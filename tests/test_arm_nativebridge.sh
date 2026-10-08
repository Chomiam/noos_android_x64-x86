#!/usr/bin/env bash
# ==============================================================================
# Test de validation du pont de traduction ARM (Native Bridge)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [Test NativeBridge] Vérification de la compatibilité des applications ARM..."

NB_PROP="$PROJECT_ROOT/compatibility/native_bridge/native_bridge.prop"
NB_SCRIPT="$PROJECT_ROOT/compatibility/native_bridge/enable_nativebridge.sh"

[ -f "$NB_PROP" ] || { echo "FAIL: $NB_PROP manquant" >&2; exit 1; }
[ -f "$NB_SCRIPT" ] || { echo "FAIL: $NB_SCRIPT manquant" >&2; exit 1; }

# Vérification de la déclaration des ABIs pour le PackageManager
grep -q "arm64-v8a" "$NB_PROP" || { echo "FAIL: arm64-v8a absent de la liste des ABIs compatibles" >&2; exit 1; }
grep -q "armeabi-v7a" "$NB_PROP" || { echo "FAIL: armeabi-v7a absent de la liste des ABIs compatibles" >&2; exit 1; }
grep -q "ro.dalvik.vm.native.bridge=libndk_translation.so" "$NB_PROP" || { echo "FAIL: Bibliothèque de traduction non déclarée" >&2; exit 1; }

echo "✓ Configuration des ABIs et de libndk_translation validée."
echo "==> [Test NativeBridge] SUCCÈS : La couche de traduction ARM est correctement configurée."
