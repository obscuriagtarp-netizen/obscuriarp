from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'web' / 'assets'
OUTPUT.mkdir(parents=True, exist_ok=True)

RUNES = {
    'rune-f-blink.png': ('62cfe1', [(22, 88), (22, 12), (78, 12), (22, 12), (22, 48), (67, 48)]),
    'rune-u-reparatio.png': ('d6aa62', [(22, 14), (22, 66), (28, 80), (40, 88), (60, 88), (72, 80), (78, 66), (78, 14)]),
    'rune-r-vitae.png': ('72c983', [(23, 90), (23, 12), (61, 12), (76, 24), (71, 39), (60, 48), (23, 48), (68, 90)]),
    'rune-u-petrificus.png': ('8ddcf2', [(18, 12), (18, 67), (32, 84), (50, 91), (68, 84), (82, 67), (82, 12)]),
    'rune-s-portus.png': ('a582db', [(78, 17), (65, 9), (35, 9), (20, 23), (30, 43), (66, 43), (80, 62), (67, 89), (29, 89), (17, 78)]),
    'rune-a-invulneris.png': ('d6c38a', [(14, 90), (50, 10), (86, 90), (69, 54), (31, 54)]),
    'rune-t-ignis.png': ('df735f', [(14, 13), (86, 13), (50, 13), (50, 90)]),
    'rune-o-fauna.png': ('9fbe75', [(50, 8), (70, 14), (84, 30), (90, 50), (84, 70), (70, 86), (50, 92), (30, 86), (16, 70), (10, 50), (16, 30), (30, 14), (50, 8)]),
}


def rgba(hex_color, alpha=255):
    value = hex_color.lstrip('#')
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def scale_points(points, size=512, margin=104):
    span = size - (margin * 2)
    return [(margin + x / 100 * span, margin + y / 100 * span) for x, y in points]


def generate(filename, accent, rune_points):
    size = 512
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow = Image.new('RGBA', image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    draw = ImageDraw.Draw(image)
    center = size // 2

    diamond = [(center, 34), (478, center), (center, 478), (34, center)]
    inner = [(center, 53), (459, center), (center, 459), (53, center)]
    draw.polygon(diamond, fill=(3, 9, 11, 236), outline=(33, 29, 24, 255), width=12)
    draw.line(diamond + [diamond[0]], fill=(196, 176, 117, 235), width=4, joint='curve')
    draw.line(inner + [inner[0]], fill=(65, 107, 108, 180), width=3, joint='curve')

    for radius, alpha in ((166, 54), (139, 43), (102, 34)):
        box = (center - radius, center - radius, center + radius, center + radius)
        draw.ellipse(box, outline=rgba(accent, alpha), width=2)

    points = scale_points(rune_points)
    glow_draw.line(points, fill=rgba(accent, 215), width=24, joint='curve')
    glow = glow.filter(ImageFilter.GaussianBlur(16))
    image.alpha_composite(glow)
    draw = ImageDraw.Draw(image)
    draw.line(points, fill=(21, 17, 14, 255), width=19, joint='curve')
    draw.line(points, fill=(204, 187, 132, 255), width=10, joint='curve')
    draw.line(points, fill=rgba(accent, 255), width=4, joint='curve')
    draw.line(points, fill=(244, 234, 197, 225), width=1, joint='curve')

    for index, point in enumerate(points):
        x, y = point
        radius = 12 if index in (0, len(points) - 1) else 8
        draw.ellipse((x - radius - 5, y - radius - 5, x + radius + 5, y + radius + 5), fill=(3, 9, 11, 245), outline=(202, 183, 125, 230), width=3)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=rgba(accent, 245), width=3)

    image.save(OUTPUT / filename, 'PNG', optimize=True)


for output_name, (color, path) in RUNES.items():
    generate(output_name, color, path)

print(f'generated {len(RUNES)} rune assets in {OUTPUT}')
