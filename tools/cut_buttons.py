"""Klipper Daniels knapper og skilt ut til Media/*.tga (128 × 64).

    python tools/cut_buttons.py

- art/knapper.png: 3 × 4 røde knapper med symbol → Media/btn_<navn>.tga
- art/skilt.png:   3 × 4 røde skilt med tekst (raden er gjentatt) → Media/lbl_<navn>.tga
Bakgrunnen og den myke skyggen fjernes fra kantene og innover; hver knapp finnes som en sammenhengende flate.
Rekkefølgen i arket (rad for rad) gir navnene; None = hopp over (duplikat).
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media")
SHEETS = [
    ("knapper.png", "btn_", [
        "close", "ok", "next",
        "prev", None, "chest",
        "settings", "search", "report",
        "refresh", None, "help",
    ]),
    ("skilt.png", "lbl_", [
        "rapport", "ferdig", "klar",
        "fiske", "fangst", "agn",
        None, None, None,
        None, None, None,
    ]),
]


def flood_from_border(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def components(fg):
    h, w = fg.shape
    label = np.zeros((h, w), np.int32)
    boxes = []
    n = 0
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if fg[y0, x0] and not label[y0, x0]:
                n += 1
                q = deque([(y0, x0)])
                label[y0, x0] = n
                y1 = y2 = y0
                x1 = x2 = x0
                size = 0
                while q:
                    y, x = q.popleft()
                    size += 1
                    y1, y2, x1, x2 = min(y1, y), max(y2, y), min(x1, x), max(x2, x)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not label[ny, nx]:
                            label[ny, nx] = n
                            q.append((ny, nx))
                if size > 5000:
                    boxes.append((n, x1, y1, x2 + 1, y2 + 1))
    return label, boxes


def cut(src, prefix, names):
    rgb = np.asarray(Image.open(os.path.join(ROOT, "art", src)).convert("RGB")).astype(np.float32)
    lo, hi = rgb.min(2), rgb.max(2)
    # Lys bakgrunn og den grå skyggen under knappene (lite farge, ganske lys)
    bg = flood_from_border((lo >= 150) & (hi - lo < 18))
    fg = ~bg
    label, boxes = components(fg)
    boxes.sort(key=lambda b: (round(b[2] / 100), b[1]))  # rad for rad, venstre mot høyre
    print("fant", len(boxes), "knapper")
    assert len(boxes) == len(names), "forventet %d knapper i %s" % (len(names), src)

    # Myk kant: alfa fra hvor mørk kanten er mot den lyse bakgrunnen
    bg_img = Image.fromarray((bg * 255).astype(np.uint8))
    band = (np.asarray(bg_img.filter(ImageFilter.MaxFilter(5))) > 0) & ~bg
    dark = 255.0 - rgb.mean(2)
    alpha = np.where(bg, 0.0, 1.0)
    alpha[band] = np.clip((dark[band] - 60.0) / 120.0, 0, 1)

    for name, (n, x1, y1, x2, y2) in zip(names, boxes):
        if name is None:
            continue
        m = label[y1:y2, x1:x2] == n
        a = np.where(m, alpha[y1:y2, x1:x2], 0)
        a = np.maximum(a, band[y1:y2, x1:x2] * alpha[y1:y2, x1:x2] * (label[y1:y2, x1:x2] == 0))
        img = np.dstack([rgb[y1:y2, x1:x2], a * 255]).astype(np.uint8)
        out = Image.fromarray(img, "RGBA").resize((128, 64), Image.LANCZOS)
        path = os.path.join(OUT, prefix + name + ".tga")
        out.save(path)
        print(name, (x2 - x1, y2 - y1), "->", os.path.basename(path))


if __name__ == "__main__":
    for sheet in SHEETS:
        cut(*sheet)
