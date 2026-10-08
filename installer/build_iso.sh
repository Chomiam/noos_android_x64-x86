#!/usr/bin/env bash
# ==============================================================================
# Génération de l'image ISO hybride UEFI/BIOS de Noos Android x86_64
# Compatible Mini PC (Intel N100 / AMD Ryzen APU / QEMU VirtIO)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PATH="$PROJECT_ROOT/tools/bin:$PATH"

ISO_DIR="$PROJECT_ROOT/build_out/iso_root"
OUTPUT_DIR="$PROJECT_ROOT/out/iso"
ISO_NAME="noos-android-x86_64.iso"
OUTPUT_ISO="$OUTPUT_DIR/$ISO_NAME"

mkdir -p "$OUTPUT_DIR" "$ISO_DIR"
rm -rf "${ISO_DIR:?}"/*

echo "==> [ISO] Préparation de l'arborescence de l'ISO Noos Android..."

# 1. Vérification des composants requis
if [ ! -f "$PROJECT_ROOT/out/boot/initrd.img" ]; then
    echo "[ISO] initrd.img manquant, génération en cours..."
    bash "$PROJECT_ROOT/initrd/build_initrd.sh"
fi

if [ ! -f "$PROJECT_ROOT/out/kernel/kernel" ]; then
    echo "[ISO] kernel manquant, préparation en cours..."
    bash "$PROJECT_ROOT/kernel/build_kernel.sh" fetch-prebuilt
fi

if [ ! -f "$PROJECT_ROOT/out/system/system.sfs" ]; then
    echo "[ISO] system.sfs manquant, génération en cours..."
    bash "$PROJECT_ROOT/rootfs/build_rootfs.sh" --edition tv
fi

# 2. Copie des fichiers système dans l'arborescence ISO
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/EFI/BOOT"

cp "$PROJECT_ROOT/out/kernel/kernel" "$ISO_DIR/kernel"
cp "$PROJECT_ROOT/out/boot/initrd.img" "$ISO_DIR/initrd.img"
cp "$PROJECT_ROOT/out/system/system.sfs" "$ISO_DIR/system.sfs"
[ -f "$PROJECT_ROOT/out/system/system_tv.sfs" ] && cp "$PROJECT_ROOT/out/system/system_tv.sfs" "$ISO_DIR/system_tv.sfs"
[ -f "$PROJECT_ROOT/out/system/system_desktop.sfs" ] && cp "$PROJECT_ROOT/out/system/system_desktop.sfs" "$ISO_DIR/system_desktop.sfs"

cp "$PROJECT_ROOT/installer/grub/grub.cfg" "$ISO_DIR/boot/grub/grub.cfg"

# 3. Création de la partition d'amorçage UEFI efi.img
echo "==> [ISO] Création de la partition d'amorçage UEFI (efi.img)..."
EFI_IMG="$ISO_DIR/boot/grub/efi.img"
rm -f "$EFI_IMG"
dd if=/dev/zero of="$EFI_IMG" bs=1M count=4 status=none
mformat -i "$EFI_IMG" -F ::
mmd -i "$EFI_IMG" ::/EFI
mmd -i "$EFI_IMG" ::/EFI/BOOT

GRUB_EFI_SRC="$PROJECT_ROOT/tools/deb_root/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi"
if [ -f "$GRUB_EFI_SRC" ]; then
    mcopy -i "$EFI_IMG" "$GRUB_EFI_SRC" ::/EFI/BOOT/bootx64.efi
    cp "$GRUB_EFI_SRC" "$ISO_DIR/EFI/BOOT/bootx64.efi"
fi

# 4. Assemblage final avec xorriso
echo "==> [ISO] Création de l'ISO hybride avec xorriso..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "NOOS_ANDROID" \
    -eltorito-alt-boot \
    -e "boot/grub/efi.img" \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "$OUTPUT_ISO" \
    "$ISO_DIR" 2>&1 | tail -n 15

# 5. Calcul de l'empreinte SHA256
sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo "✓ Image ISO hybride créée avec succès : $OUTPUT_ISO ($(ls -lh "$OUTPUT_ISO" | awk '{print $5}'))"
echo "✓ Checksum SHA256 : $(cat "$OUTPUT_ISO.sha256" | awk '{print $1}')"
