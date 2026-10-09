#!/usr/bin/env bash
# ==============================================================================
# patch_vendor_network.sh — Injection des composants réseau et GPU dans l'image vendor
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VENDOR_RAW="$PROJECT_ROOT/build_out/cache/android_17/vendor_raw.img"
VENDOR_EXTRACTED="$PROJECT_ROOT/build_out/cache/android_17/extracted_vendor/vendor.img"
VENDOR_ISO="$PROJECT_ROOT/build_out/iso_root/vendor.img"

if [ ! -f "$VENDOR_RAW" ]; then
    echo "Fichier $VENDOR_RAW introuvable."
    exit 1
fi

echo "==> [Patch Vendor] Injection des scripts, modules et permissions réseau dans vendor_raw.img..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

printf "u:object_r:vendor_configs_file:s0\0" > "$TMP_DIR/ea_cfg.bin"
printf "u:object_r:goldfish_setup_exec:s0\0" > "$TMP_DIR/ea_exec.bin"

# 1. Écriture des scripts noos_hw.sh et noos_net.sh, et des permissions Ethernet
debugfs -w -R "rm /bin/noos_hw.sh" "$VENDOR_RAW" 2>/dev/null || true
debugfs -w -R "rm /bin/noos_net.sh" "$VENDOR_RAW" 2>/dev/null || true
debugfs -w -R "rm /etc/permissions/android.hardware.ethernet.xml" "$VENDOR_RAW" 2>/dev/null || true

debugfs -w -R "write $PROJECT_ROOT/rootfs/noos_hw.sh /bin/noos_hw.sh" "$VENDOR_RAW"
debugfs -w -R "write $PROJECT_ROOT/rootfs/noos_net.sh /bin/noos_net.sh" "$VENDOR_RAW"
debugfs -w -R "write $PROJECT_ROOT/rootfs/android.hardware.ethernet.xml /etc/permissions/android.hardware.ethernet.xml" "$VENDOR_RAW"

debugfs -w -R "ea_set -f $TMP_DIR/ea_exec.bin /bin/noos_hw.sh security.selinux" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_exec.bin /bin/noos_net.sh security.selinux" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /etc/permissions/android.hardware.ethernet.xml security.selinux" "$VENDOR_RAW"

debugfs -w -R "rm /etc/init/noos_hw.rc" "$VENDOR_RAW" 2>/dev/null || true
debugfs -w -R "write $PROJECT_ROOT/rootfs/noos_hw.rc /etc/init/noos_hw.rc" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /etc/init/noos_hw.rc security.selinux" "$VENDOR_RAW"

debugfs -w -R "rm /etc/init/noos_net.rc" "$VENDOR_RAW" 2>/dev/null || true
debugfs -w -R "write $PROJECT_ROOT/rootfs/noos_net.rc /etc/init/noos_net.rc" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /etc/init/noos_net.rc security.selinux" "$VENDOR_RAW"

# Suppression du service allocator ranchu défaillant (conflit minigbm)
debugfs -w -R "rm /etc/init/android.hardware.graphics.allocator-service.ranchu.rc" "$VENDOR_RAW" 2>/dev/null || true

# 2. Patch de init.net.ranchu.sh pour invoquer noos_net.sh
debugfs -R "dump /bin/init.net.ranchu.sh $TMP_DIR/init.net.ranchu.sh" "$VENDOR_RAW"
if ! grep -q "noos_net.sh" "$TMP_DIR/init.net.ranchu.sh"; then
    echo "  -> Ajout de l'appel à noos_net.sh dans init.net.ranchu.sh"
    cat << 'EOF' >> "$TMP_DIR/init.net.ranchu.sh"

# Initialisation du réseau Noos Android 17 (VirtIO / Ethernet)
if [ -f "/vendor/bin/noos_net.sh" ]; then
    /vendor/bin/sh /vendor/bin/noos_net.sh
fi
EOF
    debugfs -w -R "rm /bin/init.net.ranchu.sh" "$VENDOR_RAW"
    debugfs -w -R "write $TMP_DIR/init.net.ranchu.sh /bin/init.net.ranchu.sh" "$VENDOR_RAW"
    debugfs -w -R "ea_set -f $TMP_DIR/ea_exec.bin /bin/init.net.ranchu.sh security.selinux" "$VENDOR_RAW"
fi

# 3. Patch complet et robuste de init.ranchu.rc pour orchestrer GPU, display et services
cat << 'EOF' > "$TMP_DIR/init.ranchu.rc"
import /vendor/etc/init/noos_hw.rc
import /vendor/etc/init/noos_net.rc

on early-fs
    start vold

