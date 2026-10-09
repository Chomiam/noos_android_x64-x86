#!/usr/bin/env python3
"""
Convert Android sparse image format to raw ext4 image.
Pure Python, no dependencies.
"""

import sys
import struct

SPARSE_HEADER_MAGIC = 0xED26FF3A
CHUNK_TYPE_RAW = 0xCAC1
CHUNK_TYPE_FILL = 0xCAC2
CHUNK_TYPE_DONT_CARE = 0xCAC3
CHUNK_TYPE_CRC32 = 0xCAC4

def simg2img(src_path, dst_path):
    with open(src_path, "rb") as fin:
        header = fin.read(28)
        if len(header) < 28:
            raise ValueError("File too short for sparse header")
        
        magic, major, minor, file_hdr_sz, chunk_hdr_sz, blk_sz, total_blks, total_chunks, crc32 = struct.unpack(
            "<IHHHHIIII", header
        )
        
        if magic != SPARSE_HEADER_MAGIC:
            print(f"Warning: Magic {magic:#x} does not match sparse magic {SPARSE_HEADER_MAGIC:#x}. Assuming raw image.")
            fin.seek(0)
            with open(dst_path, "wb") as fout:
                while chunk := fin.read(1024 * 1024):
                    fout.write(chunk)
            return

        print(f"Sparse Image detected: blk_sz={blk_sz}, total_blks={total_blks}, chunks={total_chunks}")
        
        # Skip remaining header if any
        if file_hdr_sz > 28:
            fin.seek(file_hdr_sz)

        with open(dst_path, "wb") as fout:
            out_blocks = 0
            for i in range(total_chunks):
                chk_hdr = fin.read(chunk_hdr_sz)
                if len(chk_hdr) < 12:
                    break
                chunk_type, reserved, chunk_sz, total_sz = struct.unpack("<HHII", chk_hdr[:12])
                data_sz = total_sz - chunk_hdr_sz

                if chunk_type == CHUNK_TYPE_RAW:
                    expected_bytes = chunk_sz * blk_sz
                    copied = 0
                    while copied < expected_bytes:
                        to_read = min(1024 * 1024, expected_bytes - copied)
                        buf = fin.read(to_read)
                        if not buf:
                            break
                        fout.write(buf)
                        copied += len(buf)
                    out_blocks += chunk_sz

                elif chunk_type == CHUNK_TYPE_FILL:
                    fill_val = fin.read(4)
                    pattern = fill_val * (blk_sz // 4)
                    for _ in range(chunk_sz):
                        fout.write(pattern)
                    out_blocks += chunk_sz

                elif chunk_type == CHUNK_TYPE_DONT_CARE:
                    fout.seek(chunk_sz * blk_sz, 1)
                    out_blocks += chunk_sz

                elif chunk_type == CHUNK_TYPE_CRC32:
                    fin.read(4)

                else:
                    raise ValueError(f"Unknown chunk type {chunk_type:#x} at chunk {i}")

            print(f"Extraction complete: {out_blocks} blocks ({out_blocks * blk_sz / (1024*1024):.1f} MB) written.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <sparse_img> <raw_img>")
        sys.exit(1)
    simg2img(sys.argv[1], sys.argv[2])
