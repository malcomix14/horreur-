class_name GameWorld
extends Node3D
## Monde de jeu : construit le manoir, le navmesh, le joueur, le Veilleur, les systèmes
## (lumières, screamers, ambiance), gère l'environnement, les points de sauvegarde,
## l'éveil du monstre et la cinématique de fin.

const AMBIENT_COLOR: Color = Color(0.5, 0.55, 0.72)
const AMBIENT_ENERGY: float = 0.92
const FOG_COLOR: Color = Color(0.1, 0.11, 0.14)
const MOON_FILL_ENERGY: float = 0.3

var layout: ManorLayout
var builder: ManorBuilder
var nav_region: NavigationRegion3D
var player: Player
var monster: Monster
var lights: LightManager
var scares: JumpscareManager
var ambience: AmbienceDirector
var env: Environment
var anchors: Dictionary = {}
var exterior_light: OmniLight3D
var moon_fill: DirectionalLight3D
var dust: CPUParticles3D
var ready_to_play: bool = false

var _save: Dictionary = {}
var _awaken_timer: float = -1.0
var _no_lamp_timer: float = 0.0
var _ending: bool = false
var _base_ambient: float = AMBIENT_ENERGY
var _env_tween: Tween


func build(save: Dictionary, progress: Callable) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_save = save
	layout = ManorLayout.new()
	_build_environment()
	lights = LightManager.new()
	lights.name = "LightManager"
	lights.layout = layout
	add_child(lights)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Level"
	var nm := NavigationMesh.new()
	nm.cell_size = 0.2
	nm.cell_height = 0.1
	nm.agent_radius = 0.4
	nm.agent_height = 2.2
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD | Layers.NAV_BLOCK
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	_progress(progress, 0.05, "Construction des murs…")
	await get_tree().process_frame
	builder = ManorBuilder.new(layout, nav_region)
	builder.build_structure()
	_progress(progress, 0.25, "Aménagement du manoir…")
	await get_tree().process_frame
	var content := ManorContent.new(self, builder)
	await content.populate(progress)
	builder.finalize()
	_progress(progress, 0.75, "Le Veilleur apprend les couloirs…")
	await get_tree().process_frame
	nav_region.bake_navigation_mesh(false)
	await _wait_navigation_ready()
	_spawn_player()
	_spawn_monster()
	lights.player = player
	lights.init_power_state()
	lights.refresh_now()
	scares = JumpscareManager.new()
	scares.name = "Jumpscares"
	scares.world = self
	add_child(scares)
	ambience = AmbienceDirector.new()
	ambience.name = "Ambience"
	ambience.world = self
	add_child(ambience)
	_setup_dust()
	Events.checkpoint_requested.connect(save_checkpoint)
	Events.secret_opened.connect(_on_secret_opened)
	Events.lightning_flash.connect(_on_lightning)
	Events.ending_started.connect(_on_ending_started)
	GameManager.inventory_changed.connect(_update_objective)
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()
	_progress(progress, 1.0, "Prêt.")
	await get_tree().process_frame
	ready_to_play = true


## Attend que la carte de navigation soit réellement synchronisée
## (Godot 4.5+ la met à jour de façon asynchrone).
func _wait_navigation_ready() -> void:
	var map := get_world_3d().navigation_map
	var probe := Vector3(6.0, 0.0, 17.0)
	for i: int in range(300):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var cp := NavigationServer3D.map_get_closest_point(map, probe)
			if cp.distance_to(probe) < 2.0:
				return
	push_warning("La carte de navigation n'a pas pu être synchronisée à temps.")


func _progress(progress: Callable, ratio: float, text: String) -> void:
	if progress.is_valid():
		progress.call(ratio, text)


# ============================================================ environnement

## Éclairage de base « sombre mais lisible » : une lumière ambiante froide faible mais présente
## partout (aucune zone totalement noire), un clair de lune diffus directionnel sans ombre
## (les murs, sols et meubles se distinguent par leur orientation) et un brouillard bleuté qui
## détache les silhouettes au loin. Les lampes du manoir (FlickerLight) créent les zones chaudes.
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = _base_ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	moon_fill = DirectionalLight3D.new()
	moon_fill.name = "MoonFill"
	moon_fill.light_color = Color(0.62, 0.7, 1.0)
	moon_fill.light_energy = MOON_FILL_ENERGY
	moon_fill.light_specular = 0.0
	moon_fill.shadow_enabled = false
	moon_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon_fill.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(32.0), 0.0)
	add_child(moon_fill)


