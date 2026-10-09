#!/usr/bin/env bash
# ==============================================================================
# Génération de l'image ISO hybride UEFI/BIOS de Noos Android 17 (API 37)
# Version du noyau : Linux 6.12 LTS (ACK) - Architecture : x86_64
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

echo "==> [ISO] Préparation de l'arborescence de l'ISO Noos Android 17..."

# 1. Vérification et préparation du noyau Linux 6.12 LTS
mkdir -p "$PROJECT_ROOT/out/kernel"
if [ -f "$PROJECT_ROOT/build_out/cache/android_17/extracted_vendor/kernel-ranchu" ]; then
    cp "$PROJECT_ROOT/build_out/cache/android_17/extracted_vendor/kernel-ranchu" "$PROJECT_ROOT/out/kernel/kernel"
    echo "✓ Noyau Linux 6.12 LTS synchronisé"
fi

# 2. Vérification de l'initrd
if [ ! -f "$PROJECT_ROOT/out/boot/initrd.img" ]; then
    echo "[ISO] initrd.img manquant, génération en cours..."
    bash "$PROJECT_ROOT/initrd/build_initrd.sh"
fi

# 3. Copie des composants système dans l'arborescence ISO
mkdir -p "$ISO_DIR/boot/grub" "$ISO_DIR/EFI/BOOT" "$ISO_DIR/apps"

cp "$PROJECT_ROOT/out/kernel/kernel" "$ISO_DIR/kernel"
cp "$PROJECT_ROOT/out/boot/initrd.img" "$ISO_DIR/initrd.img"

# Copie des partitions Android 17
if [ -f "$PROJECT_ROOT/build_out/cache/android_17/system.img" ]; then
    echo "==> [ISO] Copie de Android 17 system.img..."
    cp "$PROJECT_ROOT/build_out/cache/android_17/system.img" "$ISO_DIR/system.img"
elif [ -f "$PROJECT_ROOT/out/system/system.sfs" ]; then
    cp "$PROJECT_ROOT/out/system/system.sfs" "$ISO_DIR/system.sfs"
fi

if [ -f "$PROJECT_ROOT/build_out/cache/android_17/extracted_vendor/vendor.img" ]; then
    echo "==> [ISO] Copie de Android 17 vendor.img..."
    cp "$PROJECT_ROOT/build_out/cache/android_17/extracted_vendor/vendor.img" "$ISO_DIR/vendor.img"
fi

# Copie des applications préinstallées Noos (TV & Desktop & Store)
echo "==> [ISO] Copie des applications Noos (ProjectivyLauncher, NoosTV, Taskbar, AuroraStore)..."
[ -f "$PROJECT_ROOT/editions/tv/prebuilts/ProjectivyLauncher.apk" ] && cp "$PROJECT_ROOT/editions/tv/prebuilts/ProjectivyLauncher.apk" "$ISO_DIR/apps/"
[ -f "$PROJECT_ROOT/editions/tv/prebuilts/NoosTV.apk" ] && cp "$PROJECT_ROOT/editions/tv/prebuilts/NoosTV.apk" "$ISO_DIR/apps/"
[ -f "$PROJECT_ROOT/editions/desktop/prebuilts/Taskbar.apk" ] && cp "$PROJECT_ROOT/editions/desktop/prebuilts/Taskbar.apk" "$ISO_DIR/apps/"
[ -f "$PROJECT_ROOT/editions/tv/prebuilts/AuroraStore.apk" ] && cp "$PROJECT_ROOT/editions/tv/prebuilts/AuroraStore.apk" "$ISO_DIR/apps/"

# Copie de la configuration GRUB
cp "$PROJECT_ROOT/installer/grub/grub.cfg" "$ISO_DIR/boot/grub/grub.cfg"
cp "$PROJECT_ROOT/installer/grub/grub.cfg" "$ISO_DIR/EFI/BOOT/grub.cfg"

# 4. Création de la partition d'amorçage UEFI efi.img (FAT16 conforme UEFI)
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
    mcopy -o -i "$EFI_IMG" "$GRUB_EFI_SRC" ::/EFI/BOOT/BOOTX64.EFI
    cp "$GRUB_EFI_SRC" "$ISO_DIR/EFI/BOOT/BOOTX64.EFI"
    cp "$GRUB_EFI_SRC" "$ISO_DIR/EFI/BOOT/bootx64.efi"
    mcopy -o -i "$EFI_IMG" "$PROJECT_ROOT/installer/grub/grub.cfg" ::/EFI/BOOT/grub.cfg
    mcopy -o -i "$EFI_IMG" "$PROJECT_ROOT/installer/grub/grub.cfg" ::/boot/grub/grub.cfg
fi

# 5. Assemblage final avec xorriso
echo "==> [ISO] Création de l'ISO hybride Noos Android 17 avec xorriso..."
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

# Droits de lecture pour libvirt / QEMU
chmod 664 "$OUTPUT_ISO" 2>/dev/null || true
chmod a+r "$OUTPUT_ISO" 2>/dev/null || true

# 6. Calcul de l'empreinte SHA256
sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"

echo "✓ Image ISO hybride créée avec succès : $OUTPUT_ISO ($(ls -lh "$OUTPUT_ISO" | awk '{print $5}'))"
echo "✓ Checksum SHA256 : $(cat "$OUTPUT_ISO.sha256" | awk '{print $1}')"
