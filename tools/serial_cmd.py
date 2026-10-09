#!/usr/bin/env python3
"""
serial_cmd.py
Envoie une commande au shell console Android via le port série TCP (127.0.0.1:4555)
et attend la sortie jusqu'au marqueur de fin.
"""
import socket
import sys
import time
import uuid

def run_cmd(cmd: str, timeout: float = 10.0) -> str:
    marker = "DONE_" + uuid.uuid4().hex[:8]
    full_cmd = f"\n{cmd}\necho {marker}\n"
    
    s = socket.socket()
    s.settimeout(2.0)
    s.connect(('127.0.0.1', 4555))
    
    # Drain until console prompt is reached
    s.settimeout(0.3)
    buf = ""
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk.decode('latin1', errors='replace')
            if "console:/" in buf:
                break
        except (socket.timeout, BlockingIOError):
            break
    
    s.settimeout(1.0)
    s.sendall(full_cmd.encode('utf-8'))
    
    output = []
    start = time.time()
    
    while time.time() - start < timeout:
        try:
            chunk = s.recv(4096)
            if chunk:
                text = chunk.decode('latin1', errors='replace')
                output.append(text)
                accum = "".join(output)
                if marker in accum:
                    break
        except socket.timeout:
            pass
            
    s.close()
    full_text = "".join(output)
    return full_text

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: serial_cmd.py <command>")
        sys.exit(1)
    cmd = " ".join(sys.argv[1:])
    res = run_cmd(cmd)
    print(res)
