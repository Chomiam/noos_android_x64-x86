# 🚀 Noos Android x86_64

> **Modernisation et renaissance du projet open source Android-x86 pour Mini PC contemporains (TV & Bureau)**

[![Tests & Build](https://github.com/Chomiam/noos_android_x64-x86/actions/workflows/build_and_test.yml/badge.svg?branch=testing)](https://github.com/Chomiam/noos_android_x64-x86/actions)
[![Branche](https://img.shields.io/badge/branch-testing-blue.svg)](https://github.com/Chomiam/noos_android_x64-x86/tree/testing)
[![Licence](https://img.shields.io/badge/License-Apache%202.0%20%2F%20GPLv2-green.svg)](LICENSE)

---

## 📌 À Propos

Le projet originel Android-x86 ayant été abandonné sur une base Android 9.0 (Pie) avec un noyau 4.19, il est devenu incapable de fonctionner sur le matériel informatique récent ou de lancer les applications Android actuelles.

**Noos Android x86_64** remet au goût du jour cette version en apportant :
1. **Support du matériel récent (Mini PC modernes)** : Noyau Linux 6.12 LTS (avec support 6.18 LTS), pilotes graphiques Mesa 24+ (Intel Iris/Xe N95/N100, AMD Radeon RDNA2/RDNA3, VirtIO GPU), audio Sound Open Firmware (SOF), réseaux 2.5GbE (Intel i225/i226, Realtek RTL8125) et Wi-Fi 6E/7 (Intel AX210/BE200).
2. **Compatibilité maximale avec les applications Android actuelles** : Intégration du pont de traduction **Native Bridge (`libndk_translation`)** avec activation noyau `binfmt_misc`, `binderfs` et `memfd_create` permettant d'exécuter de manière transparente les applications compilées pour ARM64 (`arm64-v8a`) et ARMv7 sur architecture x86_64.
3. **Services Google Alternatifs Open Source (microG)** : Suite microG complète (`GmsCore`, `GsfProxy`, `FakeStore`), prise en charge du **Signature Spoofing**, et intégration des magasins d'applications libres **Aurora Store** et **F-Droid**.
4. **Deux Éditions Dédiées** :
   * 📺 **Édition TV (Salon & Téléviseur)** : Interface Leanback 10-foot UI, prise en charge native des télécommandes infrarouge / RF 2.4G / HDMI-CEC, manettes Xbox/PS5, et intégration préinstallée de l'application **NoosTV** pour le streaming IPTV/VOD.
   * 🖥️ **Édition Bureau (Poste de travail)** : Mode multi-fenêtres AOSP Freeform (fenêtres redimensionnables), barre des tâches et menu d'applications, intégration complète de la souris (clic droit = retour, molette) et raccourcis clavier PC (Alt+Tab, touche Super).

---

## ⚙️ Structure du Projet

```text
noos_android_x64-x86/
├── kernel/                     # Configuration noyau 6.12 LTS & scripts de build
│   ├── config-6.12-noos-x86_64 # Defconfig optimisé Mini PC & Android IPC
│   ├── build_kernel.sh         # Script de validation et compilation
│   └── cmdline.cfg             # Ligne de commande de démarrage par profil
├── initrd/                    # Ramdisk précoce de détection et montage
│   ├── init                   # Script d'orchestration précoce
│   └── build_initrd.sh        # Générateur d'initrd.img
├── rootfs/                    # Assemblage de l'arborescence système Android
│   ├── build_rootfs.sh        # Création de system.sfs (SquashFS zstd)
│   ├── fstab.noos             # Table de montage des partitions
│   ├── init.noos.rc           # Services Android init
│   └── ueventd.noos.rc        # Permissions DRM, son et périphériques
├── editions/                  # Profils spécialisés
│   ├── tv/                    # TV Edition (NoosTV, Leanback, télécommandes)
│   └── desktop/               # Desktop Edition (Freeform, clavier/souris)
├── compatibility/             # Couche de compatibilité d'applications
│   ├── native_bridge/         # Traduction ARM (libndk_translation)
│   └── microg/                # Services Google FOSS & Signature Spoofing
├── installer/                 # Chargeur GRUB 2 & installateur sur disque
│   ├── grub/grub.cfg          # Menu de démarrage GRUB 2
│   ├── noos-installer.sh      # Script d'installation sur NVMe/SATA
│   └── build_iso.sh           # Générateur de l'ISO hybride UEFI/BIOS
├── tests/                     # Suite de tests continus & virtualisation
│   ├── run_tests.sh           # Lanceur de tests global
│   ├── test_qemu_uefi.sh      # Test virtuel UEFI sous QEMU KVM
│   ├── test_qemu_bios.sh      # Test virtuel BIOS sous QEMU KVM
│   └── ...                    # Tests des profils, ARM et microG
├── tools/                     # Outils portables utilisateur (xorriso, mtools, QEMU)
└── Makefile                   # Commandes de pilotage du projet
```

---

## 🛠️ Démarrage Rapide

### 1. Prérequis
Les outils de virtualisation et d'assemblage sont configurés dans l'espace utilisateur ou via Flatpak :
* **QEMU 11 & KVM** : Installé et opérationnel sans privilèges root.
* **Outils d'images** : `xorriso`, `mtools`, `mksquashfs`, `unsquashfs` intégrés dans `tools/bin/`.

### 2. Commandes Makefile

```bash
# Afficher l'aide
make help

# Assembler l'ensemble du système et générer l'ISO hybride
make iso

# Exécuter la batterie de tests continus (7 tests avec QEMU KVM)
make test

# Lancer la machine virtuelle en mode TV (Leanback)
make run-tv

# Lancer la machine virtuelle en mode Bureau (Desktop)
make run-desktop
```

---

## 🧪 Amélioration Continue & Tests

Le script `tests/run_tests.sh` valide automatiquement :
1. ✅ La complétude du defconfig noyau Linux 6.12 LTS (BinderFS, MemFD, PSI, DMA-BUF heaps, binfmt_misc, DRM Intel/AMD, SOF, joystick).
2. ✅ Le profil TV (densité DPI 280, HDMI-CEC, mappage télécommande, présence de NoosTV.apk).
3. ✅ Le profil Bureau (multi-fenêtrage Freeform, raccourcis clavier Alt+Tab/Super, souris).
4. ✅ La configuration du pont de traduction ARM64 (Native Bridge).
5. ✅ La conformité des permissions microG et du Signature Spoofing.
6. ✅ Le démarrage virtuel en mode BIOS Legacy avec QEMU KVM.
7. ✅ Le démarrage virtuel en mode UEFI (OVMF/EDK2) avec QEMU KVM.

---

## 🛡️ Politique Git & Règles de Développement

Conformément à la politique globale de développement de l'écosystème Noos (`AGENTS.md` & `GIT_POLICY.md`) :
* **Travail exclusif sur la branche `testing`** (`git checkout testing`).
* **Pas de build lourd sur la machine locale** : La compilation binaire complète est déléguée aux serveurs distants via GitHub Actions (`.github/workflows/build_and_test.yml`).
* **Commits rédigés en français** avec explications détaillées.

---

## 📄 Licence

Ce projet est sous licence double Apache 2.0 et GNU General Public License v2 (pour les composants noyau et scripts d'amorce).
