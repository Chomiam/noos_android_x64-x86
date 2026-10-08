#!/bin/sh
# ==============================================================================
# Installateur Noos Android x86_64 pour disque dur / SSD NVMe
# ==============================================================================
set -e

echo "========================================================"
echo "          Noos Android x86_64 Installer                 "
echo "========================================================"

TARGET_DISK="${1:-}"

if [ -z "$TARGET_DISK" ]; then
    echo "[Installer] Scan des disques disponibles..."
    DISKS=$(lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop" | grep -v "sr")
    echo "$DISKS"
    echo ""
    echo "Usage: $0 /dev/sdX ou /dev/nvme0n1"
    exit 1
fi

echo "[Installer] Cible sélectionnée : $TARGET_DISK"
echo "[Installer] Préparation des partitions..."

# Création d'une table GPT propre : Partition 1: EFI (512M FAT32), Partition 2: Android (ext4)
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart "EFI" fat32 1MiB 513MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart "NoosAndroid" ext4 513MiB 100%

sleep 2

# Détection des noms de partitions (ex: /dev/sda1 ou /dev/nvme0n1p1)
if echo "$TARGET_DISK" | grep -q "nvme"; then
    PART_EFI="${TARGET_DISK}p1"
    PART_SYS="${TARGET_DISK}p2"
else
    PART_EFI="${TARGET_DISK}1"
    PART_SYS="${TARGET_DISK}2"
fi

echo "[Installer] Formatage de la partition EFI ($PART_EFI)..."
mkfs.vfat -F32 "$PART_EFI"

echo "[Installer] Formatage de la partition système ($PART_SYS)..."
mkfs.ext4 -F -L "NoosAndroid" "$PART_SYS"

MOUNT_POINT="/mnt/target_install"
mkdir -p "$MOUNT_POINT"
mount "$PART_SYS" "$MOUNT_POINT"

mkdir -p "$MOUNT_POINT/boot/efi"
mount "$PART_EFI" "$MOUNT_POINT/boot/efi"

echo "[Installer] Copie des composants système Noos Android..."
mkdir -p "$MOUNT_POINT/noos" "$MOUNT_POINT/data"
cp /mnt/noos_boot/kernel "$MOUNT_POINT/noos/kernel"
cp /mnt/noos_boot/initrd.img "$MOUNT_POINT/noos/initrd.img"
cp /mnt/noos_boot/system.sfs "$MOUNT_POINT/noos/system.sfs"

echo "[Installer] Installation du chargeur d'amorçage UEFI..."
mkdir -p "$MOUNT_POINT/boot/efi/EFI/BOOT"
mkdir -p "$MOUNT_POINT/boot/efi/boot/grub"
cp /mnt/noos_boot/boot/grub/grub.cfg "$MOUNT_POINT/boot/efi/boot/grub/grub.cfg"
cp /mnt/noos_boot/boot/grub/x86_64-efi/monolithic/grubx64.efi "$MOUNT_POINT/boot/efi/EFI/BOOT/bootx64.efi" 2>/dev/null || true

sync
umount "$MOUNT_POINT/boot/efi"
umount "$MOUNT_POINT"

echo "✓ Installation terminée avec succès sur $TARGET_DISK !"
echo "Vous pouvez maintenant retirer la clé USB et redémarrer votre Mini PC."
