# ==============================================================================
# Makefile — Noos Android x86_64
# Système d'exploitation Android modernisé pour Mini PC (TV & Bureau)
# ==============================================================================

SHELL := /bin/bash
PROJECT_ROOT := $(shell pwd)
TOOLS_BIN := $(PROJECT_ROOT)/tools/bin

.PHONY: all kernel initrd rootfs-tv rootfs-desktop iso test clean run-tv run-desktop help

all: iso test

help:
	@echo "Cibles disponibles pour Noos Android x86_64 :"
	@echo "  make iso             - Compile tous les sous-systèmes et génère l'ISO hybride"
	@echo "  make rootfs-tv       - Assemble l'image système pour profil TV (Leanback + NoosTV)"
	@echo "  make rootfs-desktop  - Assemble l'image système pour profil Bureau (Multi-fenêtres)"
	@echo "  make initrd          - Génère le ramdisk de démarrage précoce (initrd.img)"
	@echo "  make kernel          - Prépare/vérifie la configuration du noyau 6.6 LTS"
	@echo "  make test            - Exécute la batterie de tests continus (QEMU, profils, ARM)"
	@echo "  make run-tv          - Lance l'émulation QEMU KVM en mode TV"
	@echo "  make run-desktop     - Lance l'émulation QEMU KVM en mode Bureau"
	@echo "  make clean           - Nettoie les répertoires de sortie et de compilation"

kernel:
	@bash kernel/build_kernel.sh check
	@bash kernel/build_kernel.sh fetch-prebuilt

initrd:
	@bash initrd/build_initrd.sh

rootfs-tv:
	@bash rootfs/build_rootfs.sh --edition tv

rootfs-desktop:
	@bash rootfs/build_rootfs.sh --edition desktop

iso: initrd kernel rootfs-tv rootfs-desktop
	@bash installer/build_iso.sh

test:
	@bash tests/run_tests.sh

run-tv:
	@echo "Lancement de Noos Android (Profil TV) sous QEMU KVM..."
	@PATH="$(TOOLS_BIN):$$PATH" qemu-system-x86_64 \
		-enable-kvm -m 2048 -smp 4 \
		-bios /app/lib/extensions/Qemu/share/qemu/edk2-x86_64-code.fd \
		-cdrom out/iso/noos-android-x86_64.iso \
		-boot d -vga virtio -display gtk,gl=on \
		-net nic -net user,hostfwd=tcp::5555-:5555

run-desktop:
	@echo "Lancement de Noos Android (Profil Bureau) sous QEMU KVM..."
	@PATH="$(TOOLS_BIN):$$PATH" qemu-system-x86_64 \
		-enable-kvm -m 2048 -smp 4 \
		-bios /app/lib/extensions/Qemu/share/qemu/edk2-x86_64-code.fd \
		-cdrom out/iso/noos-android-x86_64.iso \
		-boot d -vga virtio -display gtk,gl=on \
		-net nic -net user,hostfwd=tcp::5555-:5555

clean:
	@echo "Nettoyage des artefacts..."
	@rm -rf build_out out
	@echo "✓ Nettoyage effectué."
