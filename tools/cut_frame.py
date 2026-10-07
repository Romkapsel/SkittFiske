"""Klipper Daniels fiskeramme (art/fiskeramme.png, hvit bakgrunn) ut til Media/frame.tga (1024 × 512, gjennomsiktig).

    python tools/cut_frame.py

Den hvite bakgrunnen fjernes fra kantene og innover (flomfylling), så pergamentet i midten blir stående.
Kantpikslene får myk overgang: fargen regnes tilbake fra «blandet med hvitt». Skriptet skriver også ut hvor
pergamentet ligger (i piksler i frame.tga) – de tallene står i LAYOUT i UI/Window.lua.
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "fiskeramme.png")
OUT = os.path.join(ROOT, "Media", "frame.tga")
TEX_W, TEX_H = 1024, 512


def flood(mask):
    """Alle sanne piksler i mask som henger sammen med kanten av bildet."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not seen[y, x]:
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


def main():
    im = Image.open(SRC).convert("RGB")
    rgb = np.asarray(im).astype(np.float32)
    lo = rgb.min(2)
    sat = rgb.max(2) - lo
    # Hvitt og den lyse, grå skyggen rundt «klistremerket» regnes som bakgrunn
    bg = flood((lo >= 238) | ((lo >= 165) & (sat < 22)))
    # Små hvite lommer helt ytterst ved kanten (ikke koblet til resten av bakgrunnen) er også bakgrunn (Daniel 7. okt)
    near = np.asarray(Image.fromarray((bg * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
    bg |= near & (lo >= 160) & (sat < 30)

    # Myk kant: et bånd rundt bakgrunnen. Alfa fra hvor mørk pikselen er (kanten av rammen er mørk), og fargen
    # hentes fra den mørke kanten innenfor – ellers blir det en lys glorie rundt fisken.
    bg_img = Image.fromarray((bg * 255).astype(np.uint8))
    band = np.asarray(bg_img.filter(ImageFilter.MaxFilter(7)), dtype=np.uint8) > 0
    band &= ~bg
    dark = 255.0 - rgb.mean(2)
    alpha = np.ones(lo.shape, np.float32)
    alpha[bg] = 0
    a_band = np.clip((dark - 8.0) / 170.0, 0, 1)
    alpha[band] = a_band[band]
    out = rgb.copy()
    inner = Image.fromarray(np.where((~bg & ~band)[..., None], rgb, 255).astype(np.uint8))
    edge_col = np.asarray(inner.filter(ImageFilter.MinFilter(9)), dtype=np.float32)
    out[band] = edge_col[band]
    # Gjennomsiktige piksler får den mørke kantfargen, ikke hvitt: når bildet skaleres (her og i spillet),
    # blandes fargen deres inn i kanten – hvitt ga lyse prikker rundt fisken (Daniel 7. okt)
    far = Image.fromarray(np.where((~bg)[..., None], out, 255).astype(np.uint8)).filter(ImageFilter.MinFilter(15))
    out[bg] = np.asarray(far, dtype=np.float32)[bg]
    out[bg & (out.min(2) > 120)] = (34, 26, 20)

    rgba = np.dstack([out, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    box = img.getbbox()
    img = img.crop(box)
    scale = min(TEX_W / img.width, TEX_H / img.height)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (TEX_W, TEX_H), (0, 0, 0, 0))
    ox, oy = (TEX_W - img.width) // 2, (TEX_H - img.height) // 2
    canvas.paste(img, (ox, oy))
    canvas.save(OUT)

    # Hvor er pergamentet? Lyse, gulbrune piksler som henger sammen med midten
    c = np.asarray(canvas).astype(np.int32)
    r, g, b, a = c[..., 0], c[..., 1], c[..., 2], c[..., 3]
    parch = (a > 200) & (r > 120) & (r - b > 25) & (g > 100) & (r < 240)
    h, w = parch.shape
    seen = np.zeros_like(parch)
    q = deque([(h // 2, w // 2)])
    seen[h // 2, w // 2] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and parch[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    ys, xs = np.nonzero(seen)
    print("ramme i tekstur:", (ox, oy, ox + img.width, oy + img.height))
    print("pergament: x", xs.min(), "-", xs.max(), " y", ys.min(), "-", ys.max())
    for y in range(ys.min(), ys.max() + 1, 20):
        row = np.nonzero(seen[y])[0]
        if len(row):
            print(f"  y={y}: x {row.min()}-{row.max()}")


if __name__ == "__main__":
    main()
