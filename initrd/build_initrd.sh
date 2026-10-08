#!/usr/bin/env bash
# ==============================================================================
# Génération de l'image initrd.img pour Noos Android x86_64
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/out/boot"
BUILD_DIR="$PROJECT_ROOT/build_out/initrd_root"

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR"
rm -rf "${BUILD_DIR:?}"/*

echo "==> [Initrd] Construction du système de fichiers initial (initrd)..."

# Création de l'arborescence
mkdir -p "$BUILD_DIR/bin" "$BUILD_DIR/sbin" "$BUILD_DIR/usr/bin" "$BUILD_DIR/usr/sbin"
mkdir -p "$BUILD_DIR/dev" "$BUILD_DIR/proc" "$BUILD_DIR/sys" "$BUILD_DIR/mnt" "$BUILD_DIR/android"

# Copie de busybox statique
if [ -f "/usr/bin/busybox" ]; then
    cp "/usr/bin/busybox" "$BUILD_DIR/bin/busybox"
    chmod +x "$BUILD_DIR/bin/busybox"
    # Installation des symlinks busybox dans bin et sbin
    (cd "$BUILD_DIR/bin" && ./busybox --install -s .)
else
    echo "ERREUR: busybox statique introuvable !" >&2
    exit 1
fi

# Copie du script d'initialisation
cp "$SCRIPT_DIR/init" "$BUILD_DIR/init"
chmod +x "$BUILD_DIR/init"

# Emballage en cpio compressé gzip
echo "==> [Initrd] Compression en initrd.img..."
(
    cd "$BUILD_DIR"
    find . | cpio -o -H newc | gzip -9 > "$OUTPUT_DIR/initrd.img"
)

echo "✓ Initrd généré avec succès : $OUTPUT_DIR/initrd.img ($(ls -lh "$OUTPUT_DIR/initrd.img" | awk '{print $5}'))"
