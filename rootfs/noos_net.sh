#!/system/bin/sh
# ==============================================================================
# noos_net.sh — Initialisation et configuration réseau automatique pour Noos Android 17
# Architecture : x86_64 — Pilote : VirtIO-Net (QEMU/KVM) & Ethernet standard
# ==============================================================================

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH

# 1. Chargement des modules noyau réseau si l'interface eth0 n'est pas encore présente
if [ ! -d "/sys/class/net/eth0" ]; then
    insmod /vendor/lib/modules/failover.ko 2>/dev/null || true
    insmod /vendor/lib/modules/net_failover.ko 2>/dev/null || true
    insmod /vendor/lib/modules/virtio_net.ko 2>/dev/null || true
fi

# 2. Attente de la détection de l'interface réseau eth0 (VirtIO / Realtek / Intel)
for i in $(seq 1 10); do
    if [ -d "/sys/class/net/eth0" ]; then
        break
    fi
    sleep 1
done

if [ ! -d "/sys/class/net/eth0" ]; then
    echo "[noos_net] Interface eth0 non détectée, abandon."
    exit 0
fi

# 3. Activation de l'interface réseau
ip link set eth0 up

# Démarrage du client DHCP toybox en tâche de fond pour obtenir un bail
toybox dhcp -n -q -i eth0 -b 2>/dev/null &
sleep 2

# Vérification de l'attribution d'une IP par DHCP
IP_CHECK=$(ip -4 addr show eth0 2>/dev/null | grep "inet " || true)
if [ -z "$IP_CHECK" ]; then
    # Fallback IP statique pour le réseau virtuel par défaut libvirt/QEMU (192.168.122.0/24)
    ifconfig eth0 192.168.122.150 netmask 255.255.255.0 up
fi

# 4. Détermination dynamique de la passerelle par défaut
GW=$(ip route show 2>/dev/null | grep default | awk '{print $3}' | head -n 1)
if [ -z "$GW" ]; then
    # Dérivation de l'adresse de passerelle depuis l'adresse IP de eth0 (ex: 192.168.122.101 -> 192.168.122.1)
    SUBNET=$(ip -4 addr show eth0 2>/dev/null | grep -o 'inet [0-9\.]*' | awk '{print $2}' | cut -d'.' -f1-3)
    if [ -n "$SUBNET" ]; then
        GW="${SUBNET}.1"
    else
        GW="192.168.122.1"
    fi
fi

# 5. Règles de routage système Linux / Android
ip rule add from all lookup main pref 1000 2>/dev/null || true
ip route add default via "$GW" dev eth0 table main 2>/dev/null || true
ip route add default via "$GW" dev eth0 2>/dev/null || true

# 6. Enregistrement du réseau physique auprès du démon Netd Android (NetId 100)
ndc network create 100 2>/dev/null || true
ndc network interface add 100 eth0 2>/dev/null || true
ndc network route add 100 eth0 0.0.0.0/0 "$GW" 2>/dev/null || true
ndc network default set 100 2>/dev/null || true

# 7. Configuration du résolveur DNS natif Android (DnsResolver) via Binder IPC
service call dnsresolver 8 i32 100 2>/dev/null || true
service call dnsresolver 3 i32 1 i32 56 i32 100 i32 1800 i32 25 i32 8 i32 64 i32 5000 i32 2 i32 1 s16 8.8.8.8 2>/dev/null || true

# 8. Configuration des propriétés système DNS
setprop net.dns1 8.8.8.8
setprop net.dns2 1.1.1.1
setprop net.eth0.dns1 8.8.8.8
setprop net.eth0.dns2 1.1.1.1

# 9. Redirection transparente DNS via iptables (port 53 vers 8.8.8.8)
iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination 8.8.8.8:53 2>/dev/null || true
iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination 8.8.8.8:53 2>/dev/null || true

echo "[noos_net] Configuration réseau initialisée avec succès (Passerelle: $GW, DNS: 8.8.8.8)."
