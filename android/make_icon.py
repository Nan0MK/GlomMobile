# Builds the launcher icon from the game sprite. The phone mask crops the
# corners, so the creature is fitted inside the adaptive-icon canvas.
import os
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, "..", "..", "GlomRemastered", "resources", "glom.png"))
res = os.path.join(here, "res")
sprite = Image.open(src).convert("RGBA")
mask = sprite.getchannel("A").point(lambda a: 255 if a > 16 else 0)
sprite = sprite.crop(mask.getbbox())

# Dark field from the mobile pad, so the green creature stays readable.
BG = (12, 16, 14, 255)
# Share of the 108dp canvas the sprite may occupy. Leaves a margin for the mask.
FILL = 0.90

legacy = {
	"mipmap-mdpi": 48,
	"mipmap-hdpi": 72,
	"mipmap-xhdpi": 96,
	"mipmap-xxhdpi": 144,
	"mipmap-xxxhdpi": 192,
}
foreground = {
	"mipmap-mdpi": 108,
	"mipmap-hdpi": 162,
	"mipmap-xhdpi": 216,
	"mipmap-xxhdpi": 324,
	"mipmap-xxxhdpi": 432,
}

def place(canvas):
	side = max(1, int(canvas * FILL))
	scale = min(side / sprite.width, side / sprite.height)
	size = (max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale)))
	fitted = sprite.resize(size, Image.Resampling.LANCZOS)
	out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
	out.paste(fitted, ((canvas - size[0]) // 2, (canvas - size[1]) // 2), fitted)
	return out

def save(path, image):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	image.save(path, "PNG")

for folder, px in foreground.items():
	save(os.path.join(res, folder, "ic_launcher_foreground.png"), place(px))

for folder, px in legacy.items():
	flat = Image.new("RGBA", (px, px), BG)
	flat.alpha_composite(place(px))
	save(os.path.join(res, folder, "ic_launcher.png"), flat.convert("RGB"))
	save(os.path.join(res, folder, "ic_launcher_round.png"), flat)
