## THE MOON'S FACE, BAKED: NASA's LROC colour map turned into the near-side disc the sky wears
## (world/textures/moon_near_side.png, read by world/shaders/sky_night.gdshaderinc).
##
##   curl -L -o lroc_color_2k.jpg https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_2k.jpg
##   python cockpit/tools/bake_moon_face.py lroc_color_2k.jpg cockpit/world/textures/moon_near_side.png 512
##
## SOURCE: NASA Scientific Visualization Studio, CGI Moon Kit (https://svs.gsfc.nasa.gov/4720), `lroc_color_2k.jpg`, 2048 x
## 1024, credited "NASA's Scientific Visualization Studio". Public domain (https://svs.gsfc.nasa.gov/help/: "All of our
## content is in the public domain (unless otherwise noted)"; the kit notes nothing otherwise). Not committed: 2k of JPEG is
## the curl above.
##
## THE PROJECTION: equirectangular in, longitude 0 at the map's middle and east to the right, latitude 90 N at the top.
## ORTHOGRAPHIC out, as seen from Earth: the disc fills the square, lunar NORTH UP and lunar EAST TO THE RIGHT -- Mare Crisium
## on the right limb, Copernicus left of the middle, Tycho low in the middle -- which is the moon as a northern observer sees
## it with the moon high in the south. A point (x, y) on the disc, each -1 to 1, is the sphere point with z = sqrt(1 - x^2 -
## y^2) towards the eye, latitude asin(y) and longitude atan2(x, z). Libration is ignored.
##
## EACH PIXEL is 3 x 3 samples of the map, each bilinear. PAST THE LIMB a sample is pulled back onto it, so the corners hold
## the limb's colour smeared outwards rather than black, and the mips the engine builds never average black into the edge;
## the shader draws the disc's edge itself.
##
## Needs Pillow only. A 512 bake takes about 5 s.
import math
import sys

from PIL import Image


def bake(source_path: str, out_path: str, size: int, samples: int = 3) -> None:
	source = Image.open(source_path).convert("RGB")
	width, height = source.size
	pixels = source.load()

	def bilinear(u: float, v: float) -> list:
		u = u % width
		v = min(max(v, 0.0), height - 1.001)
		x0, y0 = int(u), int(v)
		fx, fy = u - x0, v - y0
		x1, y1 = (x0 + 1) % width, y0 + 1
		c00, c10, c01, c11 = pixels[x0, y0], pixels[x1, y0], pixels[x0, y1], pixels[x1, y1]
		return [(c00[i] * (1 - fx) + c10[i] * fx) * (1 - fy) + (c01[i] * (1 - fx) + c11[i] * fx) * fy for i in range(3)]

	out = Image.new("RGB", (size, size))
	written = out.load()
	for j in range(size):
		for i in range(size):
			total = [0.0, 0.0, 0.0]
			for sj in range(samples):
				for si in range(samples):
					x = (i + (si + 0.5) / samples) / (size / 2) - 1.0
					y = 1.0 - (j + (sj + 0.5) / samples) / (size / 2)
					r2 = x * x + y * y
					if r2 > 1.0:
						r = math.sqrt(r2)
						x, y, r2 = x / r, y / r, 1.0
					z = math.sqrt(max(0.0, 1.0 - r2))
					latitude = math.asin(max(-1.0, min(1.0, y)))
					longitude = math.atan2(x, z)
					colour = bilinear((longitude / (2 * math.pi) + 0.5) * width - 0.5, (0.5 - latitude / math.pi) * height - 0.5)
					for k in range(3):
						total[k] += colour[k]
			written[i, j] = tuple(int(round(t / (samples * samples))) for t in total)
	out.save(out_path, optimize=True)


if __name__ == "__main__":
	bake(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 512)
