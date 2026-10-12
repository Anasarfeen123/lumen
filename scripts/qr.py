#!/usr/bin/env python3
"""qr.py — a QR code as a PNG, standard library only (no qrencode needed).

  qr.py <text> <out.png> [--scale 8]

Byte mode, error correction level M (about 15 % of the code can be damaged),
versions 1–10 (up to 213 bytes): links and addresses, not essays. Lumen uses it
to put things on a phone by pointing its camera: the KDE Connect app, this
computer's address for Lumen Link.
"""
import argparse
import struct
import sys
import zlib

# ── Galois field GF(256), polynomial 0x11D ──────────────────────────────────
EXP, LOG = [0] * 512, [0] * 256
_x = 1
for _i in range(255):
    EXP[_i] = _x
    LOG[_x] = _i
    _x <<= 1
    if _x & 0x100:
        _x ^= 0x11D
for _i in range(255, 512):
    EXP[_i] = EXP[_i - 255]


def gmul(a, b):
    return 0 if a == 0 or b == 0 else EXP[LOG[a] + LOG[b]]


def rs_generator(n):
    g = [1]
    for i in range(n):
        g = [a ^ gmul(b, EXP[i]) for a, b in zip(g + [0], [0] + g)]
    return g


def rs_ecc(data, n):
    gen = rs_generator(n)
    rem = list(data) + [0] * n
    for i in range(len(data)):
        c = rem[i]
        if c:
            for j in range(1, len(gen)):
                rem[i + j] ^= gmul(gen[j], c)
    return rem[len(data):]


# ── level M, versions 1–10: (ec codewords per block, [(blocks, data codewords)…]) ──
TABLE = {
    1: (10, [(1, 16)]), 2: (16, [(1, 28)]), 3: (26, [(1, 44)]), 4: (18, [(2, 32)]),
    5: (24, [(2, 43)]), 6: (16, [(4, 27)]), 7: (18, [(4, 31)]),
    8: (22, [(2, 38), (2, 39)]), 9: (22, [(3, 36), (2, 37)]), 10: (26, [(4, 43), (1, 44)]),
}
ALIGN = {1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34],
         7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50]}


def capacity(v):
    return sum(b * d for b, d in TABLE[v][1])


def encode_data(data, v):
    bits = []
    def put(val, n):
        bits.extend((val >> (n - 1 - i)) & 1 for i in range(n))
    put(0b0100, 4)                                   # byte mode
    put(len(data), 8 if v < 10 else 16)
    for b in data:
        put(b, 8)
    cap = capacity(v) * 8
    put(0, min(4, cap - len(bits)))                  # terminator
    while len(bits) % 8:
        bits.append(0)
    words = [int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8)]
    i = 0
    while len(words) < capacity(v):                  # pad bytes, alternating
        words.append(0xEC if i % 2 == 0 else 0x11)
        i += 1
    return words


def interleave(words, v):
    ecn, groups = TABLE[v]
    blocks, i = [], 0
    for count, size in groups:
        for _ in range(count):
            blocks.append(words[i:i + size])
            i += size
    eccs = [rs_ecc(b, ecn) for b in blocks]
    out = []
    for k in range(max(len(b) for b in blocks)):
        out.extend(b[k] for b in blocks if k < len(b))
    for k in range(ecn):
        out.extend(e[k] for e in eccs)
    return out


def bch(value, poly, bits):
    v = value << bits
    top = poly.bit_length() - 1
    while v.bit_length() > top:
        v ^= poly << (v.bit_length() - poly.bit_length())
    return (value << bits) | v


