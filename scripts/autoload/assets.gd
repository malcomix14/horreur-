extends Node
## Assets : textures procédurales (mises en cache dans user://) et bibliothèque de matériaux.
## Tous les matériaux sont légers (StandardMaterial3D, pas de normal map) pour les iGPU.

const CACHE_DIR: String = "user://cache"
const CACHE_VERSION: int = 4

var _textures: Dictionary = {}
var _materials: Dictionary = {}
var _uv: Dictionary = {}
## Fusion de matériaux : clé -> [clé de surface commune, teinte]. Les matériaux qui ne diffèrent
## que par leur couleur partagent une seule surface (teinte cuite dans les couleurs de sommets),
## ce qui divise le nombre d'appels de dessin par pièce.
var _alias: Dictionary = {}
var _font_serif: Font = null
var _font_hand: Font = null
var ready_done: bool = false


## Prépare toutes les textures. `progress` reçoit (ratio: float, texte: String).
func prepare(progress: Callable) -> void:
	if ready_done:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var names := TextureFactory.NAMES
	var total := names.size()
	var i := 0
	for tex_name: String in names:
		var img := _load_or_generate(tex_name)
		img.generate_mipmaps()
		_textures[tex_name] = ImageTexture.create_from_image(img)
		i += 1
		if progress.is_valid():
			progress.call(float(i) / float(total), "Textures : %s" % tex_name)
		if i % 3 == 0:
			await get_tree().process_frame
	_build_materials()
	ready_done = true


func _load_or_generate(tex_name: String) -> Image:
	var path := "%s/tex_%s_v%d.png" % [CACHE_DIR, tex_name, CACHE_VERSION]
	if FileAccess.file_exists(path):
		var cached := Image.load_from_file(path)
		if cached != null and not cached.is_empty():
			return cached
	var img := TextureFactory.generate(tex_name)
	var err := img.save_png(path)
	if err != OK:
		push_warning("Cache texture impossible (%s)" % tex_name)
	return img


func tex(tex_name: String) -> Texture2D:
	if _textures.has(tex_name):
		return _textures[tex_name] as Texture2D
	# Génération à la demande (ne devrait pas arriver après prepare()).
	var img := TextureFactory.generate(tex_name)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_textures[tex_name] = t
	return t


## Renvoie le matériau associé à la clé (jamais null : repli magenta si inconnu).
func mat(key: String) -> Material:
	if _materials.has(key):
		return _materials[key] as Material
	push_warning("Matériau inconnu : %s" % key)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0, 1)
	_materials[key] = m
	return m


func std_mat(key: String) -> StandardMaterial3D:
	return mat(key) as StandardMaterial3D


## Clé de surface à utiliser dans un lot (MeshBatcher) et teinte à appliquer aux sommets.
func batch_key(key: String) -> Array:
	if _alias.has(key):
		return _alias[key] as Array
	return [key, Color.WHITE]


func _build_aliases() -> void:
	var bases: Dictionary = {}
	for k: Variant in _materials.keys():
		var key := str(k)
		var m := _materials[key] as StandardMaterial3D
		if m == null or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			continue
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.emission_enabled:
			continue
		if not m.vertex_color_use_as_albedo:
			continue
		var c := m.albedo_color
		if c.r > 1.0 or c.g > 1.0 or c.b > 1.0:
			continue
		var tex_id := "none"
		if m.albedo_texture != null:
			tex_id = str(m.albedo_texture.get_rid().get_id())
		var rough := snappedf(m.roughness, 0.25)
		var metal := snappedf(m.metallic, 0.5)
		var base_key := "base|%s|%.2f|%.1f" % [tex_id, rough, metal]
		if not bases.has(base_key):
			var bm := StandardMaterial3D.new()
			bm.albedo_texture = m.albedo_texture
			bm.albedo_color = Color.WHITE
			bm.roughness = rough
			bm.metallic = metal
			bm.metallic_specular = m.metallic_specular
			bm.vertex_color_use_as_albedo = true
			bm.texture_filter = m.texture_filter
			_materials[base_key] = bm
			bases[base_key] = true
		_alias[key] = [base_key, Color(c.r, c.g, c.b, 1.0)]


