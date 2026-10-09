#!/usr/bin/env bash
# ==============================================================================
# Test de validation de la configuration réseau Noos Android 17 (VirtIO / Ethernet)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [Test Réseau] Vérification de la configuration réseau Noos Android 17..."

HW_SCRIPT="$PROJECT_ROOT/rootfs/noos_hw.sh"
HW_RC="$PROJECT_ROOT/rootfs/noos_hw.rc"
NET_SCRIPT="$PROJECT_ROOT/rootfs/noos_net.sh"
NET_RC="$PROJECT_ROOT/rootfs/noos_net.rc"
NET_PERM="$PROJECT_ROOT/rootfs/android.hardware.ethernet.xml"

# 1. Vérification des fichiers requis
[ -f "$HW_SCRIPT" ] || { echo "FAIL: $HW_SCRIPT manquant" >&2; exit 1; }
[ -x "$HW_SCRIPT" ] || { echo "FAIL: $HW_SCRIPT non exécutable" >&2; exit 1; }
[ -f "$HW_RC" ] || { echo "FAIL: $HW_RC manquant" >&2; exit 1; }
[ -f "$NET_SCRIPT" ] || { echo "FAIL: $NET_SCRIPT manquant" >&2; exit 1; }
[ -x "$NET_SCRIPT" ] || { echo "FAIL: $NET_SCRIPT non exécutable" >&2; exit 1; }
[ -f "$NET_RC" ] || { echo "FAIL: $NET_RC manquant" >&2; exit 1; }
[ -f "$NET_PERM" ] || { echo "FAIL: $NET_PERM manquant" >&2; exit 1; }

echo "✓ Fichiers matériel et réseau présents et permissions validées."

# 2. Vérification des directives critiques du script réseau
grep -q "toybox dhcp" "$NET_SCRIPT" || { echo "FAIL: Support DHCP manquant dans noos_net.sh" >&2; exit 1; }
grep -q "ndc network create 100" "$NET_SCRIPT" || { echo "FAIL: Enregistrement Netd 100 manquant dans noos_net.sh" >&2; exit 1; }
grep -q "service call dnsresolver 8" "$NET_SCRIPT" || { echo "FAIL: Cache DNS DnsResolver manquant dans noos_net.sh" >&2; exit 1; }
grep -q "service call dnsresolver 3" "$NET_SCRIPT" || { echo "FAIL: Configuration DNS DnsResolver manquante dans noos_net.sh" >&2; exit 1; }
echo "✓ Directives réseau validées (DHCP, Netd, DnsResolver Binder IPC)."

# 3. Vérification de la caractéristique matérielle Ethernet
grep -q 'feature name="android.hardware.ethernet"' "$NET_PERM" || { echo "FAIL: Caractéristique android.hardware.ethernet manquante" >&2; exit 1; }
echo "✓ Caractéristique système android.hardware.ethernet validée."

# 4. Vérification de l'intégration dans build_rootfs.sh
grep -q "noos_net.sh" "$PROJECT_ROOT/rootfs/build_rootfs.sh" || { echo "FAIL: noos_net.sh non intégré dans build_rootfs.sh" >&2; exit 1; }
grep -q "android.hardware.ethernet.xml" "$PROJECT_ROOT/rootfs/build_rootfs.sh" || { echo "FAIL: android.hardware.ethernet.xml non intégré dans build_rootfs.sh" >&2; exit 1; }
echo "✓ Intégration dans build_rootfs.sh validée."

echo "==> [Test Réseau] SUCCÈS : Tous les tests réseau statiques ont réussi."
