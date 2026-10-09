# 🏛️ Architecture Technique — Noos Android x86_64

## 1. Contexte & Problématique
Le projet originel **Android-x86** (`android-x86.org`) s'est arrêté à Android 9.0 (Pie) avec un noyau Linux 4.19 obsolète, rendant impossible :
* L'exécution sur les Mini PC modernes (Intel 12e-14e génération, N95/N100/N200/N305, AMD Ryzen APU RDNA2/RDNA3, cartes réseau 2.5GbE, puces Wi-Fi 6E/7 AX210/BE200).
* L'installation de la majorité des applications Android contemporaines (qui exigent un niveau d'API minimal Android 13/14, soit API 33/34).
* L'exécution des applications Android fournies uniquement en binaire natif ARM64 (`arm64-v8a`) sans architecture x86_64 native.
* L'usage sur écran de télévision moderne ou sur poste de travail avec multi-fenêtrage.

**Noos Android x86_64** modernise de fond en comble cette distribution en fournissant une plateforme modulaire basée sur les technologies AOSP modernes, le noyau Linux 6.12 LTS (avec support 6.18 LTS), Mesa 24+, la traduction ARM transparente (binfmt_misc / libndk_translation) et les services Google FOSS.

---

## 2. Piles Logicielles & Composants

```
+--------------------------------------------------------------------------+
|                       APPLICATIONS ANDROID                               |
|   NoosTV (IPTV/VOD)  |  Aurora Store  |  F-Droid  |  Apps ARM64/x86      |
+--------------------------------------------------------------------------+
|                   ÉDITIONS & ENVIRONNEMENT UTILISATEUR                   |
|   [TV Edition] Leanback 10-foot UI, D-Pad/CEC, NoosTV, Lecteur Media3    |
|   [Desktop Edition] Multi-fenêtrage Freeform, Barre des tâches, Souris   |
+--------------------------------------------------------------------------+
|                  COUCHE DE SERVICES GOOGLE FOSS & COMPAT                 |
|   microG Suite (GmsCore, GsfProxy, FakeStore) | Signature Spoofing       |
|   Native Bridge : libndk_translation / Houdini (ARM64 -> x86_64)         |
+--------------------------------------------------------------------------+
|                          FRAMEWORK AOSP                                  |
|   Android Runtime (ART) | AudioFlinger | SurfaceFlinger | PackageManager |
+--------------------------------------------------------------------------+
|                     HARDWARE ABSTRACTION LAYERS (HAL)                    |
|   Mesa 24+ (Iris, RadeonSI, VirGL) | DRM Gralloc (GBM) | DRM HWComposer  |
|   ALSA & Sound Open Firmware (SOF) | BlueZ / Linux Wi-Fi mac80211        |
+--------------------------------------------------------------------------+
|                     NOYAU LINUX 6.12 LTS & PILOTES                       |
|   BinderFS, MemFD, PSI, DMA-BUF Heaps, binfmt_misc, DRM/KMS, SOF Audio   |
+--------------------------------------------------------------------------+
|                    CHARGEUR D'AMORÇAGE HYBRIDE (GRUB 2)                  |
|   UEFI 64-bit (x86_64-efi) + Legacy BIOS (i386-pc) | Partition GPT/MBR   |
+--------------------------------------------------------------------------+
```

---

## 3. Matériel Cible (Mini PC Modernes)

| Composant | Matériels supportés | Pilotes & Sous-systèmes |
| :--- | :--- | :--- |
| **Processeurs Intel** | Intel N95, N100, N200, N305, Core i3/i5/i7 (12e à 14e gén.) | `CONFIG_DRM_I915`, `CONFIG_DRM_XE`, Mesa Gallium `iris` |
| **Processeurs AMD** | AMD Ryzen 5000 / 6000 / 7000 / 8000 APUs (Vega / RDNA2 / RDNA3) | `CONFIG_DRM_AMDGPU`, Mesa Gallium `radeonsi` |
| **Affichage & 3D** | TV 4K/60Hz, Écrans PC DisplayPort/HDMI, VirtIO GPU | DRM/KMS, GBM Gralloc, Vulkan (`anv`, `radv`, `lavapipe`) |
| **Réseau Ethernet** | Intel i225/i226 2.5GbE, Realtek RTL8125 2.5GbE, RTL8168/8169 | `CONFIG_IGC`, `CONFIG_R8169` |
| **Wi-Fi & Bluetooth** | Intel AX200/AX201/AX210/BE200, Realtek RTL8821CE/RTL8852BE | `CONFIG_IWLWIFI`, `CONFIG_RTW88`, `CONFIG_RTW89`, `CONFIG_BT_HCIBTUSB` |
| **Audio** | Intel/AMD HDA, Puces SOF (Sound Open Firmware) | `CONFIG_SND_SOC_SOF_TOPLEVEL`, TinyALSA, Audio HAL |
| **Contrôles TV** | Télécommandes RF 2.4G, Bluetooth, HDMI-CEC, Manettes Xbox/PS5 | `CONFIG_INPUT_EVDEV`, `CONFIG_JOYSTICK_XPAD`, `CONFIG_MEDIA_CEC_RC` |

