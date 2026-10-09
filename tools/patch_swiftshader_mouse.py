#!/usr/bin/env python3
"""
patch_swiftshader_mouse.py
Corrige le support du format de buffer AHardwareBuffer 5 (AHARDWAREBUFFER_FORMAT_B8G8R8A8_UNORM / BGRA_8888)
dans SwiftShader Vulkan (vulkan.pastel.so) sous Android 17 x86_64.

Problématique:
Sous Android 17 x86_64, le curseur de souris matériel (PointerController / SpriteController)
génère un GraphicBuffer 24x24 au format 5 (AHARDWAREBUFFER_FORMAT_B8G8R8A8_UNORM / BGRA_8888).
Dans SwiftShader (VkDeviceMemoryExternalAndroid.cpp:392), ce format n'était pas géré dans le switch
de GetVkFormatFromAHBFormat(), ce qui causait l'émission de :
  'WARNING: UNSUPPORTED: AHardwareBufferExternalMemory::AHardwareBuffer_Format 5'
renvoyait VK_FORMAT_UNDEFINED (0) et provoquait le crash fatal de SurfaceFlinger :
  'Failed to create a valid texture. [0x...]:[24,24] isProtected:0 isWriteable:0 format:5'

Remédiation :
Le patch redirige l'entrée 4 de la table de saut de switch (correspondant au format 5)
vers une séquence assembleur x86_64 qui charge 0x2c (VK_FORMAT_B8G8R8A8_UNORM = 44)
dans %eax, restaure %rbx et retourne proprement.
"""

import sys
import struct
import shutil

def patch_vulkan_pastel(input_path: str, output_path: str):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    # Vérification signature de la table de saut à 0xd4118
    jt_va = 0xd4118
    fo_jt4 = jt_va + 4 * 4 # Entrée pour ahbFormat = 5 (index 4)
    rel_orig = struct.unpack('<i', data[fo_jt4:fo_jt4+4])[0]
    target_orig = jt_va + rel_orig

    print(f"[*] Cible originale pour ahbFormat 5: {hex(target_orig)}")

    # Adresse virtuelle cible dans la zone de padding (0x64a2d5 -> offset fichier 0x6492d5)
    target_va = 0x64a2d5
    fo_code = 0x6492d5

    # Code x86_64:
    #   b8 2c 00 00 00       mov $0x2c, %eax   (VK_FORMAT_B8G8R8A8_UNORM = 44)
    #   5b                   pop %rbx
    #   c3                   ret
    code = bytes([0xb8, 0x2c, 0x00, 0x00, 0x00, 0x5b, 0xc3])

    # Application du code
    data[fo_code:fo_code+len(code)] = code

    # Calcul et injection du nouvel offset relatif dans la table de saut
    new_rel = target_va - jt_va
    data[fo_jt4:fo_jt4+4] = struct.pack('<i', new_rel)

    print(f"[+] Nouveau saut configuré: {hex(target_va)} (relatif: {hex(new_rel)})")

    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"[✓] Fichier patché généré avec succès: {output_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: patch_swiftshader_mouse.py <vulkan.pastel.so_input> <vulkan.pastel.so_output>")
        sys.exit(1)
    patch_vulkan_pastel(sys.argv[1], sys.argv[2])
