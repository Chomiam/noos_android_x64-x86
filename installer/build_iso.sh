#!/usr/bin/env bash
# ==============================================================================
# Génération de l'image ISO hybride UEFI/BIOS de Noos Android x86_64
# Compatible Mini PC (Intel N100 / AMD Ryzen APU / QEMU KVM Virt-Manager)
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

if [ ! -f "$PROJECT_ROOT/out/system/system_tv.sfs" ]; then
    echo "[ISO] system_tv.sfs manquant, génération du profil TV..."
    bash "$PROJECT_ROOT/rootfs/build_rootfs.sh" --edition tv
fi

if [ ! -f "$PROJECT_ROOT/out/system/system_desktop.sfs" ]; then
    echo "[ISO] system_desktop.sfs manquant, génération du profil Bureau..."
    bash "$PROJECT_ROOT/rootfs/build_rootfs.sh" --edition desktop
fi

# 2. Copie des fichiers système dans l'arborescence ISO
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/EFI/BOOT"

cp "$PROJECT_ROOT/out/kernel/kernel" "$ISO_DIR/kernel"

if [ -f "$PROJECT_ROOT/build_out/cache/initrd.img" ]; then
    cp "$PROJECT_ROOT/build_out/cache/initrd.img" "$ISO_DIR/initrd.img"
else
    cp "$PROJECT_ROOT/out/boot/initrd.img" "$ISO_DIR/initrd.img"
fi

if [ -f "$PROJECT_ROOT/build_out/cache/ramdisk.img" ]; then
    cp "$PROJECT_ROOT/build_out/cache/ramdisk.img" "$ISO_DIR/ramdisk.img"
fi

if [ -f "$PROJECT_ROOT/out/system/system.sfs" ]; then
    cp "$PROJECT_ROOT/out/system/system.sfs" "$ISO_DIR/system.sfs"
elif [ -f "$PROJECT_ROOT/build_out/cache/system.sfs" ]; then
    cp "$PROJECT_ROOT/build_out/cache/system.sfs" "$ISO_DIR/system.sfs"
fi

cp "$PROJECT_ROOT/installer/grub/grub.cfg" "$ISO_DIR/boot/grub/grub.cfg"
cp "$PROJECT_ROOT/installer/grub/grub.cfg" "$ISO_DIR/EFI/BOOT/grub.cfg"

# 3. Création de la partition d'amorçage UEFI efi.img (FAT16 conforme UEFI)
echo "==> [ISO] Création de la partition d'amorçage UEFI (efi.img)..."
EFI_IMG="$ISO_DIR/boot/grub/efi.img"
rm -f "$EFI_IMG"
dd if=/dev/zero of="$EFI_IMG" bs=1M count=16 status=none
/usr/sbin/mkfs.vfat -n "NOOS_EFI" "$EFI_IMG" >/dev/null

mmd -i "$EFI_IMG" ::/EFI
mmd -i "$EFI_IMG" ::/EFI/BOOT
mmd -i "$EFI_IMG" ::/boot
mmd -i "$EFI_IMG" ::/boot/grub

GRUB_EFI_SRC="$PROJECT_ROOT/tools/deb_root/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi"
if [ -f "$GRUB_EFI_SRC" ]; then
    # Copie du binaire EFI
    mcopy -o -i "$EFI_IMG" "$GRUB_EFI_SRC" ::/EFI/BOOT/BOOTX64.EFI
    cp "$GRUB_EFI_SRC" "$ISO_DIR/EFI/BOOT/BOOTX64.EFI"
    cp "$GRUB_EFI_SRC" "$ISO_DIR/EFI/BOOT/bootx64.efi"

    # Copie de la configuration GRUB dans le disque EFI
    mcopy -o -i "$EFI_IMG" "$PROJECT_ROOT/installer/grub/grub.cfg" ::/EFI/BOOT/grub.cfg
    mcopy -o -i "$EFI_IMG" "$PROJECT_ROOT/installer/grub/grub.cfg" ::/boot/grub/grub.cfg
fi

# 4. Assemblage final avec xorriso
echo "==> [ISO] Création de l'ISO hybride avec xorriso..."
rm -f "$OUTPUT_ISO"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "NOOS_ANDROID" \
    --efi-boot "boot/grub/efi.img" \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "$OUTPUT_ISO" \
    "$ISO_DIR" 2>&1 | tail -n 15

# Droits de lecture pour les démons système tels que libvirt
chmod 664 "$OUTPUT_ISO" 2>/dev/null || true
chmod a+r "$OUTPUT_ISO" 2>/dev/null || true

# 5. Calcul de l'empreinte SHA256
sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo "✓ Image ISO hybride créée avec succès : $OUTPUT_ISO ($(ls -lh "$OUTPUT_ISO" | awk '{print $5}'))"
echo "✓ Checksum SHA256 : $(cat "$OUTPUT_ISO.sha256" | awk '{print $1}')"