def matrix(v, codewords, mask):
    n = 17 + 4 * v
    m = [[None] * n for _ in range(n)]

    def finder(r, c):
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                rr, cc = r + dr, c + dc
                if 0 <= rr < n and 0 <= cc < n:
                    on = (0 <= dr <= 6 and dc in (0, 6)) or (0 <= dc <= 6 and dr in (0, 6)) or (2 <= dr <= 4 and 2 <= dc <= 4)
                    m[rr][cc] = 1 if on else 0
    finder(0, 0); finder(0, n - 7); finder(n - 7, 0)
    for i in range(8, n - 8):                       # timing
        m[6][i] = m[i][6] = 1 if i % 2 == 0 else 0
    pos = ALIGN[v]
    for r in pos:
        for c in pos:
            # every combination except the three that sit on a finder
            if (r < 9 and c < 9) or (r < 9 and c > n - 10) or (r > n - 10 and c < 9):
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    m[r + dr][c + dc] = 1 if max(abs(dr), abs(dc)) != 1 else 0
    m[n - 8][8] = 1                                 # dark module
    # reserve format and version areas
    for i in range(9):
        if m[8][i] is None: m[8][i] = 0
        if m[i][8] is None: m[i][8] = 0
    for i in range(8):
        if m[8][n - 1 - i] is None: m[8][n - 1 - i] = 0
        if m[n - 1 - i][8] is None: m[n - 1 - i][8] = 0
    if v >= 7:
        for i in range(6):
            for j in range(3):
                m[i][n - 11 + j] = 0
                m[n - 11 + j][i] = 0
    reserved = [[cell is not None for cell in row] for row in m]

    # data, in the zig-zag
    bits = [(w >> (7 - i)) & 1 for w in codewords for i in range(8)]
    k, up, col = 0, True, n - 1
    while col > 0:
        if col == 6:
            col -= 1
        rows = range(n - 1, -1, -1) if up else range(n)
        for r in rows:
            for c in (col, col - 1):
                if not reserved[r][c]:
                    m[r][c] = bits[k] if k < len(bits) else 0
                    k += 1
        up = not up
        col -= 2

    masks = [lambda r, c: (r + c) % 2 == 0, lambda r, c: r % 2 == 0, lambda r, c: c % 3 == 0,
             lambda r, c: (r + c) % 3 == 0, lambda r, c: (r // 2 + c // 3) % 2 == 0,
             lambda r, c: (r * c) % 2 + (r * c) % 3 == 0, lambda r, c: ((r * c) % 2 + (r * c) % 3) % 2 == 0,
             lambda r, c: ((r + c) % 2 + (r * c) % 3) % 2 == 0]
    f = masks[mask]
    for r in range(n):
        for c in range(n):
            if not reserved[r][c] and f(r, c):
                m[r][c] ^= 1

    # format information: level M = 00, then the mask (bit 0 = least significant)
    fmt = bch((0b00 << 3) | mask, 0x537, 10) ^ 0x5412
    bit = lambda k: (fmt >> k) & 1
    for k in range(6):
        m[k][8] = bit(k)
    m[7][8] = bit(6)
    m[8][8] = bit(7)
    m[8][7] = bit(8)
    for k in range(9, 15):
        m[8][14 - k] = bit(k)
    for k in range(8):
        m[8][n - 1 - k] = bit(k)
    for k in range(8, 15):
        m[n - 15 + k][8] = bit(k)
    m[n - 8][8] = 1                                 # the dark module
    if v >= 7:
        ver = bch(v, 0x1F25, 12)
        for i in range(18):
            b = (ver >> i) & 1
            r, c = i // 3, n - 11 + i % 3
            m[r][c] = b
            m[c][r] = b
    return m


def penalty(m):
    n, score = len(m), 0
    for grid in (m, [list(x) for x in zip(*m)]):    # rows, then columns
        for row in grid:
            run, prev = 0, None
            for x in row:
                if x == prev:
                    run += 1
                else:
                    if run >= 5:
                        score += run - 2
                    run, prev = 1, x
            if run >= 5:
                score += run - 2
            s = "".join(map(str, row))
            score += 40 * (s.count("10111010000") + s.count("00001011101"))
    for r in range(n - 1):
        for c in range(n - 1):
            if m[r][c] == m[r][c + 1] == m[r + 1][c] == m[r + 1][c + 1]:
                score += 3
    dark = sum(map(sum, m)) * 100 / (n * n)
    score += int(abs(dark - 50) // 5) * 10
    return score


def make(text):
    data = text.encode("utf-8")
    v = next((v for v in TABLE if capacity(v) >= len(data) + (2 if v < 10 else 3)), None)
    if v is None:
        raise ValueError("too long for a QR code here (%d bytes; 213 at most)" % len(data))
    words = interleave(encode_data(data, v), v)
    best = min(range(8), key=lambda k: penalty(matrix(v, words, k)))
    return matrix(v, words, best)


def png(m, path, scale=8, border=4):
    n = len(m)
    size = (n + 2 * border) * scale
    rows = []
    for y in range(size):
        r = y // scale - border
        line = bytearray([0])
        for x in range(size):
            c = x // scale - border
            dark = 0 <= r < n and 0 <= c < n and m[r][c] == 1
            line.append(0 if dark else 255)
        rows.append(bytes(line))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 0, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def main():
    p = argparse.ArgumentParser(description="QR code → PNG")
    p.add_argument("text")
    p.add_argument("out")
    p.add_argument("--scale", type=int, default=8)
    a = p.parse_args()
    try:
        png(make(a.text), a.out, a.scale)
    except ValueError as e:
        sys.exit(str(e))
    print(a.out)


if __name__ == "__main__":
    main()
