class_name TextureFactory
extends RefCounted
## Génère toutes les textures du jeu par code (aucun fichier image externe).
## Les images sont petites (64 à 256 px) et mises en cache dans user:// par Assets.

const NAMES: Array[String] = [
	"parquet", "planks", "marble", "tiles_check", "tiles_small", "flagstone", "stone_wall",
	"wallpaper", "plaster", "wood", "wood_panel", "fabric", "carpet", "rug", "metal", "brick",
	"paper", "cobweb", "portrait_a", "portrait_b", "portrait_c", "portrait_scare", "window_night",
	"skin", "ground", "bark", "books", "stained_glass", "secret_wall", "flame", "glow", "drawing",
	"window_pane", "marble_plain", "paper_blank",
]


static func generate(tex_name: String) -> Image:
	match tex_name:
		"parquet":
			return _parquet()
		"planks":
			return _planks()
		"marble":
			return _marble()
		"tiles_check":
			return _tiles_check()
		"tiles_small":
			return _tiles_small()
		"flagstone":
			return _flagstone()
		"stone_wall":
			return _stone_wall()
		"wallpaper":
			return _wallpaper()
		"plaster":
			return _plaster()
		"wood":
			return _wood()
		"wood_panel":
			return _wood_panel()
		"fabric":
			return _fabric()
		"carpet":
			return _carpet()
		"rug":
			return _rug()
		"metal":
			return _metal()
		"brick":
			return _brick()
		"paper":
			return _paper()
		"cobweb":
			return _cobweb()
		"portrait_a":
			return _portrait(1, false)
		"portrait_b":
			return _portrait(2, false)
		"portrait_c":
			return _portrait(3, false)
		"portrait_scare":
			return _portrait(1, true)
		"window_night":
			return _window_night()
		"skin":
			return _skin()
		"ground":
			return _ground()
		"bark":
			return _bark()
		"books":
			return _books()
		"stained_glass":
			return _stained_glass()
		"secret_wall":
			return _secret_wall()
		"flame":
			return _flame()
		"glow":
			return _glow()
		"drawing":
			return _drawing()
		"window_pane":
			return _window_pane()
		"marble_plain":
			return _marble_plain()
		"paper_blank":
			return _paper_blank()
	return _solid(Color(1, 0, 1))


static func has_alpha(tex_name: String) -> bool:
	return tex_name in ["cobweb", "flame", "glow", "window_pane"]


# ============================================================ outils

