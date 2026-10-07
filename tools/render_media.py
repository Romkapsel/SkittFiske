"""Tegner de små bildene til Skitt Fiske (Media/*.tga) og en forhåndsvisning av vinduet (docs/vindu-forhandsvisning.png).

    python tools/cut_frame.py      # først: fiskerammen fra Daniels bilde (art/fiskeramme.png) → Media/frame.tga
    python tools/render_media.py   # så: ringer, haker, stolpe, rapportplata og forhåndsvisningen

Plasseringene i LAYOUT er piksler i Media/frame.tga (1024 × 512) og står likt i UI/Window.lua – endre begge.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media")
SS = 2

# Pergamentet i rammen er en oval: x 295–778, y 97–418 (tools/cut_frame.py). Treplata nede til høyre: x 605–800, y 433–462.
LAYOUT = {
    "crop": (168, 856),
    "title": 104, "zone": 146, "divider": 168,
    "bar": (386, 186, 300, 28),
    "line2": 232, "pole": 382, "lure": 470,
    "rings": (596, 222, 40, 46),
    "box": (392, 272, 288, 112),
    "summary": 280, "value": 298, "rows": 320, "row_step": 19,
    "report": (672, 431, 66, 34),
    "close": (738, 94, 44, 22),
}
INK = (70, 44, 22)
HEAD = (110, 46, 18)


def smooth_noise(w, h, cells, seed):
    r = np.random.default_rng(seed)
    small = Image.fromarray((r.random((max(2, h // cells), max(2, w // cells))) * 255).astype(np.uint8))
    return np.asarray(small.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0


def mask_img(w, h, draw_fn):
    m = Image.new("L", (w, h), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def arr(m):
    return np.asarray(m, dtype=np.float32) / 255.0


def blur(a, r):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255.0


def dilate(a, px):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    size = px * 2 + 1
    return np.asarray(img.filter(ImageFilter.MaxFilter(size)), dtype=np.float32) / 255.0


def bevel(mask, r, strength):
    """Lys øverst til venstre, skygge nederst til høyre, ut fra en uskarp kopi av formen."""
    b = blur(mask, r)
    k = max(1, int(r * 0.6))
    return (np.roll(np.roll(b, k, 0), k, 1) - np.roll(np.roll(b, -k, 0), -k, 1)) * strength


def wood(w, h, base, seed, scale=1.0, vertical=False, warp=1.6):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    if vertical:
        x, y = y, x
    n1 = smooth_noise(w, h, int(60 * scale), seed)
    n2 = smooth_noise(w, h, int(14 * scale), seed + 1)
    grain = np.sin(y * 0.09 / scale + n1 * warp * 3.0 + x * 0.001) * 0.5 + 0.5
    grain = grain ** 3.0
    streak = np.sin(y * 0.31 / scale + n2 * warp * 2.0) * 0.5 + 0.5
    fine = smooth_noise(w, h, 3, seed + 2)
    v = 0.80 + 0.22 * grain + 0.06 * streak - 0.10 * n2 + 0.06 * (fine - 0.5)
    rgb = np.stack([np.full((h, w), c, np.float32) for c in base], -1) * v[..., None]
    return rgb


def compose(dst, src_rgb, mask):
    """Legg src (h,w,3) over dst (h,w,4) med maske 0..1."""
    a = mask[..., None]
    dst[..., :3] = dst[..., :3] * (1 - a) + src_rgb * a
    dst[..., 3] = np.maximum(dst[..., 3], mask * 255)


def save(img_arr, name, size, pad=None):
    """pad = (bredde, høyde) i toerpotens: bildet legges øverst til venstre (UI bruker SetTexCoord)."""
    img = Image.fromarray(np.clip(img_arr, 0, 255).astype(np.uint8), "RGBA")
    img = img.resize(size, Image.LANCZOS)
    out = img
    if pad:
        out = Image.new("RGBA", pad, (0, 0, 0, 0))
        out.paste(img, (0, 0))
    out.save(os.path.join(OUT, name))
    return img


def rrect(d, box, r, fill=255):
    d.rounded_rectangle([c * SS for c in box[:4]], radius=r * SS, fill=fill)


def S(pts):
    return [(x * SS, y * SS) for x, y in pts]


# ── rammen: fisken ──────────────────────────────────────────────────────────
def render_ring():
    s = 64 * SS
    out = np.zeros((s, s, 4), np.float32)
    outer = arr(mask_img(s, s, lambda d: d.ellipse([2 * SS, 2 * SS, s - 2 * SS, s - 2 * SS], fill=255)))
    hole = arr(mask_img(s, s, lambda d: d.ellipse([9 * SS, 9 * SS, s - 9 * SS, s - 9 * SS], fill=255)))
    ring = np.clip(outer - hole, 0, 1)
    col = np.zeros((s, s, 3), np.float32) + (150, 112, 60)
    col = col * (1 + bevel(outer, 3 * SS, 3.0) - bevel(hole, 2 * SS, 2.0))[..., None]
    compose(out, col, ring)
    edge = np.clip(dilate(hole, 1 * SS) - hole, 0, 1)
    compose(out, np.zeros((s, s, 3), np.float32) + (40, 26, 12), edge)
    save(out, "ring.tga", (64, 64))
    # Maske til ikonet (hvit sirkel)
    mk = np.zeros((s, s, 4), np.float32)
    mk[..., :3] = 255
    mk[..., 3] = hole * 255
    save(mk, "mask_circle.tga", (64, 64))


def render_symbols():
    s = 32 * SS
    for name, color, draw in (
        ("check.tga", (90, 200, 80), lambda d: d.line(S([(6, 17), (13, 24), (26, 8)]), fill=255, width=5 * SS, joint="curve")),
        ("cross.tga", (220, 70, 50), lambda d: [d.line(S([(8, 8), (24, 24)]), fill=255, width=5 * SS),
                                                d.line(S([(24, 8), (8, 24)]), fill=255, width=5 * SS)]),
    ):
        m = arr(mask_img(s, s, draw))
        out = np.zeros((s, s, 4), np.float32)
        compose(out, np.zeros((s, s, 3), np.float32) + (20, 20, 10), np.clip(dilate(m, 2 * SS) - m, 0, 1) * 0.8)
        compose(out, np.zeros((s, s, 3), np.float32) + color, m)
        save(out, name, (32, 32))
    # Boks til haken
    m = arr(mask_img(s, s, lambda d: d.rounded_rectangle([4 * SS, 4 * SS, 28 * SS, 28 * SS], radius=4 * SS, fill=255)))
    inner = arr(mask_img(s, s, lambda d: d.rounded_rectangle([7 * SS, 7 * SS, 25 * SS, 25 * SS], radius=2 * SS, fill=255)))
    out = np.zeros((s, s, 4), np.float32)
    compose(out, np.zeros((s, s, 3), np.float32) + (196, 160, 80), m)
    compose(out, np.zeros((s, s, 3), np.float32) + (30, 40, 30), inner)
    save(out, "box.tga", (32, 32))


def render_bar():
    w, h = 256 * SS, 32 * SS
    out = np.zeros((h, w, 4), np.float32)
    m = arr(mask_img(w, h, lambda d: d.rounded_rectangle([2 * SS, 2 * SS, w - 2 * SS, h - 2 * SS], radius=8 * SS, fill=255)))
    inner = arr(mask_img(w, h, lambda d: d.rounded_rectangle([6 * SS, 6 * SS, w - 6 * SS, h - 6 * SS], radius=5 * SS, fill=255)))
    ring = np.clip(m - inner, 0, 1)
    col = np.zeros((h, w, 3), np.float32) + (176, 140, 78)
    col = col * (1 + bevel(m, 2 * SS, 3.0))[..., None]
    compose(out, col, ring)
    save(out, "bar_frame.tga", (256, 32))

def render_panel():
    """Treplate med pergament til rapporten (9-deling: hjørner 48 px av 256), i fargene fra fiskerammen."""
    s = 256 * SS
    out = np.zeros((s, s, 4), np.float32)
    m = arr(mask_img(s, s, lambda d: d.rounded_rectangle([4 * SS, 4 * SS, s - 4 * SS, s - 4 * SS], radius=30 * SS, fill=255)))
    paper = arr(mask_img(s, s, lambda d: d.rounded_rectangle([26 * SS, 26 * SS, s - 26 * SS, s - 26 * SS], radius=14 * SS, fill=255)))
    col = wood(s, s, (92, 62, 40), 61)
    col = col * (1 + bevel(m, 6 * SS, 2.5))[..., None]
    compose(out, col, m)
    compose(out, np.zeros((s, s, 3), np.float32) + (30, 20, 14), np.clip(dilate(m, 2 * SS) - m, 0, 1))
    rim = np.clip(dilate(paper, 4 * SS) - paper, 0, 1)
    compose(out, np.zeros((s, s, 3), np.float32) + (70, 72, 74), rim)
    # Pergamentet er jevnt (9-delingen strekker midten); litt mørkere mot kanten
    pcol = np.zeros((s, s, 3), np.float32) + (228, 212, 182)
    edge = 1 - blur(paper, 12 * SS)
    pcol = pcol * (1 - 0.18 * np.clip(edge * paper, 0, 1))[..., None]
    compose(out, pcol, paper)
    return save(out, "panel.tga", (256, 256))


def font(names, size):
    for n in names:
        p = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def preview():
    L = LAYOUT
    x0c, x1c = L["crop"]
    frame = Image.open(os.path.join(OUT, "frame.tga")).convert("RGBA").crop((x0c, 0, x1c, 512))
    img = Image.new("RGBA", (frame.width + 80, 592), (0, 0, 0, 255))
    bg = np.zeros((592, frame.width + 80, 3), np.float32)
    yy = np.linspace(0, 1, 592)[:, None, None]
    bg += np.array([24, 34, 58]) * (1 - yy) + np.array([30, 60, 70]) * yy
    img = Image.fromarray(bg.astype(np.uint8)).convert("RGBA")
    ox, oy = 40, 40
    img.alpha_composite(frame, (ox, oy))
    d = ImageDraw.Draw(img)
    title = font(["georgiab.ttf", "timesbd.ttf"], 34)
    head = font(["georgiab.ttf", "timesbd.ttf"], 20)
    txt = font(["segoeui.ttf", "arial.ttf"], 15)
    small = font(["segoeui.ttf", "arial.ttf"], 13)
    bold = font(["segoeuib.ttf", "arialbd.ttf"], 15)

    def P(x, y):
        return ox + x - x0c, oy + y

    def ctext(x, y, t, f, fill):
        w = d.textlength(t, font=f)
        d.text((P(x, y)[0] - w / 2, P(x, y)[1]), t, font=f, fill=fill)

    ring = Image.open(os.path.join(OUT, "ring.tga")).convert("RGBA")
    check = Image.open(os.path.join(OUT, "check.tga")).resize((18, 18))
    box = Image.open(os.path.join(OUT, "box.tga")).resize((18, 18))
    barf = Image.open(os.path.join(OUT, "bar_frame.tga")).convert("RGBA")

    ctext(508, L["title"], "Skitt Fiske", title, HEAD)
    ctext(508, L["zone"], "Crystal Lake, Elwynn Forest", small, (120, 96, 70))
    d.line([P(382, L["divider"]), P(634, L["divider"])], fill=(150, 120, 80), width=1)
    bx, by, bw, bh = L["bar"]
    x, y = P(bx, by)
    d.rounded_rectangle([x + 4, y + 4, x + bw - 4, y + bh - 4], radius=6, fill=(60, 44, 30))
    d.rounded_rectangle([x + 4, y + 4, x + 4 + (bw - 8) * 0.5, y + bh - 4], radius=6, fill=(86, 140, 60))
    img.alpha_composite(barf.resize((bw, bh)), (int(x), int(y)))
    ctext(bx + bw / 2, by + 5, "Fiske 75/150  +25", txt, (255, 250, 235))
    for x0, t in ((L["pole"], "Stang"), (L["lure"], "Agn  6 min")):
        b = box.resize((21, 21))
        img.alpha_composite(b, tuple(int(v) for v in P(x0, L["line2"])))
        img.alpha_composite(check.resize((21, 21)), tuple(int(v) for v in P(x0, L["line2"])))
        d.text(P(x0 + 27, L["line2"] + 1), t, font=txt, fill=INK)
    rx, ry, rs, rstep = L["rings"]
    for i, colr in enumerate(((200, 120, 140), (110, 170, 200), (170, 120, 220))):
        x, y = P(rx + i * rstep, ry)
        d.ellipse([x + 5, y + 5, x + rs - 5, y + rs - 5], fill=colr)
        img.alpha_composite(ring.resize((rs, rs)), (int(x), int(y)))
        d.text((x + rs - 11, y + rs - 16), str((5, 3, 2)[i]), font=small, fill=(255, 255, 255))
    x0, y0, w, h = L["box"]
    a, b = P(x0, y0), P(x0 + w, y0 + h)
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rectangle([a, b], fill=(115, 82, 46, 20), outline=(140, 107, 69, 150))
    img.alpha_composite(ov)
    ctext(536, L["summary"], "Fanget 11  ·  Kast 14 · Slapp unna 1", small, (120, 96, 70))
    ctext(536, L["value"], "Verdi 1g 4s 20c  ·  3g 12s per time", bold, HEAD)
    for i, (t, v) in enumerate((("6 × Oily Blackmouth", "54s"), ("3 × Raw Longjaw Mud Snapper", "6c"), ("+ 2 til", "4c"))):
        y = L["rows"] + i * L["row_step"]
        if i < 2:
            d.rectangle([P(x0 + 10, y), (P(x0 + 10, y)[0] + 16, P(x0 + 10, y)[1] + 16)], fill=(120, 140, 160))
        d.text(P(x0 + 32, y + 1), t, font=small, fill=INK if i < 2 else (120, 96, 70))
        vw = d.textlength(v, font=small)
        d.text((P(x0 + w - 10, y)[0] - vw, P(x0, y + 1)[1]), v, font=small, fill=HEAD)
    x, y, w, h = L["report"]
    b = Image.open(os.path.join(OUT, "lbl_rapport.tga")).convert("RGBA").resize((w, h))
    img.alpha_composite(b, tuple(int(v) for v in P(x, y)))
    cx, cy, cw, ch = L["close"]
    b = Image.open(os.path.join(OUT, "btn_close.tga")).convert("RGBA").resize((cw, ch))
    img.alpha_composite(b, tuple(int(v) for v in P(cx, cy)))
    path = os.path.join(ROOT, "docs", "vindu-forhandsvisning.png")
    img.convert("RGB").save(path)
    return path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    render_ring()
    render_symbols()
    render_bar()
    render_panel()
    for old in ("plaque.tga", "button.tga"):
        if os.path.exists(os.path.join(OUT, old)):
            os.remove(os.path.join(OUT, old))
    print("Media:", sorted(os.listdir(OUT)))
    print("Forhåndsvisning:", preview())
