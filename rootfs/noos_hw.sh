#!/vendor/bin/sh
# ==============================================================================
# noos_hw.sh — Initialisation matérielle anticipée pour Noos Android 17 x86_64
# Pilotes : VirtIO-GPU, VirtIO-Net, VirtIO-Input (KVM/QEMU)
# ==============================================================================

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH

# 1. Chargement ordonné des modules noyau VirtIO indispensables
insmod /vendor/lib/modules/virtio-gpu.ko 2>/dev/null || true
insmod /vendor/lib/modules/failover.ko 2>/dev/null || true
insmod /vendor/lib/modules/net_failover.ko 2>/dev/null || true
insmod /vendor/lib/modules/virtio_net.ko 2>/dev/null || true
insmod /vendor/lib/modules/virtio_input.ko 2>/dev/null || true

# 2. Forçage de la détection et du scanout sur le connecteur DRM VirtIO
for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ -f /sys/class/drm/card0-Virtual-1/status ]; then
        echo detect > /sys/class/drm/card0-Virtual-1/status 2>/dev/null || true
        echo on > /sys/class/drm/card0-Virtual-1/status 2>/dev/null || true
        break
    fi
    sleep 0.2
done

# 3. Notification d'état matériel prêt pour Init
setprop vendor.noos.hardware.ready 1