on fs
    mount_all /vendor/etc/fstab.ranchu --early

on post-fs
    start vendor.noos_hw

on early-boot
    start vendor.noos_hw

on late-fs
    mount_all /vendor/etc/fstab.ranchu --late

on post-fs-data
    start gatekeeperd
    start keystore2
    trigger nonencrypted
    mkdir /data/vendor/var 0755 root root
    mkdir /data/vendor/var/run 0755 root root
    start ranchu-device-state
    start ranchu-adb-setup

on early-init
    mount proc proc /proc remount hidepid=2,gid=3009

    # true if ram is <= 2G
    setprop ro.config.low_ram ${ro.boot.config.low_ram}
    setprop ro.cpuvulkan.version ${ro.boot.qemu.cpuvulkan.version}
    setprop ro.hardware.egl ${ro.boot.hardwareegl:-emulation}
    setprop ro.hardware.vulkan ${ro.boot.hardware.vulkan}
    # gralloc could be minigbm, default ranchu
    setprop ro.hardware.gralloc ${ro.boot.hardware.gralloc:-ranchu}
    setprop ro.opengles.version ${ro.boot.opengles.version}
    setprop dalvik.vm.heapsize ${ro.boot.dalvik.vm.heapsize:-192m}
    setprop dalvik.vm.checkjni ${ro.boot.dalvik.vm.checkjni}
    # default skiagl: skia uses gles to render
    # option skiavk: skia uses vulkan to render
    setprop debug.hwui.renderer ${ro.boot.debug.hwui.renderer:-skiagl}
    # default skiaglthreaded: skia uses gles to render in a separate thread
    # option skiagl: skia uses gles to render
    # option skiavk: skia uses vulkan to render
    # option skiavkthreaded: skia uses vulkan to render in separate thread
    # option empty: skia uses graphite
    setprop debug.renderengine.backend ${ro.boot.debug.renderengine.backend:-skiaglthreaded}
    setprop debug.stagefright.ccodec ${ro.boot.debug.stagefright.ccodec}
    setprop debug.sf.nobootanimation ${ro.boot.debug.sf.nobootanimation}
    setprop debug.angle.feature_overrides_enabled ${ro.boot.hardware.angle_feature_overrides_enabled}
    setprop debug.angle.feature_overrides_disabled ${ro.boot.hardware.angle_feature_overrides_disabled}
    setprop vendor.qemu.dev.bootcomplete 0

    write /sys/module/firmware_class/parameters/path /vendor/firmware
    # start vendor.dlkm_loader
    exec u:r:modprobe:s0 -- /system/bin/modprobe -a -d /system/lib/modules zram.ko

on init
    start console
    write /sys/block/zram0/comp_algorithm lz4
    write /proc/sys/vm/page-cluster 0

    #
    # EAS uclamp interfaces
    #
    mkdir /dev/cpuctl/foreground
    mkdir /dev/cpuctl/background
    mkdir /dev/cpuctl/top-app
    mkdir /dev/cpuctl/rt
    chown system system /dev/cpuctl
    chown system system /dev/cpuctl/foreground
    chown system system /dev/cpuctl/background
    chown system system /dev/cpuctl/top-app
    chown system system /dev/cpuctl/rt
    chown system system /dev/cpuctl/tasks
    chown system system /dev/cpuctl/foreground/tasks
    chown system system /dev/cpuctl/background/tasks
    chown system system /dev/cpuctl/top-app/tasks
    chown system system /dev/cpuctl/rt/tasks
    chmod 0664 /dev/cpuctl/tasks
    chmod 0664 /dev/cpuctl/foreground/tasks
    chmod 0664 /dev/cpuctl/background/tasks
    chmod 0664 /dev/cpuctl/top-app/tasks
    chmod 0664 /dev/cpuctl/rt/tasks

    start qemu-props

on zygote-start
    # Create the directories used by the Wireless subsystem
    mkdir /data/vendor/wifi 0771 wifi wifi
    mkdir /data/vendor/wifi/wpa 0770 wifi wifi
    mkdir /data/vendor/wifi/wpa/sockets 0770 wifi wifi

on boot
    write /sys/class/drm/card0-Virtual-1/status on
    start ranchu-net
    chown root system /sys/power/wake_lock
    chown root system /sys/power/wake_unlock

    # Create an unused USB gadget to allow sysfs testing
    mkdir /config/usb_gadget/g1 0770 root root

on sys-boot-completed-set
    start ranchu-adb-start

service vendor.dlkm_loader /vendor/bin/dlkm_loader
    class main
    user root
    group root system
    disabled
    oneshot

