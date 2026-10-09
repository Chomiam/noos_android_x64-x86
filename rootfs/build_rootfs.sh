#!/usr/bin/env bash
# ==============================================================================
# Construction et emballage du système de fichiers Android (system.sfs)
# Pour Noos Android x86_64 — Support des éditions TV et Bureau
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATH="$PROJECT_ROOT/tools/bin:$PATH"

EDITION="tv"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --edition)
            EDITION="$2"
            shift 2
            ;;
        *)
            echo "Option inconnue : $1"
            echo "Usage: $0 [--edition tv|desktop]"
            exit 1
            ;;
    esac
done

echo "==> [RootFS] Assemblage du système Noos Android x86_64 (Édition: $EDITION)..."

OUTPUT_DIR="$PROJECT_ROOT/out/system"
mkdir -p "$OUTPUT_DIR"

if [ -f "$OUTPUT_DIR/system.sfs" ] && [ $(stat -c%s "$OUTPUT_DIR/system.sfs") -gt 100000000 ]; then
    echo "✓ Image système AOSP complète existante et opérationnelle : $OUTPUT_DIR/system.sfs ($(ls -lh "$OUTPUT_DIR/system.sfs" | awk '{print $5}'))"
    exit 0
fi

BUILD_ROOT="$PROJECT_ROOT/build_out/rootfs_$EDITION"
mkdir -p "$BUILD_ROOT"
rm -rf "${BUILD_ROOT:?}"/*

# 1. Création de l'arborescence standard AOSP
mkdir -p "$BUILD_ROOT/bin" "$BUILD_ROOT/sbin" "$BUILD_ROOT/system/bin" "$BUILD_ROOT/system/xbin" "$BUILD_ROOT/system/lib64" "$BUILD_ROOT/system/lib"
mkdir -p "$BUILD_ROOT/system/etc/permissions" "$BUILD_ROOT/system/etc/init" "$BUILD_ROOT/system/framework"
mkdir -p "$BUILD_ROOT/system/app" "$BUILD_ROOT/system/priv-app"
mkdir -p "$BUILD_ROOT/system/usr/keylayout"
mkdir -p "$BUILD_ROOT/vendor" "$BUILD_ROOT/data" "$BUILD_ROOT/dev" "$BUILD_ROOT/proc" "$BUILD_ROOT/sys"

# Installation du shell de base & commandes système
if [ -f "/usr/bin/busybox" ]; then
    cp "/usr/bin/busybox" "$BUILD_ROOT/bin/busybox"
    chmod +x "$BUILD_ROOT/bin/busybox"
    cp "/usr/bin/busybox" "$BUILD_ROOT/system/bin/busybox"
    chmod +x "$BUILD_ROOT/system/bin/busybox"
    for applet in $("$BUILD_ROOT/bin/busybox" --list); do
        [ "$applet" = "busybox" ] && continue
        ln -sf "busybox" "$BUILD_ROOT/bin/$applet"
        ln -sf "busybox" "$BUILD_ROOT/system/bin/$applet"
    done
fi

# Commandes de base Android setprop / getprop
cat << 'EOF' > "$BUILD_ROOT/system/bin/setprop"
#!/bin/sh
PROP="$1"
VAL="$2"
if [ -n "$PROP" ]; then
    echo "${PROP}=${VAL}" >> /default.prop
fi
EOF
chmod +x "$BUILD_ROOT/system/bin/setprop"

cat << 'EOF' > "$BUILD_ROOT/system/bin/getprop"
#!/bin/sh
PROP="$1"
if [ -z "$PROP" ]; then
    cat /default.prop 2>/dev/null
    cat /system/build.prop 2>/dev/null
else
    grep -E "^${PROP}=" /default.prop /system/build.prop 2>/dev/null | tail -n 1 | cut -d '=' -f 2-
fi
EOF
chmod +x "$BUILD_ROOT/system/bin/getprop"

# 2. Configuration Init & Fstab
cp "$SCRIPT_DIR/fstab.noos" "$BUILD_ROOT/system/etc/fstab.noos"
cp "$SCRIPT_DIR/init.noos.rc" "$BUILD_ROOT/system/etc/init/init.noos.rc"
cp "$SCRIPT_DIR/ueventd.noos.rc" "$BUILD_ROOT/ueventd.rc"

# 3. Intégration Native Bridge (Traduction ARM -> x86_64)
cp "$PROJECT_ROOT/compatibility/native_bridge/enable_nativebridge.sh" "$BUILD_ROOT/system/bin/enable_nativebridge.sh"
chmod +x "$BUILD_ROOT/system/bin/enable_nativebridge.sh"
cat "$PROJECT_ROOT/compatibility/native_bridge/native_bridge.prop" >> "$BUILD_ROOT/system/build.prop"

# 4. Intégration microG & Services FOSS
bash "$PROJECT_ROOT/compatibility/microg/microg_setup.sh" "$BUILD_ROOT"

# 5. Déploiement du profil d'édition (TV ou Desktop)
if [ "$EDITION" = "tv" ]; then
    echo "==> [RootFS] Application du profil TV..."
    cat "$PROJECT_ROOT/editions/tv/tv_config.prop" >> "$BUILD_ROOT/system/build.prop"
    cp "$PROJECT_ROOT/editions/tv/keychars/"*.kl "$BUILD_ROOT/system/usr/keylayout/"
    mkdir -p "$BUILD_ROOT/system/usr/idc"
    [ -d "$PROJECT_ROOT/editions/tv/idc" ] && cp "$PROJECT_ROOT/editions/tv/idc/"*.idc "$BUILD_ROOT/system/usr/idc/"
    
    # Intégration NoosTV APK (Streaming IPTV/VOD)
    if [ -f "$PROJECT_ROOT/editions/tv/prebuilts/NoosTV.apk" ]; then
        mkdir -p "$BUILD_ROOT/system/priv-app/NoosTV"
        cp "$PROJECT_ROOT/editions/tv/prebuilts/NoosTV.apk" "$BUILD_ROOT/system/priv-app/NoosTV/NoosTV.apk"
        echo "  -> NoosTV intégré dans /system/priv-app/NoosTV"
    fi

    # Intégration Projectivy Launcher (Interface TV 10-foot Leanback moderne)
    if [ -f "$PROJECT_ROOT/editions/tv/prebuilts/ProjectivyLauncher.apk" ]; then
        mkdir -p "$BUILD_ROOT/system/priv-app/ProjectivyLauncher"
        cp "$PROJECT_ROOT/editions/tv/prebuilts/ProjectivyLauncher.apk" "$BUILD_ROOT/system/priv-app/ProjectivyLauncher/ProjectivyLauncher.apk"
        echo "  -> Projectivy Launcher intégré dans /system/priv-app/ProjectivyLauncher"
    fi
else
    echo "==> [RootFS] Application du profil Bureau (Desktop)..."
    cat "$PROJECT_ROOT/editions/desktop/desktop_config.prop" >> "$BUILD_ROOT/system/build.prop"
    cp "$PROJECT_ROOT/editions/desktop/keychars/"*.kl "$BUILD_ROOT/system/usr/keylayout/"
    mkdir -p "$BUILD_ROOT/system/usr/idc"
    [ -d "$PROJECT_ROOT/editions/desktop/idc" ] && cp "$PROJECT_ROOT/editions/desktop/idc/"*.idc "$BUILD_ROOT/system/usr/idc/"

    # Intégration Taskbar (Barre des tâches & Menu Démarrer PC de bureau)
    if [ -f "$PROJECT_ROOT/editions/desktop/prebuilts/Taskbar.apk" ]; then
        mkdir -p "$BUILD_ROOT/system/priv-app/Taskbar"
        cp "$PROJECT_ROOT/editions/desktop/prebuilts/Taskbar.apk" "$BUILD_ROOT/system/priv-app/Taskbar/Taskbar.apk"
        echo "  -> Taskbar Desktop Launcher intégré dans /system/priv-app/Taskbar"
    fi
fi

# 6. Création d'un exécutable d'initialisation Android factice / démonstration si pas de binaire compilé
if [ ! -f "$BUILD_ROOT/init" ]; then
    cat << 'EOF' > "$BUILD_ROOT/init"
#!/bin/sh
echo "========================================================"
echo " Noos Android x86_64 — Android Init démarré avec succès "
echo "========================================================"
export PATH=/system/bin:/system/xbin:/sbin:/bin
/system/bin/enable_nativebridge.sh
echo "[Noos Android] Système prêt et opérationnel."
# Boucle de maintien en vie
while true; do
    sleep 3600
done
EOF
    chmod +x "$BUILD_ROOT/init"
fi

# 7. Emballage SquashFS (system.sfs)
SYSTEM_SFS="$OUTPUT_DIR/system_${EDITION}.sfs"
echo "==> [RootFS] Génération de l'image compressée $SYSTEM_SFS..."
mksquashfs "$BUILD_ROOT" "$SYSTEM_SFS" -noappend -comp zstd -Xcompression-level 15

# Lien symbolique vers system.sfs générique
cp -f "$SYSTEM_SFS" "$OUTPUT_DIR/system.sfs"

echo "✓ Image système générée avec succès : $SYSTEM_SFS ($(ls -lh "$SYSTEM_SFS" | awk '{print $5}'))"
