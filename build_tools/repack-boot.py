#!/usr/bin/env python3
"""Repack a OnePlus kona (SM8250) boot image (Android header v2) with a new kernel Image.

Handles the full v2 layout: header | kernel | ramdisk | second | recovery_dtbo | dtb.
Keeps ramdisk/cmdline/name/id/os_version; replaces kernel, and optionally the dtb.
Output is sized to its content (no stale AVB footer) — suitable for an unlocked bootloader.
"""
import struct
import sys

PAGE = 4096


def pages(n):
    return (n + PAGE - 1) // PAGE


def pad(x, ps=PAGE):
    r = len(x) % ps
    return x + (b"\0" * (ps - r) if r else b"")


def main():
    if len(sys.argv) not in (4, 5):
        sys.exit(f"usage: {sys.argv[0]} <orig_boot.img> <new_Image> <out_boot.img> [new_dtb]")
    src, new_img, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    new_dtb = sys.argv[4] if len(sys.argv) == 5 else None

    d = open(src, "rb").read()
    if d[:8] != b"ANDROID!":
        sys.exit("not an Android boot image")

    (ks, ka, rs, ra, ss, sa, ta, ps, hv, osv) = struct.unpack_from("<10I", d, 8)
    if hv != 2 or ps != PAGE:
        sys.exit(f"unexpected header_version={hv} page_size={ps} (expected 2 / 4096)")

    name = d[48:64]
    cmdline = d[64:576]
    img_id = d[576:608]
    extra = d[608:1632]

    rdtbo_size, = struct.unpack_from("<I", d, 1632)
    rdtbo_off, = struct.unpack_from("<Q", d, 1636)
    header_size, = struct.unpack_from("<I", d, 1644)
    dtb_size, = struct.unpack_from("<I", d, 1648)
    dtb_addr, = struct.unpack_from("<Q", d, 1652)

    k_off = ps
    r_off = k_off + pages(ks) * ps
    s_off = r_off + pages(rs) * ps
    rd_off = s_off + pages(ss) * ps
    dtb_off = rd_off + pages(rdtbo_size) * ps

    ramdisk = d[r_off:r_off + rs]
    second = d[s_off:s_off + ss]
    rdtbo = d[rd_off:rd_off + rdtbo_size]
    dtb = open(new_dtb, "rb").read() if new_dtb else d[dtb_off:dtb_off + dtb_size]

    kernel = open(new_img, "rb").read()

    hdr = bytearray(ps)
    hdr[0:8] = b"ANDROID!"
    struct.pack_into("<10I", hdr, 8, len(kernel), ka, len(ramdisk), ra,
                     len(second), sa, ta, ps, 2, osv)
    hdr[48:64] = name
    hdr[64:576] = cmdline
    hdr[576:608] = img_id
    hdr[608:1632] = extra
    # v2 tail
    struct.pack_into("<I", hdr, 1632, len(rdtbo))
    struct.pack_into("<Q", hdr, 1636, 0 if not rdtbo else (ps + pages(len(kernel)) * ps +
                     pages(len(ramdisk)) * ps + pages(len(second)) * ps) * ps // ps * 0 + 0)
    struct.pack_into("<I", hdr, 1644, header_size)
    struct.pack_into("<I", hdr, 1648, len(dtb))
    struct.pack_into("<Q", hdr, 1652, dtb_addr)

    out = (bytes(hdr) + pad(kernel) + pad(ramdisk) + pad(second) + pad(rdtbo) + pad(dtb))
    with open(out_path, "wb") as f:
        f.write(out)

    print(f"wrote {out_path}: {len(out)} bytes "
          f"(kernel {len(kernel)}, ramdisk {len(ramdisk)}, second {len(second)}, "
          f"recovery_dtbo {len(rdtbo)}, dtb {len(dtb)})")


if __name__ == "__main__":
    main()