---

## 4. Deux Éditions Spécialisées

### 📺 Édition 1 : Noos Android TV Edition (Mini PC -> TV)
* **Interface Leanback** : Interface visuelle 10-foot UI adaptée à une consultation à distance (2 à 4 mètres) avec une résolution 1080p ou 4K et un DPI de 280.
* **Navigation par Télécommande** : Prise en charge native des télécommandes infrarouge, RF 2.4 GHz (dongle USB air-mouse), Bluetooth et HDMI CEC via `Generic_TV_Remote.kl`.
* **Prise en charge des Manettes** : Mappage natif des manettes sans fil (Xbox Series, DualSense, manettes génériques) via `Vendor_045e_Product_028e.kl`.
* **Application NoosTV Intégrée** : Intégration en tant qu'application privilégiée de streaming TV et VOD basée sur Media3 ExoPlayer (`io.noostv`).
* **Gestion d'Alimentation TV** : Maintien de l'écran éveillé lors de la lecture vidéo et mise en veille coordonnée avec le téléviseur.

### 🖥️ Édition 2 : Noos Android Desktop Edition (Mini PC de Bureau)
* **Multi-fenêtrage AOSP Freeform** : Activation des drapeaux `persist.sys.freeform_window=true` et `enable_freeform_support=1` permettant d'ouvrir et redimensionner plusieurs applications côte à côte.
* **Barre des Tâches & Menu Démarrer** : Intégration d'un dock/taskbar de bureau pour basculer rapidement entre les fenêtres et lancer les applications.
* **Intégration Clavier & Souris** : Clic droit mappé sur l'action "Retour" (`BACK`), clic milieu sur "Applications récentes" (`RECENTS`), molette de défilement, et raccourcis claviers physiques standards (Alt+Tab pour changer de fenêtre, touche Super/Windows pour ouvrir le lanceur d'applications).

---

## 5. Compatibilité des Applications & Services Google FOSS

### Pont de Traduction ARM (Native Bridge)
* Plus de 90% des applications Android récentes ne contiennent pas de binaires x86_64 précompilés et s'appuient sur `arm64-v8a` ou `armeabi-v7a`.
* Noos Android intègre la couche **`libndk_translation`** (extraite de ChromeOS/WSA) avec branchement direct dans le runtime ART :
  ```properties
  ro.dalvik.vm.native.bridge=libndk_translation.so
  ro.enable.native.bridge.exec=1
  ro.product.cpu.abilist=x86_64,arm64-v8a,x86,armeabi-v7a,armeabi
  ```
* Enregistrement noyau `binfmt_misc` pour intercepter les en-têtes ELF ARM64 et les rediriger vers le traducteur binaire.

### Alternatives Open Source aux Services Google (microG)
* **microG GmsCore** : Réimplémentation libre et légère des services Google Play (géolocalisation, notifications push GCM/FCM, Maps API v2, stub SafetyNet/Play Integrity).
* **microG GsfProxy** : Passerelle de compatibilité pour le Google Services Framework.
* **Signature Spoofing** : Injection de la permission `android.permission.FAKE_PACKAGE_SIGNATURE` pour permettre à microG de se faire identifier de manière transparente par les applications sans altérer la sécurité du système.
* **Aurora Store** : Client libre et autonome du Google Play Store permettant de télécharger et mettre à jour toutes les applications sans compte Google obligatoire.
* **F-Droid** : Répertoire officiel d'applications libres.

---

## 6. Amorçage & Système de Fichiers Hybride

1. **Format de l'ISO** : ISO 9660 Hybride avec extensions Rock Ridge et amorçage double El Torito / EFI GPT (`isohybrid-gpt-basdat`).
2. **GRUB 2** :
   * UEFI : Image binaire monolithique `grubx64.efi` intégrée dans `efi.img` (FAT32).
   * BIOS : Amorçage PC standard.
