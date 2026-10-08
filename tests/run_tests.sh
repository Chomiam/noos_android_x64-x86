#!/usr/bin/env bash
# ==============================================================================
# Suite de Tests Complète & Amélioration Continue — Noos Android x86_64
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================================================"
echo "          Noos Android x86_64 — Suite de Tests d'Intégration           "
echo "========================================================================"
echo "Date : $(date -R)"
echo "Hôte : $(uname -srm)"
echo ""

TEST_SUITES=(
    "Configuration Noyau 6.6 LTS:$PROJECT_ROOT/kernel/build_kernel.sh check"
    "Profil Noos Android TV Edition:$PROJECT_ROOT/tests/test_tv_profile.sh"
    "Profil Noos Android Desktop Edition:$PROJECT_ROOT/tests/test_desktop_profile.sh"
    "Traduction ARM (Native Bridge):$PROJECT_ROOT/tests/test_arm_nativebridge.sh"
    "Services Google FOSS (microG):$PROJECT_ROOT/tests/test_microg_services.sh"
    "Amorçage Virtuel BIOS QEMU KVM:$PROJECT_ROOT/tests/test_qemu_bios.sh"
    "Amorçage Virtuel UEFI QEMU KVM:$PROJECT_ROOT/tests/test_qemu_uefi.sh"
)

TOTAL=${#TEST_SUITES[@]}
PASSED=0
FAILED=0

START_TIME=$(date +%s)

for item in "${TEST_SUITES[@]}"; do
    NAME="${item%%:*}"
    CMD="${item#*:}"
    
    echo "------------------------------------------------------------------------"
    echo "▶ Exécution : $NAME"
    echo "------------------------------------------------------------------------"
    
    if eval "$CMD"; then
        echo "✅ PASSÉ : $NAME"
        PASSED=$((PASSED + 1))
    else
        echo "❌ ÉCHEC : $NAME" >&2
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "========================================================================"
echo "                       RÉSUMÉ DU RAPPORT DE TESTS                       "
echo "========================================================================"
echo "Total des tests : $TOTAL"
echo "Succès          : $PASSED"
echo "Échecs          : $FAILED"
echo "Temps écoulé    : ${DURATION}s"
echo "========================================================================"

if [ "$FAILED" -eq 0 ]; then
    echo "🎉 TOUS LES TESTS SONT AU VERT ! Système Noos Android x86_64 validé."
    exit 0
else
    echo "⚠️ Certains tests ont échoué. Corrigez les anomalies ci-dessus." >&2
    exit 1
fi
