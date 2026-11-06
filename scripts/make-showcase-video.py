"""Builds a smooth 60fps App-Store-preview style video from walkthrough screenshots.

Usage: showcase.py SHOTS_DIR WORDMARK.png ICON.png BRAND_FONT.ttf OUT.mp4
Screenshots are named NN-<transition>-<name>.png (see DemoWalkthroughTests.swift).
"""
import os, re, subprocess, sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

shots_dir, wordmark_path, icon_path, font_path, out = sys.argv[1:6]
W, H, FPS = 1080, 1920, 60
PINK = (255, 215, 231)
LAVENDER = (232, 222, 255)
ACCENT = (216, 34, 96)
INK = (58, 30, 43)

CAPTIONS = [
    ("discover", "Clare’s latest reviews,\nright on your phone"),
    ("restaurant", "Every review,\nbeautifully laid out"),
    ("map", "Explore London’s\nvegan map"),
    ("list", "Search hundreds\nof restaurants"),
    ("search", "Search hundreds\nof restaurants"),
    ("filters", "Filter for exactly\nwhat you fancy"),
    ("guides", "Clare’s curated\nLondon guides"),
    ("guide", "Clare’s curated\nLondon guides"),
    ("travel", "Vegan travel guides\nfrom around the world"),
    ("perks", "Exclusive perks\nfor Premium members"),
    ("perk", "Exclusive perks\nfor Premium members"),
    ("saved", "Save it.\nSort it."),
    ("end", "The ultimate vegan\nguide to London"),
]

def caption_for(name):
    for key, text in CAPTIONS:
        if name == key or name.startswith(key + "-"):
            return text
    return ""

# ---------- load shots ----------
shots = []
for f in sorted(os.listdir(shots_dir)):
    m = re.match(r"(\d+)-(fade|push|scroll|sheet)-(.+)\.png$", f)
    if m:
        shots.append({"file": os.path.join(shots_dir, f), "transition": m.group(2), "name": m.group(3)})
if not shots:
    sys.exit("no screenshots found")

# ---------- geometry ----------
first = Image.open(shots[0]["file"])
sw, sh = first.size
PHONE_H = 1400
scale = PHONE_H / sh
PW, PH = round(sw * scale), PHONE_H
BEZEL = 16
PX = (W - PW) // 2
PY = H - PH - 120
RADIUS = round(PW * 0.135)

def load_screen(path):
    im = Image.open(path).convert("RGB")
    return im.resize((PW, PH), Image.LANCZOS)

for s in shots:
    s["img"] = load_screen(s["file"])
    s["caption"] = caption_for(s["name"])

screen_mask = Image.new("L", (PW, PH), 0)
ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, PW - 1, PH - 1), RADIUS, fill=255)

