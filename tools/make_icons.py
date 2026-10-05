from PIL import Image, ImageDraw, ImageFilter

SRC = "assets/icon/alhelal_icon_android12_frombrand.png"
OUT = "assets/icon/"
S = 1024

img = Image.open(SRC).convert("RGB")
w, h = img.size
m = min(w, h)
img = img.crop(((w-m)//2, (h-m)//2, (w+m)//2, (h+m)//2)).resize((S, S), Image.LANCZOS)

# 1) full icon (iOS + legacy)
img.save(OUT + "icon_full.png")

# background color from the top-right corner
bg_color = img.getpixel((S-20, 20))
print("Background color: #%02x%02x%02x" % bg_color)

# 2) background layer
bg = Image.new("RGB", (S, S), bg_color)
glow = Image.radial_gradient("L").resize((S, S))
light = Image.new("RGB", (S, S), (6, 40, 90))
bg = Image.composite(bg, light, glow)
bg.save(OUT + "icon_bg.png")
# 3) foreground layer
def make_fg(scale, path):
    size = int(S * scale)
    art = img.resize((size, size), Image.LANCZOS).convert("RGBA")
    px = art.load()
    bg = bg_color
    # أي بكسل قريب من لون الخلفية يصبح شفافًا، مع انتقال تدريجي
    for y in range(size):
        for x in range(size):
            r, g, b, _ = px[x, y]
            d = max(abs(r-bg[0]), abs(g-bg[1]), abs(b-bg[2]))
            a = 0 if d < 14 else min(255, int((d-14) * 255 / 40))
            px[x, y] = (r, g, b, a)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.paste(art, ((S-size)//2, (S-size)//2), art)
    canvas.save(path)

make_fg(0.80, OUT + "icon_fg.png")
make_fg(0.60, OUT + "splash_logo.png")
print("Done")