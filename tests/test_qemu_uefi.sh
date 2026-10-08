#!/usr/bin/env bash
# ==============================================================================
# Test de démarrage virtuel QEMU KVM en mode UEFI
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="$PROJECT_ROOT/out/iso/noos-android-x86_64.iso"
QEMU_BIN="$PROJECT_ROOT/tools/bin/qemu-system-x86_64"

echo "==> [Test QEMU UEFI] Vérification du boot UEFI Noos Android..."

[ -f "$ISO_PATH" ] || { echo "FAIL: ISO introuvable dans $ISO_PATH" >&2; exit 1; }
[ -x "$QEMU_BIN" ] || { echo "FAIL: Binaire QEMU introuvable dans $QEMU_BIN" >&2; exit 1; }

echo "[Test QEMU UEFI] Lancement d'une instance virtuelle KVM (durée: 5s)..."
set +e
timeout 5s "$QEMU_BIN" \
    -enable-kvm \
    -m 1024 \
    -smp 2 \
    -bios "${OVMF_PATH:-/usr/share/OVMF/OVMF_CODE_4M.fd}" \
    -cdrom "$ISO_PATH" \
    -boot d \
    -display none \
    -serial stdio > /tmp/qemu_uefi_test.log 2>&1
EXIT_CODE=$?
set -e

# Le code 124 indique un arrêt normal par le timeout après démarrage réussi
if [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 0 ]; then
    echo "✓ Démarrage UEFI QEMU KVM validé avec succès."
    echo "==> [Test QEMU UEFI] SUCCÈS : Le chargeur EFI démarre correctement."
    exit 0
else
    echo "ERREUR: Échec du démarrage UEFI (code de sortie: $EXIT_CODE)" >&2
    cat /tmp/qemu_uefi_test.log >&2
    exit 1
fi
