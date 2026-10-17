"""يولّد أيقونات PWA وfavicon من شعار التطبيق ليحلّ محل شعار Flutter الافتراضي.
التشغيل من جذر مشروع Flutter:  python tools/make_web_icons.py
"""
from pathlib import Path
from PIL import Image

BG = (0, 12, 42)  # #000c2a  (نفس خلفية الأيقونة وشاشة البدء)
ICON_DIR = Path("assets/icon")
OUT_ICONS = Path("web/icons")
FAVICON = Path("web/favicon.png")


def load(name):
    p = ICON_DIR / name
    if not p.exists():
        raise SystemExit(f"الملف غير موجود: {p}  (شغّل الأمر من جذر المشروع)")
    return Image.open(p).convert("RGBA")


def flatten(img, size):
    """يضع الصورة على خلفية صلبة بلا شفافية ويغيّر حجمها."""
    img = img.resize((size, size), Image.LANCZOS)
    bg = Image.new("RGBA", (size, size), BG + (255,))
    bg.alpha_composite(img)
    return bg.convert("RGB")


def compose(logo, size, fraction):
    """الشعار (شفاف) في منتصف خلفية صلبة، ويشغل fraction من العرض."""
    bbox = logo.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox()
    crop = logo.crop(bbox) if bbox else logo
    target = int(size * fraction)
    scale = target / max(crop.size)
    crop = crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), BG + (255,))
    canvas.alpha_composite(crop, ((size - crop.width) // 2, (size - crop.height) // 2))
    return canvas.convert("RGB")


def main():
    full = load("icon_full.png")
    fg = load("icon_fg.png")
    OUT_ICONS.mkdir(parents=True, exist_ok=True)

    for s in (192, 512):
        flatten(full, s).save(OUT_ICONS / f"Icon-{s}.png", optimize=True)
        # maskable: الشعار داخل المنطقة الآمنة (حوالي 60%) كي لا يُقصّ
        compose(fg, s, 0.58).save(OUT_ICONS / f"Icon-maskable-{s}.png", optimize=True)

    flatten(full, 96).save(FAVICON, optimize=True)  # مضاعف 48 كما تطلب Google
    print("تم: web/icons/* و web/favicon.png")


if __name__ == "__main__":
    main()