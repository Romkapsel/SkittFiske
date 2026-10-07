"""Tegner bildene til Skitt Fiske (Media/*.tga) og en forhåndsvisning av vinduet (docs/vindu-forhandsvisning.png).

    python tools/render_media.py

Stilen er Daniels forbilde 7. okt: en fisk av treverk med vann i midten, grønne skilt med gullkant, runde
agn-ringer og røde knapper. Alt tegnes i 2x størrelse og skaleres ned. Målene for vinduet (piksler i frame.tga)
står i GEOM og brukes likt i UI/Window.lua (ns.GEOM) – endrer du ett sted, endre begge.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media")
SS = 2
RNG = np.random.default_rng(7)

GEOM = {
    "W": 1024, "H": 512,
    "body": (200, 50, 860, 468, 140),
    "water": (262, 100, 808, 418, 96),
}

# Plasseringen av alt i vinduet, i piksler i frame.tga (samme tall som LAYOUT i UI/Window.lua)
LAYOUT = {
    "title": 104, "zone": 146, "left": 290, "right": 545, "col": 220,
    "plaque1": 172, "plaque2": 284, "checks": 212, "check_step": 24,
    "rings": 322, "ring_step": 62, "caught": 212, "bar": 236, "stats": 268,
    "rows": 322, "row_step": 19, "hint": 432, "buttons": 600, "button_y": 426, "close": (772, 74),
}


# ── hjelpere ────────────────────────────────────────────────────────────────

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

def render_frame():
    W, H = GEOM["W"] * SS, GEOM["H"] * SS
    out = np.zeros((H, W, 4), np.float32)
    bx1, by1, bx2, by2, br = GEOM["body"]
    wx1, wy1, wx2, wy2, wr = GEOM["water"]

    tail_pts = [(840, 188), (1012, 44), (962, 256), (1012, 468), (840, 324)]
    fin_top = [(410, 72), (450, 22), (520, 6), (610, 4), (690, 16), (760, 68)]
    fin_b1 = [(370, 452), (410, 504), (470, 508), (500, 456)]
    fin_b2 = [(640, 456), (680, 504), (745, 508), (748, 452)]

    def fin_layer(pts, seed):
        m = arr(mask_img(W, H, lambda d: d.polygon(S(pts), fill=255)))
        col = wood(W, H, (150, 104, 62), seed, 0.6, vertical=True)
        # Stråler fra roten av finnen
        cx = sum(p[0] for p in pts[:1] + pts[-1:]) / 2 * SS
        cy = sum(p[1] for p in pts[:1] + pts[-1:]) / 2 * SS
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        ang = np.arctan2(y - cy, x - cx)
        rays = (np.sin(ang * 26) * 0.5 + 0.5) ** 6
        col = col * (1 - 0.35 * rays[..., None])
        col = col * (1 + bevel(m, 6 * SS, 2.2))[..., None]
        edge = dilate(m, 3 * SS) - m
        compose(out, col, m)
        compose(out, np.zeros_like(col) + (40, 24, 12), np.clip(edge, 0, 1))

    for pts, seed in ((tail_pts, 11), (fin_top, 12), (fin_b1, 13), (fin_b2, 14)):
        fin_layer(pts, seed)

    # Kroppen (treramma)
    body = arr(mask_img(W, H, lambda d: rrect(d, GEOM["body"], br)))
    col = wood(W, H, (122, 84, 48), 21)
    shade = np.linspace(1.12, 0.82, H)[:, None]
    col = col * shade[..., None]
    col = col * (1 + bevel(body, 8 * SS, 2.5))[..., None]
    compose(out, col, body)
    edge = dilate(body, 3 * SS) - body
    compose(out, np.zeros_like(col) + (38, 22, 10), np.clip(edge, 0, 1))

    # Hodet: gråbrunt, værbitt
    def head_draw(d):
        d.ellipse([40 * SS, 84 * SS, 372 * SS, 428 * SS], fill=255)
        d.polygon(S([(26, 232), (90, 150), (160, 120), (160, 400), (60, 340), (24, 290)]), fill=255)
    head = arr(mask_img(W, H, head_draw))
    hcol = wood(W, H, (118, 108, 92), 31, 0.8, vertical=True, warp=1.2)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    # Skjell: buer i rader
    sc = (np.sin(x / (14 * SS)) * np.sin((y + np.sin(x / (14 * SS)) * 6 * SS) / (11 * SS))) * 0.5 + 0.5
    hcol = hcol * (0.92 + 0.12 * sc[..., None])
    hcol = hcol * np.linspace(1.15, 0.8, H)[:, None, None]
    hcol = hcol * (1 + bevel(head, 10 * SS, 3.0))[..., None]
    compose(out, hcol, head)
    hedge = dilate(head, 3 * SS) - head
    compose(out, np.zeros_like(hcol) + (32, 26, 20), np.clip(hedge, 0, 1))

    # Gjelle og munn
    g = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(g)
    gd.arc([200 * SS, 120 * SS, 330 * SS, 400 * SS], 110, 250, fill=255, width=7 * SS)
    gd.polygon(S([(24, 262), (120, 252), (150, 284), (128, 300), (36, 306)]), fill=255)
    gm = arr(g) * head
    compose(out, np.zeros((H, W, 3), np.float32) + (30, 14, 10), gm)
    teeth = arr(mask_img(W, H, lambda d: [d.polygon(S([(40 + i * 18, 262), (48 + i * 18, 262), (44 + i * 18, 274)]), fill=255) for i in range(5)]))
    compose(out, np.zeros((H, W, 3), np.float32) + (215, 205, 180), teeth)

    # Øyet
    ex, ey, er = 140, 196, 34
    eye = arr(mask_img(W, H, lambda d: d.ellipse([(ex - er) * SS, (ey - er) * SS, (ex + er) * SS, (ey + er) * SS], fill=255)))
    rim = dilate(eye, 6 * SS) - eye
    compose(out, np.zeros((H, W, 3), np.float32) + (60, 50, 40), np.clip(rim, 0, 1))
    d2 = (x - ex * SS) ** 2 + (y - (ey - 8) * SS) ** 2
    glow = np.exp(-d2 / (2 * (er * SS * 0.8) ** 2))
    ecol = np.stack([150 + 105 * glow, 70 + 120 * glow, 10 + 40 * glow], -1)
    compose(out, ecol, eye)
    pupil = arr(mask_img(W, H, lambda d: d.ellipse([(ex - 9) * SS, (ey - 14) * SS, (ex + 9) * SS, (ey + 14) * SS], fill=255)))
    compose(out, np.zeros((H, W, 3), np.float32) + (25, 12, 5), pupil)
    hl = arr(mask_img(W, H, lambda d: d.ellipse([(ex - 20) * SS, (ey - 22) * SS, (ex - 10) * SS, (ey - 12) * SS], fill=255)))
    compose(out, np.zeros((H, W, 3), np.float32) + (255, 245, 210), hl * 0.9)

    # Metallkant rundt vannet
    water = arr(mask_img(W, H, lambda d: rrect(d, GEOM["water"], wr)))
    ring = np.clip(dilate(water, 7 * SS) - water, 0, 1)
    mcol = np.zeros((H, W, 3), np.float32) + (176, 140, 78)
    mcol = mcol * (1 + bevel(dilate(water, 7 * SS), 3 * SS, -3.0))[..., None]
    compose(out, mcol, ring)
    dark = np.clip(dilate(water, 9 * SS) - dilate(water, 7 * SS), 0, 1)
    compose(out, np.zeros((H, W, 3), np.float32) + (40, 26, 12), dark)

    # Vannet
    cx, cy = (wx1 + wx2) / 2 * SS, (wy1 + wy2) / 2 * SS
    rx, ry = (wx2 - wx1) / 2 * SS, (wy2 - wy1) / 2 * SS
    dist = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    t = np.clip(dist, 0, 1.2) / 1.2
    wcol = np.stack([
        58 * (1 - t) + 18 * t,
        142 * (1 - t) + 66 * t,
        140 * (1 - t) + 80 * t,
    ], -1)
    n1 = smooth_noise(W, H, 40, 41) * 6
    n2 = smooth_noise(W, H, 50, 42) * 6
    c = np.abs(np.sin(x * 0.018 / SS + n1) + np.sin(y * 0.03 / SS + n2) + np.sin((x + y) * 0.012 / SS + n1 * 0.7))
    caust = np.clip(1 - c / 0.35, 0, 1) ** 2
    wcol = wcol + caust[..., None] * np.array([70, 90, 80]) * 0.55
    inner_shadow = 1 - blur(water, 14 * SS)
    wcol = wcol * (1 - 0.55 * np.clip(inner_shadow * water, 0, 1))[..., None]
    compose(out, wcol, water)

    # Nagler
    for (rx_, ry_) in ((330, 72), (530, 64), (700, 72), (836, 260)):
        rv = arr(mask_img(W, H, lambda d: d.ellipse([(rx_ - 7) * SS, (ry_ - 7) * SS, (rx_ + 7) * SS, (ry_ + 7) * SS], fill=255)))
        vcol = np.zeros((H, W, 3), np.float32) + (170, 165, 150)
        vcol = vcol * (1 + bevel(rv, 3 * SS, 4.0))[..., None]
        compose(out, vcol, rv)

    # Kroken nede til høyre
    hk = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hk)
    hd.line(S([(890, 330), (890, 420)]), fill=255, width=7 * SS)
    hd.arc([852 * SS, 392 * SS, 918 * SS, 470 * SS], 0, 180, fill=255, width=7 * SS)
    hd.polygon(S([(848, 430), (862, 420), (858, 446)]), fill=255)
    hm = arr(hk)
    hcol2 = np.zeros((H, W, 3), np.float32) + (190, 190, 185)
    hcol2 = hcol2 * (1 + bevel(hm, 2 * SS, 3.0))[..., None]
    compose(out, np.zeros((H, W, 3), np.float32) + (30, 30, 30), np.clip(dilate(hm, 2 * SS) - hm, 0, 1))
    compose(out, hcol2, hm)

    # Myk skygge under alt
    alpha = out[..., 3] / 255.0
    sh = blur(alpha, 10 * SS) * 0.55
    dy, dx = 6 * SS, 4 * SS
    shifted = np.zeros_like(sh)
    shifted[dy:, dx:] = sh[:-dy, :-dx]  # flytt uten at kanten går rundt
    sh = shifted
    a_tot = alpha + sh * (1 - alpha)
    rgb = np.where(a_tot[..., None] > 0, out[..., :3] * alpha[..., None] / np.maximum(a_tot, 1e-4)[..., None], 0)
    final = np.dstack([rgb, a_tot * 255])
    return save(final, "frame.tga", (GEOM["W"], GEOM["H"]))


# ── små deler ───────────────────────────────────────────────────────────────

def render_plaque():
    w, h = 256 * SS, 48 * SS
    out = np.zeros((h, w, 4), np.float32)
    m = arr(mask_img(w, h, lambda d: d.rounded_rectangle([4 * SS, 4 * SS, w - 4 * SS, h - 4 * SS], radius=8 * SS, fill=255)))
    inner = arr(mask_img(w, h, lambda d: d.rounded_rectangle([9 * SS, 9 * SS, w - 9 * SS, h - 9 * SS], radius=5 * SS, fill=255)))
    gold = np.zeros((h, w, 3), np.float32) + (196, 160, 80)
    gold = gold * (1 + bevel(m, 3 * SS, 3.0))[..., None]
    compose(out, gold, m)
    green = np.zeros((h, w, 3), np.float32) + (46, 74, 40)
    green = green * np.linspace(1.25, 0.8, h)[:, None, None]
    green = green * (1 + bevel(inner, 4 * SS, -2.0))[..., None]
    compose(out, green, inner)
    return save(out, "plaque.tga", (256, 48), pad=(256, 64))


def render_button():
    w, h = 192 * SS, 48 * SS
    out = np.zeros((h, w, 4), np.float32)
    m = arr(mask_img(w, h, lambda d: d.rounded_rectangle([3 * SS, 3 * SS, w - 3 * SS, h - 3 * SS], radius=7 * SS, fill=255)))
    inner = arr(mask_img(w, h, lambda d: d.rounded_rectangle([7 * SS, 7 * SS, w - 7 * SS, h - 7 * SS], radius=5 * SS, fill=255)))
    compose(out, np.zeros((h, w, 3), np.float32) + (60, 30, 14), m)
    red = np.zeros((h, w, 3), np.float32) + (150, 34, 22)
    red = red * np.linspace(1.3, 0.7, h)[:, None, None]
    red = red * (1 + bevel(inner, 4 * SS, 2.5))[..., None]
    compose(out, red, inner)
    return save(out, "button.tga", (192, 48), pad=(256, 64))


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
    """Treplate med vann til rapporten (9-deling: hjørner 48 px av 256)."""
    s = 256 * SS
    out = np.zeros((s, s, 4), np.float32)
    m = arr(mask_img(s, s, lambda d: d.rounded_rectangle([4 * SS, 4 * SS, s - 4 * SS, s - 4 * SS], radius=36 * SS, fill=255)))
    water = arr(mask_img(s, s, lambda d: d.rounded_rectangle([30 * SS, 30 * SS, s - 30 * SS, s - 30 * SS], radius=18 * SS, fill=255)))
    col = wood(s, s, (122, 84, 48), 61)
    col = col * (1 + bevel(m, 6 * SS, 2.5))[..., None]
    compose(out, col, m)
    compose(out, np.zeros((s, s, 3), np.float32) + (38, 22, 10), np.clip(dilate(m, 2 * SS) - m, 0, 1))
    ring = np.clip(dilate(water, 5 * SS) - water, 0, 1)
    compose(out, np.zeros((s, s, 3), np.float32) + (176, 140, 78), ring)
    # Vannet i midten er jevnt, så 9-delingen kan strekke det
    wcol = np.zeros((s, s, 3), np.float32) + (32, 92, 100)
    inner_shadow = 1 - blur(water, 10 * SS)
    wcol = wcol * (1 - 0.5 * np.clip(inner_shadow * water, 0, 1))[..., None]
    compose(out, wcol, water)
    return save(out, "panel.tga", (256, 256))


# ── forhåndsvisning (Windows-fonter; i spillet brukes Morpheus og Friz) ─────

def font(names, size):
    for n in names:
        p = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", n)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def preview(frame):
    scale = 1.0
    img = Image.new("RGBA", (1100, 600), (40, 52, 70, 255))
    bg = np.zeros((600, 1100, 3), np.float32)
    yy = np.linspace(0, 1, 600)[:, None]
    bg += np.array([24, 34, 58]) * (1 - yy[..., None]) + np.array([30, 60, 70]) * yy[..., None]
    img = Image.fromarray(bg.astype(np.uint8)).convert("RGBA")
    ox, oy = 38, 44
    img.alpha_composite(frame, (ox, oy))
    d = ImageDraw.Draw(img)
    title = font(["georgiab.ttf", "timesbd.ttf"], 34)
    small = font(["segoeui.ttf", "arial.ttf"], 15)
    smallb = font(["segoeuib.ttf", "arialbd.ttf"], 16)

    def P(x, y):
        return ox + x * scale, oy + y * scale

    def ctext(x, y, t, f, fill):
        w = d.textlength(t, font=f)
        d.text((P(x, y)[0] - w / 2, P(x, y)[1]), t, font=f, fill=fill)

    plaque = Image.open(os.path.join(OUT, "plaque.tga")).crop((0, 0, 256, 48)).resize((220, 34))
    ring = Image.open(os.path.join(OUT, "ring.tga")).resize((56, 56))
    check = Image.open(os.path.join(OUT, "check.tga")).resize((22, 22))
    cross = Image.open(os.path.join(OUT, "cross.tga")).resize((22, 22))
    box = Image.open(os.path.join(OUT, "box.tga")).resize((22, 22))
    btn = Image.open(os.path.join(OUT, "button.tga")).crop((0, 0, 192, 48)).resize((110, 30))
    barf = Image.open(os.path.join(OUT, "bar_frame.tga")).resize((220, 26))

    L = LAYOUT
    ctext(535, L["title"], "Skitt Fiske", title, (236, 196, 92))
    ctext(535, L["zone"], "Crystal Lake, Elwynn Forest", small, (190, 215, 215))

    def plaq(x, y, t):
        img.alpha_composite(plaque, (int(P(x, y)[0]), int(P(x, y)[1])))
        ctext(x + 110, y + 7, t, smallb, (240, 216, 140))

    plaq(L["left"], L["plaque1"], "Klar")
    for i, (t, ok) in enumerate((("Stang", True), ("Agn  6 min", True), ("Lyd", True))):
        yv = L["checks"] + i * L["check_step"]
        img.alpha_composite(box, (int(P(L["left"] + 6, yv)[0]), int(P(L["left"] + 6, yv)[1])))
        img.alpha_composite(check if ok else cross, (int(P(L["left"] + 6, yv)[0]), int(P(L["left"] + 6, yv)[1])))
        d.text(P(L["left"] + 36, yv + 1), t, font=small, fill=(245, 240, 225))
    plaq(L["left"], L["plaque2"], "Agn")
    for i, colr in enumerate(((200, 120, 140), (120, 190, 210), (170, 120, 220))):
        x0, y0 = P(L["left"] + 10 + i * L["ring_step"], L["rings"])
        d.ellipse([x0 + 8, y0 + 8, x0 + 48, y0 + 48], fill=colr)
        img.alpha_composite(ring, (int(x0), int(y0)))
        d.text((x0 + 36, y0 + 34), str((5, 3, 2)[i]), font=smallb, fill=(255, 255, 255))

    R = L["right"]
    plaq(R, L["plaque1"], "Fiske")
    d.text(P(R + 11, L["caught"]), "Fanget", font=small, fill=(245, 240, 225))
    d.text(P(R + 195, L["caught"]), "13", font=smallb, fill=(236, 196, 92))
    bx, by = P(R, L["bar"])
    d.rounded_rectangle([bx + 4, by + 4, bx + 216, by + 22], radius=5, fill=(20, 30, 30))
    d.rounded_rectangle([bx + 4, by + 4, bx + 4 + 212 * 0.8, by + 22], radius=5, fill=(80, 160, 70))
    img.alpha_composite(barf, (int(bx), int(by)))
    ctext(R + 110, L["bar"] + 4, "Fiske 120/150  +25", small, (255, 255, 255))
    d.text(P(R + 11, L["stats"]), "Kast 20  ·  Slapp unna 1", font=small, fill=(200, 215, 210))
    plaq(R, L["plaque2"], "Fangst")
    for i, t in enumerate(("8 × Raw Brilliant Smallfish", "3 × Raw Longjaw Mud…", "2 × Oily Blackmouth", "1 × Sickly Looking Fish")):
        y0 = L["rows"] + i * L["row_step"]
        d.rectangle([P(R + 11, y0)[0], P(R + 11, y0)[1] + 2, P(R + 11, y0)[0] + 14, P(R + 11, y0)[1] + 16], fill=(120, 140, 160))
        d.text(P(R + 33, y0), t, font=small, fill=(245, 240, 225))

    d.text(P(L["left"] + 10, L["hint"]), "Dobbelt høyreklikk: kast", font=small, fill=(235, 215, 170))
    for i, t in enumerate(("Rapport", "Ferdig")):
        x0, y0 = P(L["buttons"] + i * 108, L["button_y"])
        img.alpha_composite(btn, (int(x0), int(y0)))
        ctext(L["buttons"] + i * 108 + 55, L["button_y"] + 5, t, smallb, (250, 220, 150))
    x0, y0 = P(*L["close"])
    d.rounded_rectangle([x0, y0, x0 + 24, y0 + 24], radius=4, fill=(150, 34, 22), outline=(200, 160, 80), width=2)
    ctext(L["close"][0] + 12, L["close"][1] + 2, "×", smallb, (255, 230, 200))
    path = os.path.join(ROOT, "docs", "vindu-forhandsvisning.png")
    img.convert("RGB").save(path)
    return path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    frame = render_frame()
    render_plaque()
    render_button()
    render_ring()
    render_symbols()
    render_bar()
    render_panel()
    print("Media:", sorted(os.listdir(OUT)))
    print("Forhåndsvisning:", preview(frame))
