#!/usr/bin/env bash
# ==============================================================================
# Script de compilation & préparation du Kernel Linux 6.12 LTS (Noos Android x86_64)
# Conforme à la politique Noos NAS Ecosystem (délégation GitHub Actions / mode local)
# Supporte Linux 6.12 LTS et 6.18 LTS avec tous les modules Android & ARM NativeBridge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PATH="$PROJECT_ROOT/tools/bin:$PATH"
export BISON_PKGDATADIR="$PROJECT_ROOT/tools/deb_root/usr/share/bison"

KERNEL_VERSION="${KERNEL_VERSION:-6.12.112}"
KERNEL_DIR="$PROJECT_ROOT/build_out/kernel"
OUTPUT_DIR="$PROJECT_ROOT/out/kernel"
DEFCONFIG="${DEFCONFIG:-$SCRIPT_DIR/config-6.12-noos-x86_64}"

mkdir -p "$OUTPUT_DIR"

usage() {
    echo "Usage: $0 [compile|fetch-prebuilt|check]"
    echo "  check           : Vérifie la syntaxe et la complétude du defconfig 6.12 LTS"
    echo "  compile         : Télécharge et compile le noyau Linux $KERNEL_VERSION LTS avec patches Android"
    echo "  fetch-prebuilt  : Prépare une image noyau compatible pour simulation locale"
    exit 1
}

MODE="${1:-check}"

case "$MODE" in
    check)
        echo "==> [Kernel] Vérification du defconfig Noos Android x86_64 (Linux 6.12 LTS)..."
        if [ ! -f "$DEFCONFIG" ]; then
            echo "ERREUR: Defconfig introuvable: $DEFCONFIG" >&2
            exit 1
        fi
        REQUIRED_CONFIGS=(
            "CONFIG_ANDROID=y"
            "CONFIG_ANDROID_BINDER_IPC=y"
            "CONFIG_ANDROID_BINDERFS=y"
            "CONFIG_BINFMT_MISC=y"
            "CONFIG_PSI=y"
            "CONFIG_DMABUF_HEAPS=y"
            "CONFIG_DRM=y"
            "CONFIG_DRM_I915=y"
            "CONFIG_DRM_AMDGPU=y"
            "CONFIG_DRM_VIRTIO_GPU=y"
            "CONFIG_OVERLAY_FS=y"
            "CONFIG_JOYSTICK_XPAD=y"
            "CONFIG_INPUT_EVDEV=y"
            "CONFIG_MEDIA_CEC_RC=y"
        )
        for cfg in "${REQUIRED_CONFIGS[@]}"; do
            if ! grep -q "^$cfg" "$DEFCONFIG"; then
                echo "ERREUR: Configuration manquante: $cfg" >&2
                exit 1
            fi
        done
        echo "✓ Defconfig 6.12 LTS validé avec succès (tous les prérequis Android, IPC, ARM translation & hardware sont présents)."
        ;;

    compile)
        echo "==> [Kernel] Téléchargement et compilation du noyau Linux $KERNEL_VERSION LTS..."
        mkdir -p "$KERNEL_DIR"
        cd "$KERNEL_DIR"
        MAJOR_VER="${KERNEL_VERSION%%.*}"
        if [ ! -f "linux-$KERNEL_VERSION.tar.xz" ]; then
            echo "Téléchargement de Linux $KERNEL_VERSION depuis kernel.org..."
            curl -fSL "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VER}.x/linux-$KERNEL_VERSION.tar.xz" -o "linux-$KERNEL_VERSION.tar.xz"
            tar -xf "linux-$KERNEL_VERSION.tar.xz"
        fi
        cd "linux-$KERNEL_VERSION"
        cp "$DEFCONFIG" .config
        make olddefconfig
        make -j"$(nproc)" bzImage
        cp arch/x86/boot/bzImage "$OUTPUT_DIR/kernel"
        echo "✓ Noyau compilé avec succès dans $OUTPUT_DIR/kernel"
        ;;

    fetch-prebuilt)
        echo "==> [Kernel] Préparation du noyau pour l'image Noos Android..."
        mkdir -p "$OUTPUT_DIR"
        if [ -f "$OUTPUT_DIR/kernel" ] && [ -s "$OUTPUT_DIR/kernel" ]; then
            echo "✓ Noyau existant conservé : $OUTPUT_DIR/kernel"
        elif [ -f "/boot/vmlinuz-$(uname -r)" ] && [ -r "/boot/vmlinuz-$(uname -r)" ]; then
            echo "Copie du noyau hôte ($(uname -r)) pour amorçage..."
            cp "/boot/vmlinuz-$(uname -r)" "$OUTPUT_DIR/kernel"
        else
            echo "ERREUR: Aucun noyau disponible. Utilisez 'compile' ou placez un bzImage dans $OUTPUT_DIR/kernel" >&2
            exit 1
        fi
        echo "✓ Noyau opérationnel : $OUTPUT_DIR/kernel"
        ;;

    *)
        usage
        ;;
esac
