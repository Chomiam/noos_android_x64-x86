#!/usr/bin/env bash
# ==============================================================================
# Installation et Configuration Système de KVM, Libvirt et Virt-Manager
# Pour Pop!_OS / Ubuntu 24.04 (Noble)
# ==============================================================================
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"

echo "===================================================================="
echo " Installation des outils de virtualisation système (KVM / Libvirt)"
echo " Utilisateur cible : $TARGET_USER"
echo "===================================================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script doit être exécuté avec les privilèges root (sudo)." >&2
    echo "Commande recommandée : sudo $0" >&2
    exit 1
fi

echo "1. Mise à jour de la liste des paquets..."
apt-get update -y

echo "2. Installation des paquets système..."
apt-get install -y \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    ovmf \
    gir1.2-spiceclientgtk-3.0 \
    dnsmasq-base \
    iptables

echo "3. Ajout de l'utilisateur $TARGET_USER aux groupes 'libvirt' et 'kvm'..."
usermod -aG libvirt,kvm "$TARGET_USER"

echo "4. Activation et démarrage des services libvirtd..."
systemctl enable --now libvirtd || systemctl enable --now virtqemud

echo "5. Configuration et activation du réseau virtuel par défaut (virbr0 NAT)..."
if virsh net-info default >/dev/null 2>&1; then
    virsh net-autostart default || true
    if ! virsh net-list | grep -q "default"; then
        virsh net-start default || true
    fi
else
    echo "Génération du réseau virtuel par défaut..."
    cat << 'EOF' > /tmp/default-net.xml
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-define /tmp/default-net.xml || true
    virsh net-start default || true
    virsh net-autostart default || true
    rm -f /tmp/default-net.xml
fi

echo "6. Vérification du pool de stockage par défaut..."
if ! virsh pool-list --all | grep -q "default"; then
    virsh pool-define-as default dir --target /var/lib/libvirt/images || true
    virsh pool-build default || true
    virsh pool-start default || true
    virsh pool-autostart default || true
fi

echo "===================================================================="
echo "✓ Virtualisation système installée et configurée avec succès !"
echo "NOTE : Pour appliquer l'appartenance aux groupes 'libvirt' et 'kvm' :"
echo "       - Déconnectez-vous et reconnectez-vous à votre session graphique,"
echo "       - Ou lancez 'newgrp libvirt' dans votre terminal."
echo "===================================================================="