static func _noise(seed_v: int, freq: float, octaves: int = 3, ntype: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = ntype
	n.frequency = freq
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


## Bruit raccordable (tuilable) sous forme de flottants 0..1.
static func _nbuf(seed_v: int, freq: float, octaves: int, w: int, h: int) -> PackedFloat32Array:
	var n := _noise(seed_v, freq, octaves)
	var img := n.get_seamless_image(w, h, false, false, 0.1, true)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	var bytes := img.get_data()
	var out := PackedFloat32Array()
	out.resize(w * h)
	for i: int in range(w * h):
		out[i] = float(bytes[i]) / 255.0
	return out


static func _hash(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func _rgb(w: int, h: int, px: PackedFloat32Array) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(w * h * 3)
	for i: int in range(w * h * 3):
		bytes[i] = clampi(int(px[i] * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)


static func _rgba(w: int, h: int, px: PackedFloat32Array) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i: int in range(w * h * 4):
		bytes[i] = clampi(int(px[i] * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


static func _buf(w: int, h: int, channels: int) -> PackedFloat32Array:
	var px := PackedFloat32Array()
	px.resize(w * h * channels)
	return px


static func _put(px: PackedFloat32Array, i: int, c: Color) -> void:
	var j := i * 3
	px[j] = c.r
	px[j + 1] = c.g
	px[j + 2] = c.b


static func _solid(c: Color) -> Image:
	var px := _buf(8, 8, 3)
	for i: int in range(64):
		_put(px, i, c)
	return _rgb(8, 8, px)


## Voronoi toroïdal (raccordable) : renvoie l'id de cellule et la distance au bord.
static func _voronoi(size: int, grid: int, seed_v: int) -> Array:
	var cell := float(size) / float(grid)
	var pts := PackedVector2Array()
	for gy: int in range(grid):
		for gx: int in range(grid):
			var k := gy * grid + gx + seed_v * 97
			pts.append(Vector2((float(gx) + 0.15 + 0.7 * _hash(k * 2)) * cell, (float(gy) + 0.15 + 0.7 * _hash(k * 2 + 1)) * cell))
	var ids := PackedInt32Array()
	ids.resize(size * size)
	var edge := PackedFloat32Array()
	edge.resize(size * size)
	var fs := float(size)
	for y: int in range(size):
		var gy := int(float(y) / cell)
		for x: int in range(size):
			var gx := int(float(x) / cell)
			var best := 1e9
			var second := 1e9
			var best_id := 0
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					var cx := posmod(gx + ox, grid)
					var cy := posmod(gy + oy, grid)
					var p: Vector2 = pts[cy * grid + cx]
					var dx := absf(float(x) - p.x)
					var dy := absf(float(y) - p.y)
					dx = minf(dx, fs - dx)
					dy = minf(dy, fs - dy)
					var d := sqrt(dx * dx + dy * dy)
					if d < best:
						second = best
						best = d
						best_id = cy * grid + cx
					elif d < second:
						second = d
			ids[y * size + x] = best_id
			edge[y * size + x] = (second - best) * 0.5
	return [ids, edge]


# ============================================================ sols

static func _parquet() -> Image:
	var w := 256
	var grain := _nbuf(11, 0.05, 3, 256, 64)
	var dirt := _nbuf(12, 0.012, 3, 256, 256)
	var px := _buf(w, w, 3)
	var offs := PackedInt32Array()
	var tints := PackedFloat32Array()
	for c: int in range(8):
		offs.append(int(_hash(c + 100) * 127.0))
	for p: int in range(16):
		tints.append(0.78 + 0.34 * _hash(p + 300))
	var base := Color(0.40, 0.23, 0.12)
	for y: int in range(w):
		for x: int in range(w):
			var c := x >> 5
			var yy := (y + offs[c]) & 255
			var plank := yy >> 7
			var ly := yy & 127
			var pid := c * 2 + plank
			var gy := yy >> 2
			var fy := float(yy & 3) * 0.25
			var gx := (x * 3 + pid * 37) & 255
			var g := lerpf(grain[gy * 256 + gx], grain[((gy + 1) & 63) * 256 + gx], fy)
			var t := tints[pid]
			var k := t * (0.68 + 0.55 * g) * (0.72 + 0.4 * dirt[y * w + x])
			var lx := x & 31
			if lx == 0 or ly == 0:
				k *= 0.3
			elif lx == 1 or ly == 1:
				k *= 0.78
			var hue := 1.0 + (_hash(pid + 900) - 0.5) * 0.12
			_put(px, y * w + x, Color(base.r * k * hue, base.g * k, base.b * k / hue))
	return _rgb(w, w, px)


static func _planks() -> Image:
	var w := 256
	var grain := _nbuf(21, 0.06, 4, 256, 64)
	var dirt := _nbuf(22, 0.02, 3, 256, 256)
	var px := _buf(w, w, 3)
	var base := Color(0.40, 0.31, 0.22)
	for y: int in range(w):
		for x: int in range(w):
			var c := x >> 6
			var yy := (y + int(_hash(c + 40) * 255.0)) & 255
			var pid := c
			var gy := yy >> 2
			var gx := (x * 2 + pid * 53) & 255
			var g := grain[gy * 256 + gx]
			var rings := 0.5 + 0.5 * sin(g * 30.0)
			var k := (0.75 + 0.2 * _hash(pid + 7)) * (0.7 + 0.3 * rings) * (0.65 + 0.45 * dirt[y * w + x])
			# noeuds
			var kx := float(c * 64 + 20 + int(_hash(c + 70) * 24.0))
			var ky := float(int(_hash(c + 80) * 200.0) + 28)
			var dk := Vector2(float(x) - kx, (float(yy) - ky) * 0.6).length()
			if dk < 7.0:
				k *= 0.45 + 0.08 * dk
			var lx := x & 63
			if lx < 2:
				k *= 0.25
			_put(px, y * w + x, Color(base.r * k, base.g * k, base.b * k))
	return _rgb(w, w, px)


static func _marble() -> Image:
	var w := 256
	var n := _nbuf(31, 0.012, 5, w, w)
	var n2 := _nbuf(32, 0.05, 3, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var i := y * w + x
			var tile := ((x >> 7) + (y >> 7)) & 1
			var vein := pow(1.0 - absf(sin(n[i] * 26.0)), 12.0)
			var c: Color
			if tile == 0:
				var b := 0.80 - 0.07 * n2[i] - vein * 0.38
				c = Color(b, b * 0.98, b * 0.93)
			else:
				var b2 := 0.06 + 0.05 * n2[i] + vein * 0.25
				c = Color(b2, b2, b2 * 1.08)
			if (x & 127) < 2 or (y & 127) < 2:
				c = Color(0.22, 0.21, 0.2)
			_put(px, i, c)
	return _rgb(w, w, px)


static func _marble_plain() -> Image:
	var w := 256
	var n := _nbuf(33, 0.01, 5, w, w)
	var n2 := _nbuf(34, 0.05, 3, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var vein := pow(1.0 - absf(sin(n[i] * 22.0)), 14.0)
		var b := 0.84 - 0.06 * n2[i] - vein * 0.32
		_put(px, i, Color(b, b * 0.98, b * 0.94))
	return _rgb(w, w, px)


static func _tiles_check() -> Image:
	var w := 256
	var dirt := _nbuf(41, 0.02, 4, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var i := y * w + x
			var tx := x >> 5
			var ty := y >> 5
			var j := 0.9 + 0.12 * _hash(tx * 17 + ty * 131)
			var d := 0.6 + 0.45 * dirt[i]
			var c: Color
			if ((tx + ty) & 1) == 0:
				c = Color(0.76, 0.72, 0.60) * (j * d)
			else:
				c = Color(0.10, 0.13, 0.12) * (j * (0.8 + 0.3 * dirt[i]))
			if (x & 31) < 2 or (y & 31) < 2:
				c = Color(0.28, 0.27, 0.24) * d
			c.a = 1.0
			_put(px, i, c)
	return _rgb(w, w, px)


static func _tiles_small() -> Image:
	var w := 256
	var dirt := _nbuf(51, 0.025, 4, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var i := y * w + x
			var tx := x >> 4
			var ty := y >> 4
			var j := 0.92 + 0.1 * _hash(tx * 31 + ty * 71)
			if _hash(tx * 7 + ty * 13 + 5) > 0.93:
				j *= 0.8
			var d := 0.62 + 0.4 * dirt[i]
			var c := Color(0.80, 0.84, 0.82) * (j * d)
			if (x & 15) < 1 or (y & 15) < 1:
				c = Color(0.35, 0.34, 0.3) * d
			_put(px, i, c)
	return _rgb(w, w, px)


static func _flagstone() -> Image:
	var w := 256
	var vor := _voronoi(w, 5, 3)
	var ids: PackedInt32Array = vor[0]
	var edge: PackedFloat32Array = vor[1]
	var n := _nbuf(61, 0.06, 4, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var t := 0.55 + 0.45 * _hash(ids[i] + 11)
		var b := t * (0.7 + 0.4 * n[i])
		var c := Color(0.42 * b, 0.40 * b, 0.36 * b)
		var e := edge[i]
		if e < 2.0:
			c = Color(0.12, 0.11, 0.1)
		elif e < 4.0:
			c *= 0.75
		c.a = 1.0
		_put(px, i, c)
	return _rgb(w, w, px)


# ============================================================ murs

static func _stone_wall() -> Image:
	var w := 256
	var n := _nbuf(71, 0.05, 4, w, w)
	var damp := _nbuf(72, 0.015, 3, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		var row := y >> 5
		var off := 32 if (row & 1) == 1 else 0
		for x: int in range(w):
			var i := y * w + x
			var xx := (x + off) & 255
			var bid := row * 8 + (xx >> 6)
			var t := 0.65 + 0.4 * _hash(bid + 5)
			var b := t * (0.72 + 0.35 * n[i]) * (0.7 + 0.35 * damp[i])
			var c := Color(0.40 * b, 0.38 * b, 0.34 * b)
			var lx := xx & 63
			var ly := y & 31
			if lx < 3 or ly < 3:
				c = Color(0.16, 0.15, 0.13) * (0.8 + 0.3 * n[i])
			elif lx < 5 or ly < 5:
				c *= 0.8
			c.a = 1.0
			_put(px, i, c)
	return _rgb(w, w, px)


static func _wallpaper() -> Image:
	var w := 256
	var stain := _nbuf(81, 0.012, 4, w, w)
	var streak := _nbuf(82, 0.03, 3, 256, 32)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		var cy := y >> 6
		var ox := 32 if (cy & 1) == 1 else 0
		for x: int in range(w):
			var i := y * w + x
			var u := float(((x + ox) & 63) - 32) / 32.0
			var v := float((y & 63) - 32) / 32.0
			var motif := 0.0
			var d1 := absf(u) * 1.6 + absf(v)
			if d1 > 0.40 and d1 < 0.52:
				motif = 1.0
			var r := sqrt(u * u + v * v)
			if r < 0.13:
				motif = 1.0
			var cx := absf(u) - 0.62
			var cr := sqrt(cx * cx + v * v)
			if absf(cr - 0.15) < 0.045:
				motif = 0.8
			if absf(u) < 0.035 and absf(v) > 0.62:
				motif = 0.9
			var stripe := 0.035 * sin(float(x) / 256.0 * TAU * 16.0)
			var base := 0.56 + stripe + motif * 0.2
			var s := stain[i]
			var st := streak[(y >> 3) * 256 + x]
			var age := (0.72 + 0.34 * s) * (0.9 + 0.12 * st)
			if s < 0.3:
				age *= 0.85
			var b := base * age
			_put(px, i, Color(b * 1.0, b * 0.95, b * 0.86))
	return _rgb(w, w, px)


static func _plaster() -> Image:
	var w := 256
	var n := _nbuf(91, 0.02, 5, w, w)
	var f := _nbuf(92, 0.2, 2, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var b := 0.68 + 0.2 * n[i] + 0.05 * f[i]
		var yellow := clampf(0.45 - n[i], 0.0, 0.45)
		_put(px, i, Color(b, b * (0.97 - yellow * 0.1), b * (0.9 - yellow * 0.3)))
	return _rgb(w, w, px)


static func _secret_wall() -> Image:
	var w := 256
	var img := _plaster()
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var c := img.get_pixel(x, y)
			_put(px, y * w + x, c * Color(0.62, 0.5, 0.45))
	var red := Color(0.35, 0.03, 0.02)
	_draw_ring(px, w, w, 128.0, 110.0, 56.0, 3.0, red)
	_draw_ring(px, w, w, 128.0, 110.0, 44.0, 2.0, red)
	for k: int in range(7):
		var a := TAU * float(k) / 7.0
		var a2 := TAU * float(k + 3) / 7.0
		_draw_line(px, w, w, 128.0 + cos(a) * 44.0, 110.0 + sin(a) * 44.0, 128.0 + cos(a2) * 44.0, 110.0 + sin(a2) * 44.0, 1.6, red)
	for k: int in range(14):
		var yy := 190.0 + float(k % 2) * 22.0
		var xx := 20.0 + float(k) * 16.0
		_draw_line(px, w, w, xx, yy, xx + 6.0 * _hash(k), yy + 14.0, 1.4, red)
		_draw_line(px, w, w, xx + 6.0, yy, xx, yy + 8.0 * _hash(k + 50), 1.4, red)
	for k: int in range(5):
		var sx := 20.0 + _hash(k + 900) * 210.0
		_draw_line(px, w, w, sx, 10.0, sx + 3.0, 10.0 + 60.0 * _hash(k + 800), 2.0, red * 0.8)
	return _rgb(w, w, px)


static func _wood() -> Image:
	var w := 256
	var grain := _nbuf(101, 0.04, 4, 256, 64)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var gy := y >> 2
			var g := grain[gy * 256 + ((x * 3) & 255)]
			var rings := 0.5 + 0.5 * sin(g * 36.0)
			var b := 0.62 + 0.25 * rings + 0.15 * g
			_put(px, y * w + x, Color(0.52 * b, 0.34 * b, 0.2 * b))
	return _rgb(w, w, px)


static func _wood_panel() -> Image:
	var w := 256
	var grain := _nbuf(111, 0.05, 3, 256, 64)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var g := grain[(y >> 2) * 256 + ((x * 2) & 255)]
			var b := 0.65 + 0.3 * g
			var lx := x & 127
			var ly := y
			var k := 1.0
			var inner := lx > 18 and lx < 110 and ly > 22 and ly < 234
			if not inner:
				k = 0.9
			if (lx == 18 or lx == 19) and ly > 22 and ly < 234:
				k = 0.55
			elif (lx == 110 or lx == 111) and ly > 22 and ly < 234:
				k = 1.25
			elif (ly == 22 or ly == 23) and lx > 18 and lx < 110:
				k = 0.55
			elif (ly == 234 or ly == 235) and lx > 18 and lx < 110:
				k = 1.25
			if lx < 2:
				k = 0.4
			_put(px, y * w + x, Color(0.40 * b * k, 0.25 * b * k, 0.15 * b * k))
	return _rgb(w, w, px)


static func _brick() -> Image:
	var w := 256
	var n := _nbuf(121, 0.05, 3, w, w)
	var soot := _nbuf(122, 0.015, 3, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		var row := int(float(y) / 21.34)
		var off := 32 if (row & 1) == 1 else 0
		for x: int in range(w):
			var i := y * w + x
			var xx := (x + off) & 255
			var bid := row * 4 + (xx >> 6)
			var t := 0.7 + 0.35 * _hash(bid + 77)
			var b := t * (0.75 + 0.3 * n[i]) * (0.55 + 0.5 * soot[i])
			var c := Color(0.50 * b, 0.22 * b, 0.15 * b)
			var ly := fmod(float(y), 21.34)
			if (xx & 63) < 3 or ly < 2.5:
				c = Color(0.3, 0.28, 0.25) * (0.5 + 0.5 * soot[i])
			c.a = 1.0
			_put(px, i, c)
	return _rgb(w, w, px)


# ============================================================ tissus / objets

static func _fabric() -> Image:
	var w := 128
	var n := _nbuf(131, 0.04, 3, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var weave := 0.9 if ((x + (y >> 1)) & 3) < 2 else 1.05
			var b := weave * (0.72 + 0.35 * n[y * w + x])
			_put(px, y * w + x, Color(b, b, b))
	return _rgb(w, w, px)


static func _carpet() -> Image:
	var w := 256
	var n := _nbuf(141, 0.03, 4, w, w)
	var px := _buf(w, w, 3)
	var red := Color(0.42, 0.06, 0.05)
	var gold := Color(0.55, 0.42, 0.18)
	var dark := Color(0.10, 0.04, 0.04)
	for y: int in range(w):
		for x: int in range(w):
			var u := float(x) / float(w)
			var v := float(y & 127) / 128.0
			var c := red
			if u < 0.06 or u > 0.94:
				c = dark
			elif u < 0.1 or u > 0.9:
				c = gold
			elif u < 0.14 or u > 0.86:
				c = dark
			else:
				var cu := (u - 0.5) * 2.6
				var cv := (v - 0.5) * 2.0
				var d := absf(cu) + absf(cv)
				if absf(d - 0.7) < 0.06:
					c = gold
				elif d < 0.3:
					c = dark
				elif absf(d - 0.5) < 0.04:
					c = Color(0.2, 0.08, 0.1)
			var wear := 0.65 + 0.45 * n[y * w + x]
			var center_wear := 1.0 + 0.15 * (1.0 - absf(u - 0.5) * 2.0)
			_put(px, y * w + x, c * (wear * center_wear))
	return _rgb(w, w, px)


static func _rug() -> Image:
	var w := 256
	var n := _nbuf(151, 0.04, 4, w, w)
	var px := _buf(w, w, 3)
	var base := Color(0.20, 0.07, 0.10)
	var border := Color(0.45, 0.30, 0.14)
	var navy := Color(0.06, 0.07, 0.14)
	for y: int in range(w):
		for x: int in range(w):
			var u := float(x) / float(w - 1) * 2.0 - 1.0
			var v := float(y) / float(w - 1) * 2.0 - 1.0
			var e := maxf(absf(u), absf(v))
			var c := base
			if e > 0.92:
				c = navy
			elif e > 0.84:
				c = border
			elif e > 0.8:
				c = navy
			else:
				var d := absf(u) * 1.3 + absf(v)
				if d < 0.35:
					c = border
				elif d < 0.42:
					c = navy
				elif absf(d - 0.7) < 0.04:
					c = border
				var pat := sin(u * 30.0) * sin(v * 30.0)
				if pat > 0.85:
					c = c * 1.5
			_put(px, y * w + x, c * (0.65 + 0.5 * n[y * w + x]))
	return _rgb(w, w, px)


static func _metal() -> Image:
	var w := 128
	var n := _nbuf(161, 0.05, 4, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var b := 0.3 + 0.35 * n[i]
		_put(px, i, Color(b, b * 0.97, b * 0.92))
	for k: int in range(40):
		var x0 := _hash(k * 3) * 128.0
		var y0 := _hash(k * 3 + 1) * 128.0
		var ang := _hash(k * 3 + 2) * PI
		_draw_line(px, w, w, x0, y0, x0 + cos(ang) * 18.0, y0 + sin(ang) * 18.0, 0.6, Color(0.6, 0.58, 0.55))
	return _rgb(w, w, px)


static func _paper() -> Image:
	var w := 256
	var n := _nbuf(171, 0.02, 4, w, w)
	var fib := _nbuf(172, 0.3, 2, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var i := y * w + x
			var u := float(x) / float(w) - 0.5
			var v := float(y) / float(w) - 0.5
			var edge := clampf(1.0 - pow(maxf(absf(u), absf(v)) * 2.0, 6.0) * 0.5, 0.0, 1.0)
			var b := (0.84 + 0.1 * n[i] + 0.04 * fib[i]) * edge
			var stain := clampf(0.35 - n[i], 0.0, 0.35)
			_put(px, i, Color(b, b * (0.95 - stain * 0.3), b * (0.82 - stain * 0.6)))
	# lignes d'écriture
	for line: int in range(14):
		var yy := 40.0 + float(line) * 13.0
		var x1 := 30.0 + 190.0 * (0.6 + 0.4 * _hash(line + 3))
		_draw_line(px, w, w, 30.0, yy, x1, yy + 1.0, 0.7, Color(0.25, 0.2, 0.18))
	return _rgb(w, w, px)


static func _paper_blank() -> Image:
	var w := 256
	var n := _nbuf(173, 0.02, 4, w, w)
	var fib := _nbuf(174, 0.3, 2, w, w)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var i := y * w + x
			var u := float(x) / float(w) - 0.5
			var v := float(y) / float(w) - 0.5
			var edge := clampf(1.0 - pow(maxf(absf(u), absf(v)) * 2.0, 8.0) * 0.45, 0.0, 1.0)
			var b := (0.86 + 0.08 * n[i] + 0.03 * fib[i]) * edge
			var stain := clampf(0.3 - n[i], 0.0, 0.3)
			_put(px, i, Color(b, b * (0.95 - stain * 0.3), b * (0.82 - stain * 0.5)))
	return _rgb(w, w, px)


static func _books() -> Image:
	var w := 64
	var h := 128
	var n := _nbuf(181, 0.08, 3, w, h)
	var px := _buf(w, h, 3)
	for y: int in range(h):
		for x: int in range(w):
			var v := float(y) / float(h)
			var b := 0.55 + 0.35 * n[y * w + x]
			var c := Color(b, b, b)
			if absf(v - 0.12) < 0.02 or absf(v - 0.88) < 0.02 or absf(v - 0.2) < 0.008:
				c = Color(0.95, 0.8, 0.4)
			if absf(v - 0.45) < 0.06 and x > 16 and x < 48:
				c = Color(0.2, 0.18, 0.15)
			_put(px, y * w + x, c)
	return _rgb(w, h, px)


static func _skin() -> Image:
	var w := 128
	var n := _nbuf(191, 0.05, 4, w, w)
	var veins := _nbuf(192, 0.03, 3, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var b := 0.7 + 0.25 * n[i]
		var c := Color(0.78 * b, 0.77 * b, 0.70 * b)
		var vn := 1.0 - absf(veins[i] - 0.5) * 2.0
		if vn > 0.92:
			c = c.lerp(Color(0.28, 0.3, 0.38), (vn - 0.92) * 8.0)
		if n[i] < 0.28:
			c = c.lerp(Color(0.35, 0.33, 0.3), 0.4)
		_put(px, i, c)
	return _rgb(w, w, px)


static func _ground() -> Image:
	var w := 256
	var n := _nbuf(201, 0.02, 5, w, w)
	var f := _nbuf(202, 0.15, 2, w, w)
	var px := _buf(w, w, 3)
	for i: int in range(w * w):
		var g := n[i]
		var c := Color(0.14, 0.12, 0.09).lerp(Color(0.12, 0.16, 0.09), g) * (0.7 + 0.5 * f[i])
		_put(px, i, c)
	return _rgb(w, w, px)


static func _bark() -> Image:
	var w := 128
	var n := _nbuf(211, 0.05, 4, 128, 32)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			var g := n[(y >> 2) * 128 + ((x * 4) & 127)]
			var ridge := 1.0 - absf(g - 0.5) * 2.0
			var b := 0.35 + 0.5 * ridge
			_put(px, y * w + x, Color(0.24 * b, 0.21 * b, 0.18 * b))
	return _rgb(w, w, px)


# ============================================================ vitraux, fenêtres, lumière

static func _window_night() -> Image:
	var w := 64
	var h := 128
	var clouds := _nbuf(221, 0.05, 4, w, h)
	var px := _buf(w, h, 3)
	for y: int in range(h):
		for x: int in range(w):
			var v := float(y) / float(h)
			var sky := Color(0.10, 0.13, 0.22).lerp(Color(0.015, 0.02, 0.03), v)
			var cl := clouds[y * w + x]
			sky = sky.lerp(Color(0.2, 0.23, 0.3), clampf((cl - 0.55) * 1.5, 0.0, 0.5) * (1.0 - v))
			if v > 0.78:
				sky = Color(0.01, 0.012, 0.015)
			_put(px, y * w + x, sky)
	var black := Color(0.005, 0.006, 0.008)
	_draw_line(px, w, h, 10.0, 128.0, 16.0, 70.0, 2.4, black)
	_draw_line(px, w, h, 16.0, 70.0, 6.0, 40.0, 1.4, black)
	_draw_line(px, w, h, 16.0, 70.0, 30.0, 45.0, 1.2, black)
	_draw_line(px, w, h, 30.0, 45.0, 40.0, 30.0, 0.8, black)
	_draw_line(px, w, h, 52.0, 128.0, 50.0, 88.0, 1.8, black)
	_draw_line(px, w, h, 50.0, 88.0, 60.0, 64.0, 1.0, black)
	_draw_line(px, w, h, 50.0, 88.0, 40.0, 70.0, 0.9, black)
	return _rgb(w, h, px)


static func _stained_glass() -> Image:
	var w := 128
	var vor := _voronoi(w, 4, 9)
	var ids: PackedInt32Array = vor[0]
	var edge: PackedFloat32Array = vor[1]
	var px := _buf(w, w, 3)
	var palette: Array[Color] = [
		Color(0.55, 0.05, 0.05), Color(0.08, 0.12, 0.45), Color(0.5, 0.38, 0.06),
		Color(0.08, 0.3, 0.12), Color(0.35, 0.08, 0.35), Color(0.6, 0.55, 0.4),
	]
	for i: int in range(w * w):
		var c: Color = palette[ids[i] % palette.size()]
		c = c * (0.8 + 0.4 * _hash(ids[i] + 3))
		if edge[i] < 1.5:
			c = Color(0.02, 0.02, 0.02)
		_put(px, i, c)
	return _rgb(w, w, px)


static func _window_pane() -> Image:
	var w := 64
	var px := _buf(w, w, 4)
	for y: int in range(w):
		for x: int in range(w):
			var u := float(x) / float(w - 1)
			var v := float(y) / float(w - 1)
			var bars := 1.0
			if absf(u - 0.5) < 0.03 or absf(v - 0.5) < 0.03:
				bars = 0.1
			var fade := clampf(1.0 - pow(maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0, 3.0), 0.0, 1.0)
			var a := bars * fade
			var j := (y * w + x) * 4
			px[j] = 1.0
			px[j + 1] = 1.0
			px[j + 2] = 1.0
			px[j + 3] = a
	return _rgba(w, w, px)


static func _flame() -> Image:
	var w := 64
	var px := _buf(w, w, 4)
	for y: int in range(w):
		for x: int in range(w):
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0
			var v := float(y) / float(w - 1)
			var width := 0.55 * sin(clampf(v, 0.0, 1.0) * PI * 0.9 + 0.1) * (0.4 + 0.6 * v)
			var d := absf(u) / maxf(width, 0.01)
			var a := clampf(1.0 - d, 0.0, 1.0) * clampf(v * 3.0, 0.0, 1.0) * clampf((1.0 - v) * 8.0, 0.0, 1.0)
			a = pow(a, 0.7)
			var core := clampf(1.0 - d * 1.6, 0.0, 1.0) * v
			var c := Color(1.0, 0.55 + 0.4 * core, 0.2 + 0.6 * core)
			var j := (y * w + x) * 4
			px[j] = c.r
			px[j + 1] = c.g
			px[j + 2] = c.b
			px[j + 3] = a
	return _rgba(w, w, px)


static func _glow() -> Image:
	var w := 64
	var px := _buf(w, w, 4)
	for y: int in range(w):
		for x: int in range(w):
			var u := float(x) / float(w - 1) * 2.0 - 1.0
			var v := float(y) / float(w - 1) * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.2)
			var j := (y * w + x) * 4
			px[j] = 1.0
			px[j + 1] = 1.0
			px[j + 2] = 1.0
			px[j + 3] = a
	return _rgba(w, w, px)


static func _cobweb() -> Image:
	var w := 128
	var px := _buf(w, w, 4)
	var col := Color(0.85, 0.85, 0.82)
	# fils radiaux depuis le coin (0,0)
	for k: int in range(9):
		var ang := (float(k) + 0.3 * _hash(k)) / 8.0 * (PI * 0.5)
		_draw_line_a(px, w, 0.0, 0.0, cos(ang) * 130.0, sin(ang) * 130.0, 0.8, col, 0.9)
	# arcs irréguliers
	for ring: int in range(1, 9):
		var r := float(ring) * 14.0 + 4.0 * _hash(ring + 20)
		var prev := Vector2(r, 0.0)
		for s: int in range(1, 11):
			var ang2 := float(s) / 10.0 * (PI * 0.5)
			var rr := r * (0.9 + 0.1 * _hash(ring * 20 + s))
			var p := Vector2(cos(ang2) * rr, sin(ang2) * rr)
			_draw_line_a(px, w, prev.x, prev.y, p.x, p.y, 0.6, col, 0.75)
			prev = p
	return _rgba(w, w, px)


# ============================================================ peintures, dessins

static func _portrait(variant: int, scare: bool) -> Image:
	var w := 128
	var h := 160
	var n := _nbuf(230 + variant, 0.04, 4, w, h)
	var crack := _nbuf(240 + variant, 0.12, 2, w, h)
	var px := _buf(w, h, 3)
	var bg_top := [Color(0.16, 0.12, 0.08), Color(0.08, 0.12, 0.1), Color(0.14, 0.08, 0.08)][variant - 1] as Color
	for y: int in range(h):
		for x: int in range(w):
			var v := float(y) / float(h)
			var c := bg_top.lerp(Color(0.03, 0.025, 0.02), v)
			var u := float(x) / float(w) - 0.5
			var lit := clampf(1.0 - Vector2(u * 1.4, v - 0.35).length() * 1.6, 0.0, 1.0)
			c = c * (0.7 + 0.8 * lit)
			_put(px, y * w + x, c * (0.8 + 0.35 * n[y * w + x]))
	# corps
	var cloth := [Color(0.05, 0.04, 0.04), Color(0.1, 0.03, 0.03), Color(0.04, 0.05, 0.08)][variant - 1] as Color
	_fill_ellipse(px, w, h, 64.0, 170.0, 58.0, 62.0, cloth)
	_fill_ellipse(px, w, h, 64.0, 118.0, 12.0, 14.0, Color(0.55, 0.45, 0.38) * 0.7)
	if variant == 2:
		_fill_ellipse(px, w, h, 64.0, 128.0, 16.0, 6.0, Color(0.85, 0.82, 0.75))
	# visage
	var skin := Color(0.72, 0.6, 0.5)
	if scare:
		skin = Color(0.62, 0.62, 0.58)
	var fh := 30.0 if variant != 3 else 26.0
	_fill_ellipse(px, w, h, 64.0, 78.0, 21.0, fh, skin)
	# cheveux
	var hair := [Color(0.12, 0.08, 0.05), Color(0.2, 0.16, 0.1), Color(0.35, 0.25, 0.12)][variant - 1] as Color
	_fill_ellipse(px, w, h, 64.0, 56.0, 23.0, 14.0, hair)
	if variant == 3:
		_fill_ellipse(px, w, h, 44.0, 84.0, 7.0, 24.0, hair)
		_fill_ellipse(px, w, h, 84.0, 84.0, 7.0, 24.0, hair)
	if scare:
		_fill_ellipse(px, w, h, 55.0, 76.0, 6.5, 7.5, Color(0.0, 0.0, 0.0))
		_fill_ellipse(px, w, h, 73.0, 76.0, 6.5, 7.5, Color(0.0, 0.0, 0.0))
		_fill_ellipse(px, w, h, 55.0, 76.0, 1.6, 1.6, Color(1.0, 0.95, 0.7))
		_fill_ellipse(px, w, h, 73.0, 76.0, 1.6, 1.6, Color(1.0, 0.95, 0.7))
		_fill_ellipse(px, w, h, 64.0, 97.0, 11.0, 7.0, Color(0.05, 0.0, 0.0))
		for t: int in range(7):
			var tx := 55.0 + float(t) * 3.0
			_draw_line(px, w, h, tx, 91.0, tx + 0.5, 95.0, 0.6, Color(0.8, 0.75, 0.6))
		_draw_line(px, w, h, 55.0, 83.0, 53.0, 110.0, 0.8, Color(0.3, 0.0, 0.0))
		_draw_line(px, w, h, 73.0, 83.0, 76.0, 112.0, 0.8, Color(0.3, 0.0, 0.0))
	else:
		_fill_ellipse(px, w, h, 56.0, 76.0, 3.5, 2.2, Color(0.12, 0.08, 0.06))
		_fill_ellipse(px, w, h, 72.0, 76.0, 3.5, 2.2, Color(0.12, 0.08, 0.06))
		_draw_line(px, w, h, 58.0, 96.0, 70.0, 96.0, 0.8, Color(0.35, 0.18, 0.15))
	# craquelures
	for i: int in range(w * h):
		var cr := 1.0 - absf(crack[i] - 0.5) * 2.0
		if cr > 0.94:
			var j := i * 3
			px[j] *= 0.55
			px[j + 1] *= 0.55
			px[j + 2] *= 0.55
	return _rgb(w, h, px)


static func _drawing() -> Image:
	var w := 128
	var img := _paper()
	img.resize(w, w, Image.INTERPOLATE_BILINEAR)
	var px := _buf(w, w, 3)
	for y: int in range(w):
		for x: int in range(w):
			_put(px, y * w + x, img.get_pixel(x, y))
	var crayon := Color(0.1, 0.08, 0.08)
	# maison
	_draw_line(px, w, w, 20.0, 100.0, 20.0, 60.0, 1.2, crayon)
	_draw_line(px, w, w, 20.0, 60.0, 50.0, 35.0, 1.2, crayon)
	_draw_line(px, w, w, 50.0, 35.0, 80.0, 60.0, 1.2, crayon)
	_draw_line(px, w, w, 80.0, 60.0, 80.0, 100.0, 1.2, crayon)
	_draw_line(px, w, w, 20.0, 100.0, 80.0, 100.0, 1.2, crayon)
	# petite fille
	var pink := Color(0.7, 0.2, 0.3)
	_draw_ring(px, w, w, 40.0, 76.0, 5.0, 1.0, pink)
	_draw_line(px, w, w, 40.0, 81.0, 40.0, 92.0, 1.0, pink)
	_draw_line(px, w, w, 34.0, 86.0, 46.0, 86.0, 1.0, pink)
	# grand homme noir aux yeux blancs
	var black := Color(0.02, 0.02, 0.02)
	_fill_ellipse(px, w, w, 100.0, 40.0, 7.0, 9.0, black)
	_draw_line(px, w, w, 100.0, 48.0, 100.0, 95.0, 3.0, black)
	_draw_line(px, w, w, 100.0, 55.0, 86.0, 90.0, 1.4, black)
	_draw_line(px, w, w, 100.0, 55.0, 114.0, 90.0, 1.4, black)
	_draw_line(px, w, w, 100.0, 95.0, 94.0, 118.0, 1.4, black)
	_draw_line(px, w, w, 100.0, 95.0, 106.0, 118.0, 1.4, black)
	_fill_ellipse(px, w, w, 97.0, 39.0, 1.8, 1.8, Color(1, 1, 1))
	_fill_ellipse(px, w, w, 103.0, 39.0, 1.8, 1.8, Color(1, 1, 1))
	# gribouillis rouge
	for k: int in range(10):
		_draw_line(px, w, w, 88.0 + _hash(k) * 25.0, 20.0 + _hash(k + 9) * 10.0, 88.0 + _hash(k + 3) * 25.0, 22.0 + _hash(k + 5) * 10.0, 0.9, Color(0.6, 0.05, 0.05))
	return _rgb(w, w, px)


# ============================================================ primitives de dessin (tampons RGB)

static func _fill_ellipse(px: PackedFloat32Array, w: int, h: int, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var x0 := maxi(0, int(cx - rx) - 1)
	var x1 := mini(w - 1, int(cx + rx) + 1)
	var y0 := maxi(0, int(cy - ry) - 1)
	var y1 := mini(h - 1, int(cy + ry) + 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var j := (y * w + x) * 3
				var shade := 1.0 - d * 0.25
				px[j] = c.r * shade
				px[j + 1] = c.g * shade
				px[j + 2] = c.b * shade


static func _draw_line(px: PackedFloat32Array, w: int, h: int, x0: float, y0: float, x1: float, y1: float, thick: float, c: Color) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
	var r := int(ceil(thick))
	for s: int in range(steps + 1):
		var t := float(s) / float(steps)
		var fx := lerpf(x0, x1, t)
		var fy := lerpf(y0, y1, t)
		for oy: int in range(-r, r + 1):
			for ox: int in range(-r, r + 1):
				var x := int(fx) + ox
				var y := int(fy) + oy
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				if Vector2(float(ox), float(oy)).length() > thick:
					continue
				var j := (y * w + x) * 3
				px[j] = c.r
				px[j + 1] = c.g
				px[j + 2] = c.b


static func _draw_ring(px: PackedFloat32Array, w: int, h: int, cx: float, cy: float, radius: float, thick: float, c: Color) -> void:
	var segs := int(radius * 3.0) + 8
	for s: int in range(segs):
		var a0 := TAU * float(s) / float(segs)
		var a1 := TAU * float(s + 1) / float(segs)
		_draw_line(px, w, h, cx + cos(a0) * radius, cy + sin(a0) * radius, cx + cos(a1) * radius, cy + sin(a1) * radius, thick, c)


## Ligne sur un tampon RGBA carré de côté w (pour les textures transparentes).
static func _draw_line_a(px: PackedFloat32Array, w: int, x0: float, y0: float, x1: float, y1: float, thick: float, c: Color, alpha: float) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
	for s: int in range(steps + 1):
		var t := float(s) / float(steps)
		var fx := lerpf(x0, x1, t)
		var fy := lerpf(y0, y1, t)
		var x := int(fx)
		var y := int(fy)
		if x < 0 or y < 0 or x >= w or y >= w:
			continue
		var j := (y * w + x) * 4
		px[j] = c.r
		px[j + 1] = c.g
		px[j + 2] = c.b
		px[j + 3] = maxf(px[j + 3], alpha * clampf(thick, 0.0, 1.0))
