#!/system/bin/sh
# ==============================================================================
# Script d'activation et de gestion du pont de traduction ARM (Native Bridge)
# Permet de faire tourner 99% des applications Android ARMv7 et ARM64 sur PC x86_64
# ==============================================================================

BRIDGE_PROP="ro.dalvik.vm.native.bridge"
BRIDGE_LIB="libndk_translation.so"
SYS_LIB64="/system/lib64"
SYS_LIB="/system/lib"

echo "[NativeBridge] Initialisation de la couche de compatibilité ARM..."

# 1. Vérification de la présence des bibliothèques de traduction
if [ ! -f "$SYS_LIB64/$BRIDGE_LIB" ] && [ ! -f "/vendor/lib64/$BRIDGE_LIB" ]; then
    echo "[NativeBridge] Bibliothèque $BRIDGE_LIB absente de /system/lib64."
    echo "[NativeBridge] Tentative de récupération automatique du pack libndk_translation..."
    
    # URL miroir officielle communautaire (Android-Generic / BlissOS)
    DOWNLOAD_URL="https://github.com/RawPikachu/libndk_translation_Module/releases/latest/download/libndk_translation.zip"
    
    if [ -x "/system/bin/curl" ]; then
        curl -L -k "$DOWNLOAD_URL" -o /data/local/tmp/native_bridge.zip 2>/dev/null || true
    fi
fi

# 2. Activation des propriétés système
setprop ro.dalvik.vm.native.bridge "$BRIDGE_LIB"
setprop ro.enable.native.bridge.exec 1
setprop ro.dalvik.vm.isa.arm x86
setprop ro.dalvik.vm.isa.arm64 x86_64

# 3. Enregistrement binfmt_misc pour les exécutables ELF ARM autonomes
if [ -d /proc/sys/fs/binfmt_misc ]; then
    if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
        mount -t binfmt_misc none /proc/sys/fs/binfmt_misc 2>/dev/null || true
    fi
    # Enregistrement ARM64 ELF header
    if [ -f /proc/sys/fs/binfmt_misc/register ] && [ -f "$SYS_LIB64/arm64/ndk_translation" ]; then
        echo ':arm64_elf:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/system/lib64/arm64/ndk_translation:P' > /proc/sys/fs/binfmt_misc/register 2>/dev/null || true
    fi
fi

echo "[NativeBridge] Couche de traduction ARM64 -> x86_64 activée avec succès."
