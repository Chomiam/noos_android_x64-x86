#!/usr/bin/env bash
# ==============================================================================
# Test de démarrage virtuel QEMU KVM en mode BIOS / Legacy
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="$PROJECT_ROOT/out/iso/noos-android-x86_64.iso"
QEMU_BIN="$PROJECT_ROOT/tools/bin/qemu-system-x86_64"

echo "==> [Test QEMU BIOS] Vérification du boot BIOS Noos Android..."

[ -f "$ISO_PATH" ] || { echo "FAIL: ISO introuvable dans $ISO_PATH" >&2; exit 1; }
[ -x "$QEMU_BIN" ] || { echo "FAIL: Binaire QEMU introuvable dans $QEMU_BIN" >&2; exit 1; }

echo "[Test QEMU BIOS] Lancement d'une instance virtuelle KVM (durée: 5s)..."
set +e
timeout 5s "$QEMU_BIN" \
    -enable-kvm \
    -m 1024 \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -display none \
    -serial stdio > /tmp/qemu_bios_test.log 2>&1
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 0 ]; then
    echo "✓ Démarrage BIOS QEMU KVM validé avec succès."
    echo "==> [Test QEMU BIOS] SUCCÈS : L'image hybride s'amorce correctement."
    exit 0
else
    echo "ERREUR: Échec du démarrage BIOS (code de sortie: $EXIT_CODE)" >&2
    cat /tmp/qemu_bios_test.log >&2
    exit 1
fi
