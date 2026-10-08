#!/usr/bin/env bash
# ==============================================================================
# Déploiement et intégration des Services Google Alternatifs Open Source (microG)
# & Clients d'applications FOSS (Aurora Store, F-Droid)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-}"

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <chemin_vers_system_rootfs>"
    exit 1
fi

echo "==> [microG] Intégration de la suite FOSS Google Services dans $TARGET_DIR..."

PRIVAPP_DIR="$TARGET_DIR/system/priv-app"
ETC_PERM_DIR="$TARGET_DIR/system/etc/permissions"
SYS_LIB_DIR="$TARGET_DIR/system/framework"

mkdir -p "$PRIVAPP_DIR/GmsCore" "$PRIVAPP_DIR/GsfProxy" "$PRIVAPP_DIR/FakeStore"
mkdir -p "$PRIVAPP_DIR/AuroraStore" "$PRIVAPP_DIR/FDroid"
mkdir -p "$ETC_PERM_DIR" "$SYS_LIB_DIR"

# 1. Copie des fichiers de permissions privilégiées
cp "$SCRIPT_DIR/privapp-permissions-microg.xml" "$ETC_PERM_DIR/"
cp "$SCRIPT_DIR/default-permissions-microg.xml" "$ETC_PERM_DIR/"

# 2. Permissions pour le Signature Spoofing (Fausse signature d'application)
cat << 'EOF' > "$ETC_PERM_DIR/android.permission.FAKE_PACKAGE_SIGNATURE.xml"
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <permission name="android.permission.FAKE_PACKAGE_SIGNATURE" />
</permissions>
EOF

# 3. Déclaration com.google.android.maps.xml pour les applications dépendantes de Google Maps
cat << 'EOF' > "$ETC_PERM_DIR/com.google.android.maps.xml"
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <library name="com.google.android.maps"
            file="/system/framework/com.google.android.maps.jar" />
</permissions>
EOF

# 4. Intégration du magasin d'applications libres F-Droid
if [ -f "$SCRIPT_DIR/prebuilts/F-Droid.apk" ]; then
    mkdir -p "$PRIVAPP_DIR/FDroid"
    cp "$SCRIPT_DIR/prebuilts/F-Droid.apk" "$PRIVAPP_DIR/FDroid/FDroid.apk"
    echo "  -> F-Droid Store intégré dans /system/priv-app/FDroid"
fi

echo "✓ Fichiers de configuration et permissions microG déployés avec succès."
