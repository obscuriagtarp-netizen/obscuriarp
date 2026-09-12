from pathlib import Path

from PIL import Image, ImageDraw


SCALE = 4
SIZE = 128
CANVAS = SIZE * SCALE
INK = (236, 227, 239, 255)
ACCENT = (174, 111, 202, 255)
FILL = (91, 57, 104, 72)


def points(values):
    return [(int(x * SCALE), int(y * SCALE)) for x, y in values]


def box(values):
    return tuple(int(value * SCALE) for value in values)


def draw_icon(name, painter):
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    painter(draw)
    image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    output = Path(__file__).resolve().parents[1] / "public" / "wardrobe-icons"
    output.mkdir(parents=True, exist_ok=True)
    image.save(output / f"{name}.png")


def line(draw, values, fill=INK, width=6, joint="curve"):
    draw.line(points(values), fill=fill, width=width * SCALE, joint=joint)


def polygon(draw, values, fill=FILL, outline=INK, width=5):
    pts = points(values)
    draw.polygon(pts, fill=fill)
    draw.line(pts + [pts[0]], fill=outline, width=width * SCALE, joint="curve")


def head(draw):
    draw.ellipse(box((42, 19, 86, 63)), fill=FILL, outline=INK, width=5 * SCALE)
    line(draw, ((31, 106), (34, 86), (45, 72), (64, 65), (83, 72), (94, 86), (97, 106)))
    line(draw, ((45, 72), (51, 84), (64, 90), (77, 84), (83, 72)), ACCENT, 4)


def mask(draw):
    polygon(draw, ((21, 48), (39, 38), (64, 44), (89, 38), (107, 48), (99, 78), (77, 93), (64, 82), (51, 93), (29, 78)))
    draw.ellipse(box((39, 54, 58, 67)), outline=ACCENT, width=4 * SCALE)
    draw.ellipse(box((70, 54, 89, 67)), outline=ACCENT, width=4 * SCALE)


def jacket(draw):
    polygon(draw, ((35, 28), (50, 20), (64, 34), (78, 20), (93, 28), (105, 105), (74, 105), (64, 84), (54, 105), (23, 105)))
    line(draw, ((50, 20), (47, 56), (64, 77), (81, 56), (78, 20)), ACCENT, 4)
    line(draw, ((64, 77), (64, 105)), INK, 4)
    draw.ellipse(box((68, 82, 74, 88)), fill=ACCENT)


def shirt(draw):
    polygon(draw, ((44, 24), (55, 19), (64, 31), (73, 19), (84, 24), (105, 39), (92, 59), (82, 52), (82, 106), (46, 106), (46, 52), (36, 59), (23, 39)))
    draw.arc(box((52, 17, 76, 42)), 15, 165, fill=ACCENT, width=4 * SCALE)


def arms(draw):
    polygon(draw, ((29, 28), (46, 28), (56, 69), (73, 91), (58, 105), (39, 78)))
    polygon(draw, ((99, 28), (82, 28), (72, 69), (55, 91), (70, 105), (89, 78)))
    line(draw, ((43, 69), (56, 62)), ACCENT, 4)
    line(draw, ((85, 69), (72, 62)), ACCENT, 4)


def vest(draw):
    polygon(draw, ((39, 23), (56, 19), (64, 42), (72, 19), (89, 23), (98, 104), (30, 104)))
    line(draw, ((39, 23), (49, 59), (64, 73), (79, 59), (89, 23)), ACCENT, 4)
    line(draw, ((64, 73), (64, 104)), INK, 4)


def necklace(draw):
    draw.arc(box((25, 18, 103, 94)), 15, 165, fill=INK, width=6 * SCALE)
    draw.arc(box((34, 28, 94, 84)), 18, 162, fill=ACCENT, width=3 * SCALE)
    polygon(draw, ((64, 74), (76, 90), (64, 107), (52, 90)), fill=(91, 57, 104, 120), outline=ACCENT, width=4)


def bag(draw):
    draw.rounded_rectangle(box((26, 35, 102, 106)), radius=11 * SCALE, fill=FILL, outline=INK, width=5 * SCALE)
    draw.arc(box((43, 15, 85, 57)), 180, 360, fill=INK, width=5 * SCALE)
    line(draw, ((27, 56), (101, 56)), ACCENT, 4)
    draw.rounded_rectangle(box((53, 50, 75, 68)), radius=4 * SCALE, outline=ACCENT, width=4 * SCALE)


def pants(draw):
    polygon(draw, ((39, 20), (89, 20), (84, 105), (63, 105), (60, 61), (55, 105), (34, 105)))
    line(draw, ((39, 36), (89, 36)), ACCENT, 4)
    line(draw, ((64, 21), (60, 61)), INK, 4)


def shoes(draw):
    polygon(draw, ((22, 66), (52, 59), (68, 82), (91, 88), (104, 101), (98, 108), (25, 108)))
    line(draw, ((27, 91), (65, 91)), ACCENT, 4)
    line(draw, ((47, 65), (58, 82)), INK, 4)


def decals(draw):
    polygon(draw, ((64, 18), (75, 47), (106, 48), (81, 67), (90, 98), (64, 80), (38, 98), (47, 67), (22, 48), (53, 47)))
    draw.ellipse(box((54, 54, 74, 74)), outline=ACCENT, width=4 * SCALE)


