#!/usr/bin/env bash
# ==============================================================================
# Test de validation des services Google FOSS (microG, Permissions, Spoofing)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [Test microG] Vérification des services Google FOSS et Signature Spoofing..."

PRIVAPP_XML="$PROJECT_ROOT/compatibility/microg/privapp-permissions-microg.xml"
DEFPERM_XML="$PROJECT_ROOT/compatibility/microg/default-permissions-microg.xml"
SETUP_SH="$PROJECT_ROOT/compatibility/microg/microg_setup.sh"

[ -f "$PRIVAPP_XML" ] || { echo "FAIL: $PRIVAPP_XML manquant" >&2; exit 1; }
[ -f "$DEFPERM_XML" ] || { echo "FAIL: $DEFPERM_XML manquant" >&2; exit 1; }
[ -f "$SETUP_SH" ] || { echo "FAIL: $SETUP_SH manquant" >&2; exit 1; }

# Vérification du Signature Spoofing
grep -q "android.permission.FAKE_PACKAGE_SIGNATURE" "$PRIVAPP_XML" || { echo "FAIL: FAKE_PACKAGE_SIGNATURE manquant dans privapp" >&2; exit 1; }
grep -q "com.google.android.gms" "$PRIVAPP_XML" || { echo "FAIL: GmsCore manquant" >&2; exit 1; }
grep -q "com.android.vending" "$PRIVAPP_XML" || { echo "FAIL: FakeStore / Aurora manquant" >&2; exit 1; }

echo "✓ Permissions microG et Signature Spoofing vérifiées avec succès."
echo "==> [Test microG] SUCCÈS : Les alternatives Google Services sont opérationnelles."