service ranchu-adb-setup /system_ext/bin/init.adb-setup.ranchu.sh
    user system
    group shell
    stdio_to_kmsg
    disabled
    oneshot

service ranchu-adb-start /system_ext/bin/init.adb-start.ranchu.sh
    user root
    group shell
    oneshot
    disabled

service ranchu-device-state /vendor/bin/init.device-state.ranchu.sh
    user root
    group root
    oneshot
    disabled
    stdio_to_kmsg

service ranchu-net /vendor/bin/init.net.ranchu.sh
    class late_start
    user root
    group root wakelock wifi
    oneshot
    disabled

service ranchu-setup /vendor/bin/init.setup.ranchu.sh
    user root
    group root
    oneshot
    disabled

on property:vendor.qemu.vport.gnss=*
    symlink ${vendor.qemu.vport.gnss} /dev/gnss0

on property:vendor.qemu.timezone=*
    setprop persist.sys.timezone ${vendor.qemu.timezone}

on property:dev.bootcomplete=1 && property:vendor.qemu.dev.bootcomplete=0
    setprop vendor.qemu.dev.bootcomplete 1
    start qemu-props-bootcomplete
    start ranchu-setup

on post-fs-data && property:ro.boot.qemu.virtiowifi=1
    start ranchu-net

service qemu-props /vendor/bin/qemu-props
    user root
    group root
    oneshot
    disabled

service vendor.graphics.allocator /vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm
    override
    class hal animation
    user system
    group graphics drmrpc
    capabilities SYS_NICE
    onrestart restart surfaceflinger
    task_profiles ServiceCapacityLow
    disabled

service vendor.graphics.allocator.ranchu /vendor/bin/hw/android.hardware.graphics.allocator-service.ranchu
    override
    class hal animation
    user system
    group graphics drmrpc
    capabilities SYS_NICE
    onrestart restart surfaceflinger
    task_profiles ServiceCapacityLow
    disabled

on property:ro.hardware.gralloc=minigbm
    start vendor.graphics.allocator
    start vendor.camera-provider-ranchu.minigbm

on property:ro.hardware.gralloc=ranchu
    start vendor.graphics.allocator.ranchu
    start vendor.camera-provider-ranchu

on property:ro.hardware.gralloc=
    start vendor.graphics.allocator.ranchu
    start vendor.camera-provider-ranchu

service qemu-props-bootcomplete /vendor/bin/qemu-props "bootcomplete"
    user root
    group root
    oneshot
    disabled

service goldfish-logcat /system/bin/logcat -f /dev/hvc1 ${ro.boot.logcat}
    class main
    user logd
    group root logd

service bugreport /system/bin/dumpstate -d -p -z
    class main
    user root
    disabled
    oneshot
    keycodes 114 115 116

service wpa_supplicant /vendor/bin/hw/wpa_supplicant -Dnl80211 -iwlan0 -c/vendor/etc/wifi/wpa_supplicant.conf -g@android:wpa_wlan0
    interface aidl android.hardware.wifi.supplicant.ISupplicant/default
    socket wpa_wlan0 dgram 660 wifi wifi
    group system wifi inet
    oneshot
    disabled
    user root

on property:vendor.qemu.vport.bluetooth=*
    symlink ${vendor.qemu.vport.bluetooth} /dev/bluetooth0

service bt_vhci_forwarder /vendor/bin/bt_vhci_forwarder -virtio_console_dev=/dev/bluetooth0
    class main
    user bluetooth
    group root bluetooth

service vendor.noos_hw /vendor/bin/noos_hw.sh
    class early_hal
    user root
    group root
    oneshot

on property:vendor.noos.hardware.ready=1
    start vendor.hwcomposer-3
    start surfaceflinger
    start ranchu-net

on property:sys.boot_completed=1
    start ranchu-net
    start vendor.noos_net
    trigger sys-boot-completed-set

on sys-boot-completed-set && property:persist.sys.zram_enabled=1
    swapon_all /vendor/etc/fstab.${ro.hardware}
EOF

debugfs -w -R "rm /etc/init/hw/init.ranchu.rc" "$VENDOR_RAW"
debugfs -w -R "write $TMP_DIR/init.ranchu.rc /etc/init/hw/init.ranchu.rc" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /etc/init/hw/init.ranchu.rc security.selinux" "$VENDOR_RAW"

# 4. Patch de modules.load pour charger en priorité virtio-gpu et virtio_net
debugfs -R "dump /lib/modules/modules.load $TMP_DIR/modules.load" "$VENDOR_RAW"
python3 -c "
with open('$TMP_DIR/modules.load', 'r') as f:
    lines = [l.strip() for l in f if l.strip()]

