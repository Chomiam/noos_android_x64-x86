#!/usr/bin/env bash
# ==============================================================================
# Test de validation du profil TV (Noos Android TV Edition)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [Test TV] Vérification de la configuration Noos Android TV Edition..."

TV_PROP="$PROJECT_ROOT/editions/tv/tv_config.prop"
REMOTE_KL="$PROJECT_ROOT/editions/tv/keychars/Generic_TV_Remote.kl"
NOOSTV_APK="$PROJECT_ROOT/editions/tv/prebuilts/NoosTV.apk"

# 1. Vérification des propriétés système TV
[ -f "$TV_PROP" ] || { echo "FAIL: $TV_PROP manquant" >&2; exit 1; }

grep -q "ro.build.characteristics=tv" "$TV_PROP" || { echo "FAIL: Caractéristique TV manquante" >&2; exit 1; }
grep -q "ro.noos.ui_mode=leanback" "$TV_PROP" || { echo "FAIL: Mode Leanback manquant" >&2; exit 1; }
grep -q "persist.sys.app.rotation=force_land" "$TV_PROP" || { echo "FAIL: Rotation paysage non forcée" >&2; exit 1; }
grep -q "persist.sys.hdmi.cec_enabled=true" "$TV_PROP" || { echo "FAIL: HDMI-CEC non activé" >&2; exit 1; }
echo "✓ Propriétés du profil TV validées (Leanback, 10-foot UI, HDMI-CEC)."

# 2. Vérification du mappage de la télécommande TV
[ -f "$REMOTE_KL" ] || { echo "FAIL: $REMOTE_KL manquant" >&2; exit 1; }
REQUIRED_KEYS=("DPAD_UP" "DPAD_DOWN" "DPAD_LEFT" "DPAD_RIGHT" "DPAD_CENTER" "BACK" "HOME" "MEDIA_PLAY_PAUSE")
for key in "${REQUIRED_KEYS[@]}"; do
    grep -q "$key" "$REMOTE_KL" || { echo "FAIL: Touche télécommande $key manquante" >&2; exit 1; }
done
echo "✓ Mappage de la télécommande TV validé (D-Pad, Retour, Accueil, Média)."

# 3. Vérification de la présence des applications TV (NoosTV & Projectivy Launcher)
[ -f "$NOOSTV_APK" ] || { echo "FAIL: NoosTV.apk manquant dans $NOOSTV_APK" >&2; exit 1; }
echo "✓ Application NoosTV intégrée avec succès ($(ls -lh "$NOOSTV_APK" | awk '{print $5}'))."

PROJECTIVY_APK="$PROJECT_ROOT/editions/tv/prebuilts/ProjectivyLauncher.apk"
if [ -f "$PROJECTIVY_APK" ]; then
    echo "✓ Projectivy Launcher intégré avec succès ($(ls -lh "$PROJECTIVY_APK" | awk '{print $5}'))."
fi

echo "==> [Test TV] SUCCÈS : Tous les tests du profil TV ont réussi."