def hat(draw):
    draw.rounded_rectangle(box((39, 29, 89, 72)), radius=13 * SCALE, fill=FILL, outline=INK, width=5 * SCALE)
    line(draw, ((28, 67), (100, 67)), ACCENT, 5)
    draw.ellipse(box((17, 61, 111, 88)), outline=INK, width=5 * SCALE)
    line(draw, ((43, 51), (85, 51)), ACCENT, 4)


def glasses(draw):
    draw.rounded_rectangle(box((17, 43, 55, 79)), radius=12 * SCALE, fill=FILL, outline=INK, width=5 * SCALE)
    draw.rounded_rectangle(box((73, 43, 111, 79)), radius=12 * SCALE, fill=FILL, outline=INK, width=5 * SCALE)
    draw.arc(box((53, 50, 75, 71)), 195, 345, fill=ACCENT, width=4 * SCALE)
    line(draw, ((17, 48), (7, 43)), INK, 4)
    line(draw, ((111, 48), (121, 43)), INK, 4)


def earrings(draw):
    draw.ellipse(box((31, 23, 49, 41)), outline=INK, width=5 * SCALE)
    draw.ellipse(box((79, 23, 97, 41)), outline=INK, width=5 * SCALE)
    line(draw, ((40, 41), (40, 67)), ACCENT, 4)
    line(draw, ((88, 41), (88, 67)), ACCENT, 4)
    polygon(draw, ((40, 64), (52, 84), (40, 105), (28, 84)), outline=INK, width=4)
    polygon(draw, ((88, 64), (100, 84), (88, 105), (76, 84)), outline=INK, width=4)


def watch(draw):
    polygon(draw, ((53, 13), (75, 13), (79, 40), (49, 40)), outline=INK, width=4)
    polygon(draw, ((49, 88), (79, 88), (75, 115), (53, 115)), outline=INK, width=4)
    draw.rounded_rectangle(box((38, 35, 90, 93)), radius=12 * SCALE, fill=FILL, outline=INK, width=5 * SCALE)
    draw.ellipse(box((49, 46, 79, 82)), outline=ACCENT, width=4 * SCALE)
    line(draw, ((64, 64), (64, 51)), INK, 3)
    line(draw, ((64, 64), (73, 70)), INK, 3)


def bracelet(draw):
    draw.ellipse(box((24, 25, 104, 105)), fill=FILL, outline=INK, width=6 * SCALE)
    draw.ellipse(box((43, 44, 85, 86)), fill=(0, 0, 0, 0), outline=ACCENT, width=5 * SCALE)
    draw.arc(box((31, 32, 97, 98)), 205, 335, fill=INK, width=8 * SCALE)


def tattoo_head(draw):
    draw.ellipse(box((40, 17, 88, 65)), fill=FILL, outline=INK, width=5 * SCALE)
    line(draw, ((33, 108), (37, 85), (48, 72), (64, 67), (80, 72), (91, 85), (95, 108)))
    line(draw, ((50, 42), (58, 34), (64, 43), (70, 34), (78, 42), (64, 58), (50, 42)), ACCENT, 3)


def tattoo_torso(draw):
    polygon(draw, ((40, 20), (55, 16), (64, 31), (73, 16), (88, 20), (101, 45), (91, 106), (37, 106), (27, 45)))
    line(draw, ((64, 36), (52, 57), (64, 75), (76, 57), (64, 36)), ACCENT, 4)
    line(draw, ((47, 88), (81, 88)), ACCENT, 3)


def tattoo_left_arm(draw):
    polygon(draw, ((46, 17), (69, 22), (73, 51), (63, 83), (49, 112), (29, 102), (43, 73), (49, 47)))
    line(draw, ((55, 34), (45, 55), (59, 68), (43, 90)), ACCENT, 4)


def tattoo_right_arm(draw):
    polygon(draw, ((82, 17), (59, 22), (55, 51), (65, 83), (79, 112), (99, 102), (85, 73), (79, 47)))
    line(draw, ((73, 34), (83, 55), (69, 68), (85, 90)), ACCENT, 4)


def tattoo_left_leg(draw):
    polygon(draw, ((45, 16), (70, 16), (67, 56), (58, 82), (57, 112), (31, 112), (37, 78)))
    line(draw, ((54, 31), (44, 53), (56, 67), (43, 91)), ACCENT, 4)


def tattoo_right_leg(draw):
    polygon(draw, ((83, 16), (58, 16), (61, 56), (70, 82), (71, 112), (97, 112), (91, 78)))
    line(draw, ((74, 31), (84, 53), (72, 67), (85, 91)), ACCENT, 4)


ICONS = {
    "head": head,
    "mask": mask,
    "jacket": jacket,
    "shirt": shirt,
    "arms": arms,
    "vest": vest,
    "necklace": necklace,
    "bag": bag,
    "pants": pants,
    "shoes": shoes,
    "decals": decals,
    "hat": hat,
    "glasses": glasses,
    "earrings": earrings,
    "watch": watch,
    "bracelet": bracelet,
    "tattoo-head": tattoo_head,
    "tattoo-torso": tattoo_torso,
    "tattoo-left-arm": tattoo_left_arm,
    "tattoo-right-arm": tattoo_right_arm,
    "tattoo-left-leg": tattoo_left_leg,
    "tattoo-right-leg": tattoo_right_leg,
}


if __name__ == "__main__":
    for icon_name, icon_painter in ICONS.items():
        draw_icon(icon_name, icon_painter)
    print(f"generated={len(ICONS)}")
