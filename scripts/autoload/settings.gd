extends Node
## Réglages du joueur (graphismes, audio, contrôles), sauvegardés dans user://settings.cfg.
## Les autres systèmes écoutent `settings_changed` pour se mettre à jour.

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"

enum Quality { LOW, MEDIUM, HIGH }

# --- Graphismes ---
var render_scale: float = 0.75
var shadows: bool = true
var quality: int = Quality.MEDIUM
var fullscreen: bool = false
var vsync: bool = true
var max_fps: int = 60
var brightness: float = 1.0
var show_fps: bool = false
var fov: float = 75.0
var head_bob: bool = true
# --- Contrôles ---
var mouse_sensitivity: float = 0.12
var invert_y: bool = false
# --- Audio (0..1) ---
var vol_master: float = 0.9
var vol_music: float = 0.75
var vol_sfx: float = 0.9


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.4, 1.0)
	shadows = bool(cfg.get_value("video", "shadows", shadows))
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 2)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	brightness = clampf(float(cfg.get_value("video", "brightness", brightness)), 0.5, 2.0)
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	fov = clampf(float(cfg.get_value("video", "fov", fov)), 60.0, 95.0)
	head_bob = bool(cfg.get_value("video", "head_bob", head_bob))
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.02, 0.6)
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	vol_master = clampf(float(cfg.get_value("audio", "master", vol_master)), 0.0, 1.0)
	vol_music = clampf(float(cfg.get_value("audio", "music", vol_music)), 0.0, 1.0)
	vol_sfx = clampf(float(cfg.get_value("audio", "sfx", vol_sfx)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "head_bob", head_bob)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("audio", "master", vol_master)
	cfg.set_value("audio", "music", vol_music)
	cfg.set_value("audio", "sfx", vol_sfx)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Impossible d'enregistrer les réglages (%d)." % err)


## Applique tous les réglages et prévient les autres systèmes.
func apply_all() -> void:
	apply_video()
	settings_changed.emit()


func apply_video() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale
	vp.use_occlusion_culling = quality >= Quality.MEDIUM
	vp.positional_shadow_atlas_size = 1024 if quality == Quality.LOW else 2048
	if not _is_headless():
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps


## Nombre de lumières dynamiques (sans ombres) actives en même temps autour du joueur.
func max_active_lights() -> int:
	match quality:
		Quality.LOW:
			return 4
		Quality.HIGH:
			return 8
	return 6


func light_cull_radius() -> float:
	match quality:
		Quality.LOW:
			return 14.0
		Quality.HIGH:
			return 24.0
	return 18.0


func camera_far() -> float:
	match quality:
		Quality.LOW:
			return 32.0
		Quality.HIGH:
			return 60.0
	return 45.0


func dust_amount() -> int:
	match quality:
		Quality.LOW:
			return 0
		Quality.HIGH:
			return 90
	return 45


func linear_to_db_safe(v: float) -> float:
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