func _apply_settings() -> void:
	var br := Settings.brightness
	_base_ambient = AMBIENT_ENERGY * br
	env.ambient_light_energy = _base_ambient
	env.fog_light_color = FOG_COLOR * lerpf(0.7, 1.4, clampf((br - 0.5) / 1.5, 0.0, 1.0))
	env.tonemap_exposure = lerpf(0.85, 1.35, clampf((br - 0.5) / 1.5, 0.0, 1.0))
	if moon_fill != null:
		moon_fill.light_energy = MOON_FILL_ENERGY * br
	match Settings.quality:
		Settings.Quality.LOW:
			env.fog_density = 0.05
		Settings.Quality.HIGH:
			env.fog_density = 0.032
		_:
			env.fog_density = 0.038
	if dust != null:
		var amount := Settings.dust_amount()
		dust.visible = amount > 0
		if amount > 0 and dust.amount != amount:
			dust.amount = amount


func _setup_dust() -> void:
	dust = CPUParticles3D.new()
	dust.amount = maxi(1, Settings.dust_amount())
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(4.5, 1.6, 4.5)
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	dust.gravity = Vector3(0, -0.01, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.06
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.014)
	q.material = Assets.mat("dust")
	dust.mesh = q
	add_child(dust)
	dust.visible = Settings.dust_amount() > 0


func _on_lightning(strength: float) -> void:
	if _env_tween != null and _env_tween.is_valid():
		_env_tween.kill()
	_env_tween = create_tween()
	var peak := _base_ambient * (1.0 + 2.2 * strength)
	_env_tween.tween_property(env, "ambient_light_energy", peak, 0.05)
	_env_tween.tween_property(env, "ambient_light_energy", _base_ambient * 1.3, 0.12)
	_env_tween.tween_property(env, "ambient_light_energy", peak * 0.8, 0.06)
	_env_tween.tween_property(env, "ambient_light_energy", _base_ambient, 0.6)


## Assombrit brièvement l'ambiance (coupures de courant des screamers) sans jamais aller
## jusqu'au noir total, puis revient progressivement à la normale.
func dim_ambient(factor: float, duration: float) -> void:
	if _env_tween != null and _env_tween.is_valid():
		_env_tween.kill()
	_env_tween = create_tween()
	_env_tween.tween_property(env, "ambient_light_energy", _base_ambient * factor, 0.12)
	_env_tween.tween_interval(maxf(0.0, duration - 0.9))
	_env_tween.tween_property(env, "ambient_light_energy", _base_ambient, 0.8)
	var moon_target := MOON_FILL_ENERGY * Settings.brightness
	var mt := create_tween()
	mt.tween_property(moon_fill, "light_energy", moon_target * factor, 0.12)
	mt.tween_interval(maxf(0.0, duration - 0.9))
	mt.tween_property(moon_fill, "light_energy", moon_target, 0.8)


# ============================================================ joueur et monstre

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.surface_at = surface_at
	var pos := Vector3(9.3, 0.05, 19.3)
	var yaw := 0.96
	var pp: Variant = _save.get("player_pos", null)
	if pp is Array and (pp as Array).size() == 3:
		var a: Array = pp
		pos = Vector3(float(a[0]), float(a[1]) + 0.05, float(a[2]))
		yaw = float(_save.get("player_yaw", 0.0))
		player.flashlight.charge = float(_save.get("flashlight_charge", 75.0))
	player.global_position = pos
	player.set_view(yaw, 0.0)


func _spawn_monster() -> void:
	monster = Monster.new()
	monster.name = "Veilleur"
	add_child(monster)
	monster.player = player
	var map := get_world_3d().navigation_map
	var pts: Array[Vector3] = []
	for p: Vector3 in layout.patrol_points:
		pts.append(NavigationServer3D.map_get_closest_point(map, p))
	monster.patrol_points = pts
	monster.nav_ready = true
	anchors["monster_spawn"] = NavigationServer3D.map_get_closest_point(map, Vector3(23.0, 0.0, 6.5))
	if GameManager.get_flag("monster_awake"):
		monster.activate(monster.pick_far_spawn(player.global_position))


func _process(delta: float) -> void:
	if not ready_to_play:
		return
	if dust != null and player != null:
		dust.global_position = player.global_position + Vector3(0, 1.4, 0)
	if not GameManager.is_playing() or _ending:
		return
	if not monster.is_active():
		if GameManager.has_item("flashlight"):
			if _awaken_timer < 0.0:
				_awaken_timer = 22.0
			_awaken_timer -= delta
			if _awaken_timer <= 0.0:
				awaken_monster()
		else:
			_no_lamp_timer += delta
			if _no_lamp_timer > 150.0:
				awaken_monster()