3. **Partition Système** :
   * Système compressé en SquashFS (`system.sfs`) avec algorithme **Zstandard (zstd)** pour un temps de décompression ultra-rapide et un gain d'espace de 65%.
   * Prise en charge d'OverlayFS pour monter `/system` en lecture-écriture temporaire en RAM ou permanent sur disque.
4. **Installateur Automatisé** :
   * Script `noos-installer.sh` capable de partitionner automatiquement les disques NVMe et SATA SSD en GPT (ESP 512 Mo + ext4 NoosAndroid), d'installer le noyau, le ramdisk, l'image système et d'enregistrer l'entrée UEFI.

---

## 7. Architecture Graphique & Portage Android 17 (API 37 "Cinnamon Bun")

Le portage d'Android 17 sur x86_64 en environnement bare-metal / virtualisé KVM repose sur une chaîne graphique sans régression :

```
+-------------------------------------------------------------------------+
|                  APPLICATIONS & HWUI (RenderThread)                     |
|      Projectivy Launcher / Taskbar / SystemUI / Native Apps             |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                       SWIFTSHADER / ANGLE GLES                          |
|   vulkan.pastel.so (Vulkan 1.3 CPU) <-> libEGL_angle.so                 |
+-------------------------------------------------------------------------+
                                    |
              (dlopen android.hardware.graphics.mapper@4.0-impl.so)
                                    v
+-------------------------------------------------------------------------+
|                    HIDL MAPPER 4.0 & MINIGBM ALLOCATOR                  |
|   CrosGralloc4Mapper -> libminigbm_gralloc.so -> /dev/dri/card0         |
|   - Magic buffer minigbm : 0x63623031 ("cb01")                         |
|   - Passthrough manifest VINTF : android.hardware.graphics.mapper@4.0   |
+-------------------------------------------------------------------------+
                                    |
                           (GraphicBuffer / BLAST)
                                    v
+-------------------------------------------------------------------------+
|                          SURFACEFLINGER (SF)                            |
|   usesClientComposition=true, framebuffers 1280x800                    |
+-------------------------------------------------------------------------+
                                    |
                       (AIDL Composer 3.0 / HWC3)
                                    v
+-------------------------------------------------------------------------+
|                        RANCHU HARDWARE COMPOSER                         |
|   android.hardware.graphics.composer3-service.ranchu                   |
|   Commit atomique DRM KMS sur plan primaire                            |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                     NOYAU LINUX 6.12 & VIRTIO-GPU                       |
|   VirtIO-GPU DRM driver -> QEMU VirtIO VGA (Scanout actif 1280x800)     |
+-------------------------------------------------------------------------+
```

### Problème structurel résolu :
1. **La cause de l'écran noir initial** : `vulkan.pastel.so` (SwiftShader) requiert le HAL `android.hardware.graphics.mapper@4.0` via `libhidlbase`. Faute d'une bibliothèque nommée selon la norme HIDL passthrough (`android.hardware.graphics.mapper@4.0-impl.so`) et déclarée dans le manifest VINTF vendor, SwiftShader basculait sur le module legacy `gralloc.default.so`.
2. **Incompatibilité des structures de handles** : `gralloc.default.so` attendait un handle ashmem propriétaire AOSP (magic `0x3141592`), alors que l'allocateur actif `minigbm` générait des handles DMA-BUF DRM (magic `0x63623031`). Ce rejet entraînait `invalid gralloc handle` et faisait échouer la swapchain Vulkan (`QueueSignalReleaseImageANDROID failed: -1000001004`).
3. **Résolution définitive** : 
   - Injection de la bibliothèque `android.hardware.graphics.mapper@4.0-impl.so` dans `/vendor/lib64/hw/` encapsulant `CrosGralloc4Mapper`.
   - Déclaration formelle du service passthrough dans `/vendor/etc/vintf/manifest/android.hardware.graphics.mapper@4.0.xml`.
   - Les buffers graphiques sont directement négociés, SurfaceFlinger transmet le client target à HWC3, qui réalise le commit atomique DRM et active le scanout QEMU en 1280x800.

---

## 8. Amélioration Continue & Tests Automatisés

Le dépôt inclut une suite de tests automatisés (`tests/run_tests.sh`) intégrée dans les workflows GitHub Actions :
* Validation syntaxique et vérification de la complétude du defconfig Linux 6.12 LTS.
* Tests unitaires des profils TV et Bureau (propriétés, disposition des touches).
* Vérification des permissions microG et Signature Spoofing.
* Validation de la configuration Native Bridge ARM64.
* Tests de démarrage virtuel sous **QEMU KVM** avec validation par capture d'écran.