## Nombre de répétitions de la texture par mètre (pour la projection UV monde).
func uv_scale(key: String) -> float:
	return float(_uv.get(key, 1.0))


func font_serif() -> Font:
	if _font_serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Garamond", "Book Antiqua", "Palatino Linotype", "Times New Roman", "Liberation Serif", "DejaVu Serif", "Noto Serif", "serif"])
		_font_serif = f
	return _font_serif


func font_hand() -> Font:
	if _font_hand == null:
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Lucida Handwriting", "Georgia", "Times New Roman", "DejaVu Serif", "serif"])
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.18, 1.0), Vector2.ZERO)
		_font_hand = fv
	return _font_hand


# ============================================================ matériaux

func _std(key: String, tex_name: String, color: Color, rough: float, uv: float = 1.0, spec: float = 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if tex_name != "":
		m.albedo_texture = tex(tex_name)
	m.albedo_color = color
	m.roughness = rough
	m.metallic_specular = spec
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	_uv[key] = uv
	return m


func _unshaded(key: String, tex_name: String, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_name != "":
		m.albedo_texture = tex(tex_name)
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	_materials[key] = m
	return m


func _build_materials() -> void:
	# --- sols
	_std("floor_parquet", "parquet", Color(1.0, 0.95, 0.9), 0.45, 0.9, 0.5)
	_std("floor_parquet_dark", "parquet", Color(0.62, 0.55, 0.52), 0.5, 0.9, 0.5)
	_std("floor_planks", "planks", Color(0.9, 0.88, 0.85), 0.8, 0.6)
	_std("floor_marble", "marble", Color(1, 1, 1), 0.22, 0.42, 0.6)
	_std("floor_tiles", "tiles_check", Color(1, 1, 1), 0.4, 0.5, 0.55)
	_std("floor_bath", "tiles_small", Color(0.95, 0.97, 0.97), 0.35, 0.6, 0.55)
	_std("floor_stone", "flagstone", Color(0.9, 0.9, 0.88), 0.85, 0.33)
	_std("floor_chapel", "flagstone", Color(1.1, 1.05, 1.0), 0.75, 0.3)
	# --- murs
	_std("wp_green", "wallpaper", Color(0.46, 0.62, 0.48), 0.8, 1.4)
	_std("wp_red", "wallpaper", Color(0.7, 0.34, 0.32), 0.8, 1.4)
	_std("wp_blue", "wallpaper", Color(0.46, 0.55, 0.72), 0.8, 1.4)
	_std("wp_olive", "wallpaper", Color(0.68, 0.66, 0.46), 0.8, 1.4)
	_std("wp_pink", "wallpaper", Color(0.88, 0.66, 0.66), 0.8, 1.6)
	_std("wp_burgundy", "wallpaper", Color(0.55, 0.28, 0.33), 0.8, 1.4)
	_std("wp_gold", "wallpaper", Color(0.8, 0.68, 0.46), 0.75, 1.1)
	_std("wp_teal", "wallpaper", Color(0.4, 0.6, 0.6), 0.8, 1.4)
	_std("plaster", "plaster", Color(0.92, 0.9, 0.86), 0.9, 0.5)
	_std("plaster_dirty", "plaster", Color(0.72, 0.68, 0.6), 0.9, 0.5)
	_std("stone_wall", "stone_wall", Color(0.95, 0.95, 0.95), 0.9, 0.55)
	_std("tiles_wall", "tiles_small", Color(0.9, 0.95, 0.93), 0.3, 0.6, 0.6)
	_std("wainscot", "wood_panel", Color(0.95, 0.9, 0.85), 0.55, 1.0, 0.45)
	_std("wainscot_dark", "wood_panel", Color(0.6, 0.52, 0.5), 0.55, 1.0, 0.45)
	_std("wainscot_white", "wood_panel", Color(2.0, 2.1, 2.2), 0.6, 1.0)
	_std("secret_wall", "secret_wall", Color(1, 1, 1), 0.9, 0.4)
	_std("exterior", "stone_wall", Color(0.4, 0.4, 0.42), 0.95, 0.5)
	# --- plafonds
	_std("ceiling", "plaster", Color(0.8, 0.78, 0.74), 0.95, 0.4)
	_std("ceiling_dark", "plaster", Color(0.45, 0.42, 0.38), 0.95, 0.4)
	_std("ceiling_wood", "planks", Color(0.55, 0.5, 0.45), 0.9, 0.5)
	_std("ceiling_stone", "stone_wall", Color(0.6, 0.6, 0.6), 0.95, 0.5)
	# --- boiseries et mobilier
	_std("trim", "wood", Color(0.45, 0.33, 0.26), 0.5, 1.5, 0.5)
	_std("trim_white", "plaster", Color(0.95, 0.93, 0.88), 0.7, 1.0)
	_std("wood_dark", "wood", Color(0.45, 0.36, 0.3), 0.5, 1.2, 0.5)
	_std("wood_med", "wood", Color(0.85, 0.75, 0.65), 0.55, 1.2, 0.5)
	_std("wood_light", "wood", Color(1.2, 1.1, 0.95), 0.6, 1.2)
	_std("wood_black", "wood", Color(0.2, 0.17, 0.16), 0.45, 1.2, 0.55)
	_std("wood_raw", "planks", Color(0.9, 0.85, 0.8), 0.9, 1.0)
	_std("fabric_red", "fabric", Color(0.5, 0.1, 0.1), 0.95, 3.0, 0.2)
	_std("fabric_green", "fabric", Color(0.18, 0.3, 0.2), 0.95, 3.0, 0.2)
	_std("fabric_blue", "fabric", Color(0.18, 0.22, 0.38), 0.95, 3.0, 0.2)
	_std("fabric_cream", "fabric", Color(0.8, 0.76, 0.66), 0.95, 3.0, 0.2)
	_std("fabric_pink", "fabric", Color(0.8, 0.55, 0.58), 0.95, 3.0, 0.2)
	_std("sheet", "fabric", Color(0.78, 0.77, 0.74), 1.0, 1.5, 0.2)
	_std("leather", "fabric", Color(0.25, 0.14, 0.09), 0.6, 2.0, 0.4)
	_std("metal", "metal", Color(0.55, 0.55, 0.55), 0.45, 2.0, 0.6)
	_std("iron_black", "metal", Color(0.18, 0.18, 0.2), 0.5, 2.0, 0.5)
	var brass := _std("brass", "metal", Color(0.85, 0.65, 0.3), 0.35, 2.0, 0.7)
	brass.metallic = 0.6
	var gold := _std("gold_frame", "metal", Color(0.8, 0.6, 0.25), 0.35, 2.0, 0.7)
	gold.metallic = 0.55
	_std("porcelain", "", Color(0.88, 0.87, 0.84), 0.2, 1.0, 0.6)
	_std("brick", "brick", Color(1, 1, 1), 0.9, 1.2)
	_std("soot", "brick", Color(0.18, 0.16, 0.15), 1.0, 1.2)
	_std("carpet", "carpet", Color(1, 1, 1), 0.95, 1.0, 0.2)
	_std("rug", "rug", Color(1, 1, 1), 0.95, 1.0, 0.2)
	_std("rug_blue", "rug", Color(0.5, 0.7, 1.3), 0.95, 1.0, 0.2)
	_std("marble_white", "marble_plain", Color(0.95, 0.94, 0.92), 0.3, 1.2, 0.6)
	_std("stone_dark", "flagstone", Color(0.55, 0.55, 0.55), 0.9, 1.0)
	_std("rubble", "stone_wall", Color(0.6, 0.58, 0.55), 1.0, 2.0)
	_std("bone", "plaster", Color(0.85, 0.8, 0.68), 0.6, 2.0)
	_std("paper", "paper", Color(1, 1, 1), 0.9, 1.0, 0.2)
	_std("books", "books", Color(1, 1, 1), 0.7, 1.0, 0.3)
	_std("wax", "", Color(0.85, 0.82, 0.72), 0.5, 1.0, 0.4)
	_std("black", "", Color(0.02, 0.02, 0.02), 1.0, 1.0, 0.1)
	_std("ground", "ground", Color(0.8, 0.8, 0.8), 1.0, 0.25, 0.1)
	_std("bark", "bark", Color(0.8, 0.8, 0.8), 1.0, 1.5, 0.1)
	_std("drawing", "drawing", Color(1, 1, 1), 0.9, 1.0, 0.2)
	_std("portrait_a", "portrait_a", Color(1, 1, 1), 0.5, 1.0, 0.5)
	_std("portrait_b", "portrait_b", Color(1, 1, 1), 0.5, 1.0, 0.5)
	_std("portrait_c", "portrait_c", Color(1, 1, 1), 0.5, 1.0, 0.5)
	_std("portrait_scare", "portrait_scare", Color(1, 1, 1), 0.5, 1.0, 0.5)
	_std("water", "", Color(0.06, 0.07, 0.06), 0.05, 1.0, 0.8)
	_std("toy_red", "", Color(0.55, 0.08, 0.06), 0.6, 1.0)
	_std("toy_blue", "", Color(0.1, 0.18, 0.45), 0.6, 1.0)
	_std("toy_yellow", "", Color(0.7, 0.55, 0.12), 0.6, 1.0)
	# --- monstre
	_std("skin", "skin", Color(0.46, 0.47, 0.43), 0.55, 4.0, 0.4)
	_std("skin_dark", "skin", Color(0.22, 0.22, 0.21), 0.7, 4.0, 0.3)
	_std("cloth_black", "fabric", Color(0.07, 0.065, 0.06), 0.95, 4.0, 0.2)
	_std("teeth", "", Color(0.75, 0.7, 0.55), 0.35, 1.0, 0.6)
	_std("mouth", "", Color(0.06, 0.005, 0.005), 0.85, 1.0, 0.2)
	var eye_white := _unshaded("eye_white", "", Color(0.62, 0.56, 0.42))
	eye_white.albedo_color = Color(0.62, 0.56, 0.42)
	_unshaded("eye_glow", "", Color(1.0, 0.92, 0.62))
	# --- effets / transparents
	var glass := _unshaded("glass_window", "window_night", Color(0.55, 0.6, 0.75))
	glass.albedo_color = Color(0.55, 0.6, 0.75)
	var stained := _unshaded("glass_stained", "stained_glass", Color(0.5, 0.5, 0.5))
	stained.albedo_color = Color(0.5, 0.5, 0.5)
	var flame := _unshaded("flame", "flame", Color(1.0, 0.8, 0.55))
	flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	flame.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flame_p := _unshaded("flame_particle", "flame", Color(1.0, 0.6, 0.3))
	flame_p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_p.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_p.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_p.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bulb := _unshaded("bulb", "", Color(1.0, 0.85, 0.6))
	bulb.albedo_color = Color(1.0, 0.85, 0.6)
	var halo := _unshaded("halo", "glow", Color(1.0, 0.75, 0.45, 0.35))
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.vertex_color_use_as_albedo = false
	var shaft := _unshaded("moon_shaft", "", Color(0.35, 0.45, 0.7, 1.0))
	shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var pool := _unshaded("moon_pool", "window_pane", Color(0.3, 0.4, 0.65, 0.5))
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool.vertex_color_use_as_albedo = false
	var web := _std("cobweb", "cobweb", Color(0.9, 0.9, 0.88), 1.0, 1.0, 0.1)
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	web.alpha_scissor_threshold = 0.4
	web.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Poussière éclairée (visible seulement dans le faisceau de la lampe).
	var dust := _std("dust", "glow", Color(1.0, 0.97, 0.9, 0.55), 1.0, 1.0, 0.0)
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust.vertex_color_use_as_albedo = false
	dust.disable_receive_shadows = true
	var mirror := _std("mirror", "", Color(0.05, 0.06, 0.07, 0.82), 0.05, 1.0, 1.0)
	mirror.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mirror.metallic = 0.3
	var ember := _unshaded("ember", "", Color(1.0, 0.35, 0.08))
	ember.albedo_color = Color(1.0, 0.35, 0.08)
	_build_aliases()