# ---------- static background with phone body + shadow ----------
def gradient():
    top, bottom = PINK, LAVENDER
    g = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        g.putpixel((0, y), tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return g.resize((W, H))

base = gradient()
shadow = Image.new("L", (W, H), 0)
ImageDraw.Draw(shadow).rounded_rectangle((PX - BEZEL, PY - BEZEL + 24, PX + PW + BEZEL, PY + PH + BEZEL + 24), RADIUS + BEZEL, fill=110)
shadow = shadow.filter(ImageFilter.GaussianBlur(36))
base.paste((120, 60, 90), (0, 0), shadow)
body = ImageDraw.Draw(base)
body.rounded_rectangle((PX - BEZEL, PY - BEZEL, PX + PW + BEZEL, PY + PH + BEZEL), RADIUS + BEZEL, fill=(24, 24, 28))
body.rounded_rectangle((PX - BEZEL + 3, PY - BEZEL + 3, PX + PW + BEZEL - 3, PY + PH + BEZEL - 3), RADIUS + BEZEL - 3, outline=(70, 70, 78), width=2)

caption_font = ImageFont.truetype(font_path, 74)
wordmark = Image.open(wordmark_path).convert("RGBA")
small_mark = wordmark.copy(); small_mark.thumbnail((300, 120), Image.LANCZOS)

def caption_layer(text):
    layer = Image.new("RGBA", (W, PY - BEZEL), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    layer.alpha_composite(small_mark, ((W - small_mark.width) // 2, 70))
    if text:
        d.multiline_text((W // 2, 200 + (PY - BEZEL - 200) // 2), text, font=caption_font, fill=INK,
                         anchor="mm", align="center", spacing=10)
    return layer

caption_cache = {}
def caption(text):
    if text not in caption_cache:
        caption_cache[text] = caption_layer(text)
    return caption_cache[text]

# ---------- intro / outro cards ----------
icon = Image.open(icon_path).convert("RGBA").resize((260, 260), Image.LANCZOS)
icon_mask = Image.new("L", icon.size, 0)
ImageDraw.Draw(icon_mask).rounded_rectangle((0, 0, 259, 259), 58, fill=255)
icon.putalpha(icon_mask)
big_mark = wordmark.copy(); big_mark.thumbnail((900, 400), Image.LANCZOS)
tag_font = ImageFont.truetype(font_path, 52)

def title_card(subtitle):
    card = gradient().convert("RGBA")
    card.alpha_composite(icon, ((W - 260) // 2, 520))
    card.alpha_composite(big_mark, ((W - big_mark.width) // 2, 860))
    ImageDraw.Draw(card).text((W // 2, 860 + big_mark.height + 90), subtitle, font=tag_font, fill=ACCENT, anchor="mm")
    return card.convert("RGB")

intro = title_card("Coming soon to iPhone")
outro = title_card("The ultimate vegan guide to London")

# ---------- frame rendering ----------
def ease(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))

TOP_BAND = 0.115   # status + nav bar stays put while content scrolls
BOTTOM_BAND = 0.905

def transition_screen(a, b, kind, t):
    e = ease(t)
    if kind == "fade":
        return Image.blend(a, b, e)
    if kind == "push":
        canvas = a.copy()
        dim = Image.blend(a, Image.new("RGB", a.size, (0, 0, 0)), 0.18 * e)
        canvas.paste(dim, (round(-0.3 * PW * e), 0))
        canvas.paste(b, (round(PW * (1 - e)), 0))
        return canvas
    if kind == "sheet":
        canvas = Image.blend(a, Image.new("RGB", a.size, (0, 0, 0)), 0.25 * e)
        canvas.paste(b, (0, round(PH * (1 - e))))
        return canvas
    if kind == "scroll":
        y0, y1 = round(PH * TOP_BAND), round(PH * BOTTOM_BAND)
        h = y1 - y0
        canvas = (a if e < 0.5 else b).copy()  # bars switch at the midpoint
        ca, cb = a.crop((0, y0, PW, y1)), b.crop((0, y0, PW, y1))
        # Content slides up like a scroll; old content leaves, new arrives from below.
        off = round(h * e)
        strip = Image.new("RGB", (PW, h), (255, 255, 255))
        strip.paste(ca, (0, -off))
        strip.paste(cb, (0, h - off))
        canvas.paste(strip, (0, y0))
        return canvas
    return b

def compose(screen, cap_a, cap_b=None, cap_t=0.0):
    frame = base.copy()
    frame.paste(screen, (PX, PY), screen_mask)
    frame = frame.convert("RGBA")
    if cap_b is None or cap_a is cap_b:
        frame.alpha_composite(cap_a)
    else:
        e = ease(cap_t)
        la, lb = cap_a.copy(), cap_b.copy()
        la.putalpha(la.getchannel("A").point(lambda v: round(v * (1 - e))))
        lb.putalpha(lb.getchannel("A").point(lambda v: round(v * e)))
        frame.alpha_composite(la); frame.alpha_composite(lb)
    return frame.convert("RGB")

ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
                       "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                       "-movflags", "+faststart", out], stdin=subprocess.PIPE)
count = 0
def emit(img, frames=1):
    global count
    data = img.tobytes()
    for _ in range(frames):
        ff.stdin.write(data); count += 1

HOLD = {"fade": 2.1, "push": 2.2, "scroll": 1.7, "sheet": 2.0}
TRANS = {"fade": 0.4, "push": 0.45, "scroll": 0.55, "sheet": 0.45}

# intro, then fade into the first screen
emit(intro, round(1.8 * FPS))
first_frame = compose(shots[0]["img"], caption(shots[0]["caption"]))
for i in range(round(0.5 * FPS)):
    emit(Image.blend(intro, first_frame, ease(i / (0.5 * FPS))))
emit(first_frame, round(2.4 * FPS))

for prev, cur in zip(shots, shots[1:]):
    kind = cur["transition"]
    n = round(TRANS[kind] * FPS)
    ca, cb = caption(prev["caption"]), caption(cur["caption"])
    for i in range(1, n + 1):
        t = i / n
        emit(compose(transition_screen(prev["img"], cur["img"], kind, t), ca, cb, t))
    emit(compose(cur["img"], cb), round(HOLD[kind] * FPS))

last = compose(shots[-1]["img"], caption(shots[-1]["caption"]))
for i in range(round(0.6 * FPS)):
    emit(Image.blend(last, outro, ease(i / (0.6 * FPS))))
emit(outro, round(2.5 * FPS))
ff.stdin.close(); ff.wait()
print(f"{len(shots)} screens, {count / FPS:.1f}s at {FPS}fps -> {out}")