func awaken_monster() -> void:
	if monster.is_active():
		return
	GameManager.set_flag("monster_awake")
	var spawn: Vector3 = anchors.get("monster_spawn", Vector3(23, 0, 6.5))
	if spawn.distance_to(player.global_position) < 18.0:
		spawn = monster.pick_far_spawn(player.global_position)
	monster.activate(spawn)
	AudioManager.play_3d("door_slam", spawn + Vector3(0, 1.5, 0), 8.0, 0.8, 70.0, 10.0)
	var _delay_tw5 := create_tween()
	_delay_tw5.tween_interval(1.4)
	_delay_tw5.tween_callback(func() -> void:
		AudioManager.play_3d("monster_scream", spawn + Vector3(0, 2.0, 0), 4.0, 0.85, 80.0, 10.0)
		Events.camera_shake.emit(0.2))
	Events.message_requested.emit("Une porte a claqué, quelque part au nord. Je ne suis pas seul.", 4.5)
	Events.monster_awakened.emit()
	_update_objective()


func surface_at(pos: Vector3) -> String:
	var r := layout.room_at(pos)
	if r == null:
		return "wood"
	if r.style in ["cellar", "kitchen", "bath", "chapel", "hall"]:
		return "stone"
	return "wood"


func zone_at(pos: Vector3) -> String:
	var r := layout.room_at(pos)
	if r == null:
		return "corridor"
	return r.zone


func room_label_at(pos: Vector3) -> String:
	var r := layout.room_at(pos)
	return r.label if r != null else ""


# ============================================================ objectifs et sauvegarde

func _update_objective() -> void:
	if _ending:
		return
	var n := GameManager.key_count()
	if not GameManager.has_item("flashlight") and n == 0:
		GameManager.set_objective("Trouver de la lumière.")
		return
	if n >= 4:
		var extra := ""
		if GameManager.has_item("register") and not GameManager.get_flag("register_burned"):
			extra = " (Le registre... et si je le brûlais d'abord ?)"
		GameManager.set_objective("Les quatre clés sont réunies. Ouvrir la grande porte du hall." + extra)
		return
	if GameManager.get_flag("tried_main_door") or n > 0:
		GameManager.set_objective("Trouver les quatre clés de la grande porte (%d/4)." % n)
		return
	GameManager.set_objective("Explorer le manoir et trouver une sortie.")


func save_checkpoint() -> void:
	if _ending or player == null or player.caught:
		return
	var d := GameManager.serialize()
	var pos := player.global_position
	if player.is_hidden and player.hidden_in != null:
		pos = player.hidden_in.exit_global()
	d["player_pos"] = [pos.x, pos.y, pos.z]
	d["player_yaw"] = player.yaw
	d["flashlight_charge"] = player.flashlight.charge
	if SaveSystem.write_save(d):
		Events.checkpoint_saved.emit()


func _on_secret_opened() -> void:
	nav_region.bake_navigation_mesh(true)
	await nav_region.bake_finished
	# Le monstre reprend ses chemins avec le nouveau navmesh.
	if monster != null:
		monster.refresh_path()


# ============================================================ intro et fin

## Réveil du joueur au sol de la salle à manger.
func play_intro() -> void:
	GameManager.set_phase(GameManager.Phase.CUTSCENE)
	player.cinematic = true
	player.eye_height = 0.3
	player.cam_pivot.rotation.z = 0.9
	player.set_view(player.yaw, -0.4)
	Events.screen_fade.emit(1.0, 0.0)
	Events.subtitle_requested.emit("Manoir Vespérine — Morvan, novembre 1954", 5.0)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: Events.screen_fade.emit(0.0, 3.0))
	tw.tween_property(player, "eye_height", 0.9, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(player, "eye_height", Player.EYE_STAND, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		player.cinematic = false
		GameManager.set_phase(GameManager.Phase.PLAYING)
		Events.message_requested.emit("Ma tête... La porte d'entrée s'est refermée derrière moi. Puis plus rien.", 5.0)
		_update_objective())


func _on_ending_started(ending: String) -> void:
	_ending = true
	GameManager.set_phase(GameManager.Phase.CUTSCENE)
	monster.set_physics_process(false)
	if exterior_light != null:
		exterior_light.visible = true
	player.cinematic = true
	var out: Vector3 = anchors.get("exit_outside", Vector3(22, 0, 35))
	var start_yaw := player.yaw
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void: player.set_view(lerp_angle(start_yaw, PI, v), lerpf(player.pitch, 0.0, v)), 0.0, 1.0, 1.2)
	tw.chain().tween_property(player, "global_position", Vector3(22, 0.05, 29.0), 1.6).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(player, "global_position", out, 3.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_callback(func() -> void: Events.screen_fade.emit(1.0, 3.0)).set_delay(1.2)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_callback(func() -> void:
		SaveSystem.erase_save()
		Events.victory.emit(ending))
