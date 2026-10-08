#!/usr/bin/env bash
# ==============================================================================
# Test de validation du profil Bureau (Noos Android Desktop Edition)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [Test Bureau] Vérification de la configuration Noos Android Desktop Edition..."

DESKTOP_PROP="$PROJECT_ROOT/editions/desktop/desktop_config.prop"
KEYBOARD_KL="$PROJECT_ROOT/editions/desktop/keychars/Generic_PC_Keyboard.kl"

# 1. Vérification des propriétés système Bureau
[ -f "$DESKTOP_PROP" ] || { echo "FAIL: $DESKTOP_PROP manquant" >&2; exit 1; }

grep -q "persist.sys.freeform_window=true" "$DESKTOP_PROP" || { echo "FAIL: Multi-fenêtrage libre non activé" >&2; exit 1; }
grep -q "enable_freeform_support=1" "$DESKTOP_PROP" || { echo "FAIL: Freeform support désactivé" >&2; exit 1; }
grep -q "persist.sys.mouse_right_click=back" "$DESKTOP_PROP" || { echo "FAIL: Clic droit retour arrière non configuré" >&2; exit 1; }
echo "✓ Propriétés du profil Bureau validées (Multi-fenêtres, barre des tâches, souris)."

# 2. Vérification du mappage clavier PC
[ -f "$KEYBOARD_KL" ] || { echo "FAIL: $KEYBOARD_KL manquant" >&2; exit 1; }
grep -q "META_LEFT" "$KEYBOARD_KL" || { echo "FAIL: Touche Super/Windows non assignée" >&2; exit 1; }
grep -q "ALT_LEFT" "$KEYBOARD_KL" || { echo "FAIL: Touche Alt non assignée" >&2; exit 1; }
grep -q "TAB" "$KEYBOARD_KL" || { echo "FAIL: Touche Tab non assignée" >&2; exit 1; }
echo "✓ Mappage du clavier physique validé (Raccourcis Alt+Tab, Super / Menu)."

echo "==> [Test Bureau] SUCCÈS : Tous les tests du profil Bureau ont réussi."