priority = ['virtio-gpu.ko', 'failover.ko', 'net_failover.ko', 'virtio_net.ko', 'virtio_input.ko']
new_lines = [m for m in priority]
for l in lines:
    if l not in new_lines:
        new_lines.append(l)

with open('$TMP_DIR/modules.load', 'w') as f:
    f.write('\n'.join(new_lines) + '\n')
"
debugfs -w -R "rm /lib/modules/modules.load" "$VENDOR_RAW"
debugfs -w -R "write $TMP_DIR/modules.load /lib/modules/modules.load" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /lib/modules/modules.load security.selinux" "$VENDOR_RAW"

# 5. Patch de fstab.ranchu avec first_stage_mount pour /data et /metadata
cat << 'EOF' > "$TMP_DIR/fstab.ranchu"
# Android fstab file
/dev/block/vda   /system     ext4    ro,barrier=1     wait,first_stage_mount
/dev/block/vdb   /vendor     ext4    ro,barrier=1     wait,first_stage_mount
/dev/block/vdc   /data       ext4    noatime,nosuid,nodev,barrier=1 wait,formattable,first_stage_mount
/dev/block/vdd   /metadata   ext4    noatime,nosuid,nodev,barrier=1 wait,formattable,first_stage_mount
EOF

debugfs -w -R "rm /etc/fstab.ranchu" "$VENDOR_RAW"
debugfs -w -R "write $TMP_DIR/fstab.ranchu /etc/fstab.ranchu" "$VENDOR_RAW"
debugfs -w -R "ea_set -f $TMP_DIR/ea_cfg.bin /etc/fstab.ranchu security.selinux" "$VENDOR_RAW"

# 6. Injection des dispositions de clavier AZERTY français (matériel & fallback)
if [ -f "$PROJECT_ROOT/rootfs/azerty.kl" ]; then
    printf "u:object_r:vendor_keylayout_file:s0\0" > "$TMP_DIR/ea_vkl.bin"
    debugfs -w -R "rm /usr/keylayout/Vendor_0001_Product_0001.kl" "$VENDOR_RAW" 2>/dev/null || true
    debugfs -w -R "write $PROJECT_ROOT/rootfs/azerty.kl /usr/keylayout/Vendor_0001_Product_0001.kl" "$VENDOR_RAW"
    debugfs -w -R "ea_set -f $TMP_DIR/ea_vkl.bin /usr/keylayout/Vendor_0001_Product_0001.kl security.selinux" "$VENDOR_RAW"

    debugfs -w -R "rm /usr/keylayout/AT_Translated_Set_2_keyboard.kl" "$VENDOR_RAW" 2>/dev/null || true
    debugfs -w -R "write $PROJECT_ROOT/rootfs/azerty.kl /usr/keylayout/AT_Translated_Set_2_keyboard.kl" "$VENDOR_RAW"
    debugfs -w -R "ea_set -f $TMP_DIR/ea_vkl.bin /usr/keylayout/AT_Translated_Set_2_keyboard.kl security.selinux" "$VENDOR_RAW"

    debugfs -w -R "rm /usr/keylayout/Generic.kl" "$VENDOR_RAW" 2>/dev/null || true
    debugfs -w -R "write $PROJECT_ROOT/rootfs/azerty.kl /usr/keylayout/Generic.kl" "$VENDOR_RAW"
    debugfs -w -R "ea_set -f $TMP_DIR/ea_vkl.bin /usr/keylayout/Generic.kl security.selinux" "$VENDOR_RAW"
fi

if [ -f "$PROJECT_ROOT/rootfs/azerty_full.kcm" ]; then
    printf "u:object_r:vendor_keychars_file:s0\0" > "$TMP_DIR/ea_vkcm.bin"
    debugfs -w -R "rm /usr/keychars/Generic.kcm" "$VENDOR_RAW" 2>/dev/null || true
    debugfs -w -R "write $PROJECT_ROOT/rootfs/azerty_full.kcm /usr/keychars/Generic.kcm" "$VENDOR_RAW"
    debugfs -w -R "ea_set -f $TMP_DIR/ea_vkcm.bin /usr/keychars/Generic.kcm security.selinux" "$VENDOR_RAW"
fi

# 7. Synchronisation vers extracted_vendor et iso_root
[ -d "$(dirname "$VENDOR_EXTRACTED")" ] && cp "$VENDOR_RAW" "$VENDOR_EXTRACTED"
[ -d "$(dirname "$VENDOR_ISO")" ] && cp "$VENDOR_RAW" "$VENDOR_ISO"

echo "✓ Fichiers matériel, réseau, clavier AZERTY et modules injectés et labellisés avec succès dans les images vendor."
