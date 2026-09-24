class_name AutoTest
extends Node
## Test automatique (développement) : lancer avec
##   godot --path . --fixed-fps 60 -- --autotest [--shots=/chemin/dossier]
## Il joue une partie complète par code (énigmes, monstre, cachettes, screamers,
## sauvegarde, fins) et affiche un rapport. N'est jamais utilisé en jeu normal.

var main: MainController
var _fails: int = 0
var _checks: int = 0
var _shots_dir: String = ""
var _died: bool = false
var _victory: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	Events.player_died.connect(func() -> void: _died = true)
	Events.victory.connect(func(e: String) -> void: _victory = e)
	_run()


func _log(t: String) -> void:
	print("[AUTOTEST] ", t)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		_log("OK   " + what)
	else:
		_fails += 1
		_log("FAIL " + what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame


func _world() -> GameWorld:
	return main.world


func _shot(shot_name: String) -> void:
	if _shots_dir == "":
		return
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_shots_dir, shot_name])
		var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		_log("capture %s  (appels de dessin : %d, triangles : %d, objets : %d)" % [shot_name, int(dc), int(prims), int(objs)])


func _find_all(root: Node, script_class: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var sc := n.get_script() as Script
		if sc != null and sc.get_global_name() == script_class:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _find_all_class(root: Node, native_class: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_class() == native_class:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _find_one(root: Node, script_class: String) -> Node:
	var l := _find_all(root, script_class)
	return l[0] if not l.is_empty() else null


func _place_player(pos: Vector3, yaw: float, pitch: float = 0.0) -> void:
	var p := _world().player
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set_view(yaw, pitch)


func _look_at_yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


# ============================================================ scénario

func _run() -> void:
	_log("=== DÉBUT DU TEST AUTOMATIQUE ===")
	_compile_all("res://scripts")
	SaveSystem.erase_save()
	# ---- menu principal
	main.show_menu()
	await _frames(5)
	await _shot("00_menu")
	# ---- nouvelle partie
	GameManager.new_game()
	var t0 := Time.get_ticks_msec()
	await main._start_world({}, false)
	_log("Monde construit en %d ms" % (Time.get_ticks_msec() - t0))
	var w := _world()
	_check(w != null and w.ready_to_play, "le monde est construit")
	_check(GameManager.is_playing(), "phase = PLAYING")
	_test_navigation(w)
	if OS.get_cmdline_user_args().has("--perf"):
		await _perf(w)
		main.quit_game(0)
		return
	if OS.get_cmdline_user_args().has("--navonly"):
		_log("=== RÉSULTAT : %d vérifications, %d échec(s) ===" % [_checks, _fails])
		main.quit_game(0 if _fails == 0 else 1)
		return
	await _screens_tour(w)
	await _test_puzzles(w)
	await _test_monster(w)
	await _test_scares()
	_test_save_load()
	await _test_ui()
	await _test_ending()
	_log("=== RÉSULTAT : %d vérifications, %d échec(s) ===" % [_checks, _fails])
	main.quit_game(0 if _fails == 0 else 1)


func _stats() -> String:
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return "appels %4d  objets %4d  triangles %6d" % [int(dc), int(objs), int(prims)]


## Mesures de rendu selon les réglages (développement).
func _perf(w: GameWorld) -> void:
	w.monster.set_physics_process(false)
	var flashlight: Pickup = null
	for n: Node in _find_all(w, "Pickup"):
		if (n as Pickup).item_id == "flashlight":
			flashlight = n as Pickup
	flashlight.interact(w.player)
	w.player.flashlight.set_on(true)
	var views: Array = [
		["galerie", Vector3(2.0, 0.05, 10.5), -PI * 0.5, -0.05],
		["hall", Vector3(22.0, 0.05, 28.5), 0.0, 0.12],
		["salle_a_manger", Vector3(9.3, 0.05, 19.3), 0.96, -0.1],
		["bibliotheque", Vector3(4.5, 0.05, 7.8), 0.0, -0.05],
	]
	var cfgs: Array = [["base", true, 45.0, true], ["sans_occlusion", false, 45.0, true], ["far_30", true, 30.0, true], ["sans_ombres", true, 45.0, false]]
	var total_mi := 0
	var total_surf := 0
	var room_surf := 0
	for n: Node in _find_all_class(w, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		total_mi += 1
		total_surf += mi.mesh.get_surface_count()
		if mi.name == "Mesh" and mi.get_parent().name.begins_with("Room_"):
			room_surf += mi.mesh.get_surface_count()
	_log("PERF scène : %d MeshInstance3D, %d surfaces (dont %d dans les 17 pièces)" % [total_mi, total_surf, room_surf])
	for v: Variant in views:
		var arr: Array = v
		_place_player(arr[1] as Vector3, float(arr[2]), float(arr[3]))
		for n2: Node in _find_all_class(w, "MeshInstance3D"):
			var mi2 := n2 as MeshInstance3D
			if not (mi2.name == "Mesh" and mi2.get_parent().name.begins_with("Room_")):
				mi2.set_meta("was_visible", mi2.visible)
				mi2.visible = false
		w.player.flashlight.light.shadow_enabled = false
		await _frames(6)
		_log("PERF %-15s %-15s %s" % [str(arr[0]), "pieces_seules", _stats()])
		for n3: Node in _find_all_class(w, "MeshInstance3D"):
			var mi3 := n3 as MeshInstance3D
			if mi3.has_meta("was_visible"):
				mi3.visible = bool(mi3.get_meta("was_visible"))
		for c: Variant in cfgs:
			var cf: Array = c
			get_viewport().use_occlusion_culling = bool(cf[1])
			w.player.camera.far = float(cf[2])
			w.player.flashlight.light.shadow_enabled = bool(cf[3])
			await _frames(6)
			_log("PERF %-15s %-15s %s" % [str(arr[0]), str(cf[0]), _stats()])


func _compile_all(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var path := dir + "/" + f
		if d.current_is_dir():
			_compile_all(path)
		elif f.ends_with(".gd"):
			var s := load(path) as Script
			_check(s != null and s.can_instantiate(), "script compile : " + path)
		f = d.get_next()


func _test_navigation(w: GameWorld) -> void:
	var map := w.get_world_3d().navigation_map
	_check(NavigationServer3D.map_get_iteration_id(map) > 0, "carte de navigation synchronisée")
	var start := NavigationServer3D.map_get_closest_point(map, Vector3(8, 0, 19))
	var bad := 0
	for p: Vector3 in w.monster.patrol_points:
		var path := NavigationServer3D.map_get_path(map, start, p, true)
		if path.is_empty() or path[path.size() - 1].distance_to(p) > 1.0:
			bad += 1
			_log("  point de patrouille inaccessible : %s" % str(p))
	_check(bad == 0, "tous les points de patrouille sont accessibles (%d)" % w.monster.patrol_points.size())
	var cellar := NavigationServer3D.map_get_path(map, start, Vector3(6, -3.6, 17), true)
	if cellar.is_empty() or cellar[cellar.size() - 1].distance_to(Vector3(6, -3.6, 17)) > 1.5:
		_log("  chemin cave : %s" % str(cellar))
		for probe: Vector3 in [Vector3(4.5, 0, 29), Vector3(6, -0.6, 29), Vector3(8, -1.8, 29), Vector3(10, -3.0, 29), Vector3(11, -3.6, 27.5), Vector3(6, -3.6, 25)]:
			_log("  sonde %s -> %s" % [str(probe), str(NavigationServer3D.map_get_closest_point(map, probe))])
	_check(not cellar.is_empty() and cellar[cellar.size() - 1].distance_to(Vector3(6, -3.6, 17)) < 1.5, "la cave est accessible par l'escalier")
	var secret := NavigationServer3D.map_get_path(map, start, Vector3(10.5, 0, 5.0), true)
	var reach_secret := not secret.is_empty() and secret[secret.size() - 1].distance_to(Vector3(10.5, 0, 5.0)) < 1.0
	if reach_secret:
		_log("  chemin vers le cabinet : %s" % str(secret))
	_check(not reach_secret, "le cabinet secret est fermé au monstre avant ouverture")


func _screens_tour(w: GameWorld) -> void:
	var p := w.player
	# Réveil : lampe éteinte, candélabre seul.
	_place_player(Vector3(9.3, 0.05, 19.3), 0.96, -0.1)
	await _wait(0.6)
	await _shot("01_depart_salle_a_manger")
	var lamp := _find_one(w, "Pickup")
	var flashlight: Pickup = null
	for n: Node in _find_all(w, "Pickup"):
		if (n as Pickup).item_id == "flashlight":
			flashlight = n as Pickup
	_check(lamp != null and flashlight != null, "la lampe torche est présente")
	if flashlight != null:
		flashlight.interact(p)
	_check(GameManager.has_item("flashlight"), "lampe ramassée")
	p.flashlight.set_on(true)
	_check(p.flashlight.is_on, "lampe allumée")
	var views: Array = [
		["02_galerie", Vector3(2.0, 0.05, 10.5), -PI * 0.5, -0.05],
		["03_hall", Vector3(22.0, 0.05, 28.5), 0.0, 0.12],
		["04_hall_escalier", Vector3(17.0, 0.05, 24.0), -0.6, 0.15],
		["05_bibliotheque", Vector3(4.5, 0.05, 7.8), 0.0, -0.05],
		["06_chapelle", Vector3(23.0, 0.05, 8.0), 0.0, 0.05],
		["07_cuisine", Vector3(2.0, 0.05, 23.5), -2.4, -0.15],
		["08_cave", Vector3(10.8, -3.55, 27.5), 0.6, -0.05],
		["09_chambre", Vector3(30.5, 0.05, 7.5), 0.8, -0.1],
		["10_salon", Vector3(34.0, 0.05, 20.5), -2.1, -0.05],
		["11_chambre_lise", Vector3(33.2, 0.05, 25.0), -2.3, -0.2],
		["12_salle_de_bain", Vector3(39.0, 0.05, 7.5), -2.2, -0.05],
	]
	for v: Variant in views:
		var arr: Array = v
		_place_player(arr[1] as Vector3, float(arr[2]), float(arr[3]))
		await _wait(0.35)
		await _shot(str(arr[0]))
	# Mesure : même vue sans l'ombre de la lampe, puis avec le préréglage « PC faible ».
	Settings.shadows = false
	Settings.apply_all()
	_place_player(Vector3(2.0, 0.05, 10.5), -PI * 0.5, -0.05)
	await _wait(0.35)
	await _shot("02b_galerie_sans_ombres")
	Settings.quality = Settings.Quality.LOW
	Settings.render_scale = 0.6
	Settings.apply_all()
	await _wait(0.35)
	await _shot("02c_galerie_pc_faible")
	Settings.quality = Settings.Quality.MEDIUM
	Settings.render_scale = 0.75
	Settings.shadows = true
	Settings.apply_all()
	p.flashlight.charge = 100.0


func _interact_all(w: GameWorld, script_class: String, filter: Callable) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in _find_all(w, script_class):
		if filter.call(n):
			out.append(n)
	return out


func _pickup_item(w: GameWorld, item: String) -> bool:
	for n: Node in _find_all(w, "Pickup"):
		var pk := n as Pickup
		if pk.item_id == item and pk.active and pk.is_inside_tree() and not pk.is_queued_for_deletion():
			pk.interact(w.player)
			return true
	return false


func _test_puzzles(w: GameWorld) -> void:
	var p := w.player
	# Réveil du monstre (sera testé plus tard) : on le garde endormi pour les énigmes.
	w.monster.set_physics_process(false)
	# Portes.
	var doors := _find_all(w, "Door")
	_check(doors.size() >= 14, "portes créées (%d)" % doors.size())
	var d0 := doors[0] as Door
	d0.interact(p)
	await _wait(0.9)
	_check(d0.is_open, "une porte s'ouvre")
	d0.interact(p)
	await _wait(0.9)
	_check(not d0.is_open, "une porte se ferme")
	# Document.
	var letter: NoteItem = null
	for n: Node in _find_all(w, "NoteItem"):
		if (n as NoteItem).note_id == "lettre_notaire":
			letter = n as NoteItem
	if letter != null:
		letter.interact(p)
		await _frames(3)
		_check(main.notes.visible, "la lettre s'affiche")
		await _shot("13_lecture_note")
		main.notes.close()
		await _frames(3)
		_check(GameManager.is_playing() and not get_tree().paused, "retour au jeu après lecture")
	_check(GameManager.notes_read.size() == 14 or GameManager.notes_db.size() == 14, "14 documents définis (%d)" % GameManager.notes_db.size())
	# Tiroirs de la cuisine : allumettes + main.
	var drawers := _find_all(w, "Drawer")
	_check(drawers.size() >= 5, "tiroirs créés (%d)" % drawers.size())
	for n: Node in drawers:
		var dr := n as Drawer
		dr.interact(p)
	await _wait(0.6)
	_check(_pickup_item(w, "matches"), "allumettes ramassées dans un tiroir")
	_check(_pickup_item(w, "fuse"), "fusible ramassé dans la table de chevet")
	for n: Node in drawers:
		(n as Drawer).interact(p)
	# Fusible -> boîtier -> monte-charge -> clé de fer.
	var fb := _find_one(w, "FuseBox") as FuseBox
	fb.interact(p)
	_check(GameManager.get_flag("power_on"), "courant rétabli")
	var dw := _find_one(w, "Dumbwaiter") as Dumbwaiter
	dw.interact(p)
	await _wait(4.5)
	_check(GameManager.get_flag("dumbwaiter_down"), "monte-charge descendu")
	_place_player(Vector3(10.6, -3.55, 23.2), -PI * 0.5 + PI, 0.0)
	await _wait(0.3)
	await _shot("14_monte_charge")
	_check(_pickup_item(w, "key_iron"), "clé de fer ramassée")
	# Coffre : mauvais code puis bon code.
	var safe := _find_one(w, "Safe") as Safe
	_check(not safe.try_code("0000"), "mauvais code refusé")
	_check(safe.try_code("1403"), "code 1403 accepté")
	await _wait(1.8)
	var ok_silver := _pickup_item(w, "key_silver")
	_check(ok_silver, "clé d'argent ramassée")
	await _wait(4.5)
	# Boîte à musique.
	_check(_pickup_item(w, "crank"), "manivelle ramassée")
	var mb := _find_one(w, "MusicBox") as MusicBox
	mb.interact(p)
	_check(not GameManager.has_item("crank"), "manivelle utilisée")
	await _wait(MusicBox.PLAY_TIME + 0.8)
	_check(GameManager.get_flag("musicbox_done"), "la boîte à musique a fini de jouer")
	_check(_pickup_item(w, "key_brass"), "clé de laiton ramassée")
	# Cierges : mauvais ordre puis bon ordre.
	var puzzle := _find_one(w, "CandlePuzzle") as CandlePuzzle
	var by_role: Dictionary = {}
	for c: Candle in puzzle.candles:
		by_role[c.role] = c
	(by_role["enfant"] as Candle).interact(p)
	await _wait(1.4)
	_check(not (by_role["enfant"] as Candle).lit, "mauvais ordre : les cierges s'éteignent")
	for role: String in ["pere", "mere", "enfant"]:
		(by_role[role] as Candle).interact(p)
		await _wait(0.2)
	await _wait(2.6)
	_check(puzzle.solved and GameManager.get_flag("candles_done"), "énigme des cierges résolue")
	_place_player(Vector3(23.0, 0.05, 5.5), 0.0, -0.2)
	await _wait(0.3)
	await _shot("15_chapelle_cierges")
	_check(_pickup_item(w, "key_bone"), "clé d'os ramassée")
	_check(GameManager.key_count() == 4, "quatre clés en main")
	# Livre rouge -> cabinet secret -> registre.
	var red: ExamineProp = null
	for n: Node in _find_all(w, "ExamineProp"):
		if (n as ExamineProp).prompt == "Tirer le livre rouge":
			red = n as ExamineProp
	_check(red != null, "livre rouge présent")
	if red != null:
		red.interact(p)
	await _wait(6.0)
	_check(GameManager.get_flag("secret_open"), "cabinet secret ouvert")
	var map := w.get_world_3d().navigation_map
	var start := NavigationServer3D.map_get_closest_point(map, Vector3(8, 0, 19))
	var secret := NavigationServer3D.map_get_path(map, start, Vector3(10.5, 0, 5.0), true)
	_check(not secret.is_empty() and secret[secret.size() - 1].distance_to(Vector3(10.5, 0, 5.0)) < 1.0, "navmesh recalculé : cabinet accessible")
	_place_player(Vector3(8.0, 0.05, 4.5), PI * 0.5 + PI, 0.0)
	await _wait(0.3)
	await _shot("16_cabinet_secret")
	_check(_pickup_item(w, "register"), "registre ramassé")
	var fp := _find_one(w, "Fireplace") as Fireplace
	fp.interact(p)
	_check(GameManager.get_flag("register_burned"), "registre brûlé dans la cheminée")
	_place_player(Vector3(40.0, 0.05, 17.0), -PI * 0.5, -0.1)
	await _wait(0.5)
	await _shot("17_cheminee")
	_check(_pickup_item(w, "battery"), "pile ramassée")
	p.flashlight.charge = 30.0
	p.flashlight.use_battery()
	_check(p.flashlight.charge > 99.0, "pile remplacée")
	w.monster.set_physics_process(true)


func _test_monster(w: GameWorld) -> void:
	var p := w.player
	var m := w.monster
	w.awaken_monster()
	_check(m.is_active(), "le Veilleur est éveillé")
	# Portrait du monstre pour contrôle visuel.
	m.global_position = Vector3(22.0, 0.0, 10.5)
	_place_player(Vector3(26.0, 0.05, 10.5), PI * 0.5, 0.05)
	m.set_physics_process(false)
	m.body.rotation.y = -PI * 0.5
	m.body.pose = MonsterBody.Pose.IDLE
	await _wait(0.6)
	await _shot("18_veilleur_galerie")
	_place_player(Vector3(23.4, 0.05, 10.5), PI * 0.5, 0.35)
	await _wait(0.3)
	await _shot("19_veilleur_visage")
	m.body.pose = MonsterBody.Pose.WALK
	m.body.speed = 4.0
	await _wait(0.4)
	await _shot("20_veilleur_course")
	m.set_physics_process(true)
	# 1) Poursuite puis capture : le joueur reste immobile dans la galerie.
	_died = false
	GameManager.set_flag("register_burned", false)
	m.enraged = false
	m.global_position = Vector3(10.0, 0.0, 10.5)
	m.body.rotation.y = -PI * 0.5
	_place_player(Vector3(18.0, 0.05, 10.5), PI * 0.5, 0.0)
	p.flashlight.set_on(true)
	var chased := false
	for i: int in range(200):
		await _frames(3)
		if m.state == Monster.State.CHASE:
			chased = true
		if _died:
			break
	_check(chased, "le Veilleur repère le joueur et le poursuit")
	await _wait(0.2)
	_check(_died, "capture => mort (écran de mort)")
	await _shot("21_capture")
	await _wait(1.2)
	await _shot("22_ecran_mort")
	# Relance depuis la sauvegarde.
	Events.checkpoint_requested.emit()
	await main.continue_game()
	w = _world()
	p = w.player
	m = w.monster
	_check(w != null and GameManager.is_playing(), "reprise au point de sauvegarde")
	_check(GameManager.key_count() == 4, "clés conservées après reprise")
	_died = false
	# 2) Cachette sans être vu : le monstre fouille mais ne trouve pas.
	var spot: HidingSpot = null
	for n: Node in get_tree().get_nodes_in_group("hiding_spots"):
		var hs := n as HidingSpot
		if hs.kind == "wardrobe" and hs.global_position.distance_to(Vector3(36.5, 0, 9.4)) < 1.0:
			spot = hs
	_check(spot != null, "armoire de la galerie trouvée")
	if spot != null:
		_place_player(spot.exit_global() + Vector3(0, 0.05, 0), 0.0)
		p.enter_hiding(spot)
		await _wait(0.8)
		_check(p.is_hidden, "le joueur est caché")
		await _shot("23_vue_cachette")
		m.global_position = Vector3(28.0, 0.0, 10.5)
		m._start_search(spot.global_position + Vector3(0, 0, 1.2), 3)
		await _wait(14.0)
		_check(not _died and not p.caught, "caché hors de sa vue : non trouvé")
		p.exit_hiding()
		await _wait(0.8)
		_check(not p.is_hidden, "sortie de cachette")
		# 3) Vu en train de se cacher : il vient le chercher.
		_died = false
		m.global_position = Vector3(31.0, 0.0, 10.5)
		m.body.rotation.y = -PI * 0.5
		m._start_chase()
		m.last_seen_time = m._now
		p.enter_hiding(spot)
		for i: int in range(300):
			await _frames(3)
			if _died:
				break
		_check(_died, "vu en entrant dans l'armoire : il l'en arrache")
	await _wait(1.5)
	await main.continue_game()


func _test_scares() -> void:
	var w := _world()
	var sm := w.scares
	w.monster.set_physics_process(false)
	w.player.flashlight.set_on(true)
	var count := 0
	for s: Dictionary in sm.scares:
		var ctx: Node = null
		var visual := str(s.get("visual", ""))
		if visual != "":
			for n: Node in _find_all(w, "ExamineProp") + _find_all(w, "Drawer"):
				if n.has_method("play_scare_visual"):
					var trig := str(s.get("trigger", ""))
					if str(n.get("scare_trigger")) == trig or trig == "":
						ctx = n
			if ctx == null:
				for n2: Node in _find_all(w, "ExamineProp"):
					ctx = n2
		_place_player(Vector3(2.0, 0.05, 10.5), -PI * 0.5, 0.0)
		for n3: Node in _find_all(w, "Door"):
			var d := n3 as Door
			if d.global_position.distance_to(w.player.global_position) < 8.0 and not d.is_open:
				d.open_from(w.player.global_position, 0.1)
		await _frames(4)
		var ok := sm._execute(s, ctx)
		if ok:
			count += 1
		_log("  screamer %s : %s" % [str(s.get("id", "?")), "joué" if ok else "non applicable ici"])
		if str(s.get("id", "")) == "silhouette_couloir" and ok:
			await _shot("24_screamer_silhouette")
		await _wait(0.5)
	_check(count >= 12, "screamers exécutés sans erreur (%d / %d)" % [count, sm.scares.size()])
	_check(sm.scares.size() >= 10, "au moins 10 screamers configurés")
	w.monster.set_physics_process(true)


func _test_save_load() -> void:
	var w := _world()
	w.save_checkpoint()
	var d := SaveSystem.read_save()
	_check(not d.is_empty(), "sauvegarde écrite et relue")
	_check(bool((d.get("flags", {}) as Dictionary).get("candles_done", false)), "drapeaux d'énigmes sauvegardés")


func _test_ui() -> void:
	var w := _world()
	Events.keypad_requested.emit(_find_one(w, "Safe"))
	await _frames(3)
	await _shot("25_pave_numerique")
	main.keypad.close()
	await _frames(2)
	main._open_ui()
	main.journal.open()
	await _frames(3)
	await _shot("26_journal")
	main.journal.close()
	await _frames(2)
	main._pause()
	await _frames(2)
	main.pause_menu._open_options()
	await _frames(3)
	await _shot("27_options")
	var opt := main.pause_menu.options
	opt._preset_low()
	_check(Settings.quality == Settings.Quality.LOW, "préréglage PC faible appliqué")
	Settings.quality = Settings.Quality.MEDIUM
	Settings.render_scale = 0.75
	Settings.shadows = true
	Settings.max_fps = 60
	Settings.apply_all()
	opt._close()
	main._resume()
	await _frames(3)
	_check(GameManager.is_playing() and not get_tree().paused, "reprise après pause")


func _test_ending() -> void:
	var w := _world()
	GameManager.set_flag("register_burned", true)
	var md := _find_one(w, "MainDoor") as MainDoor
	_place_player(Vector3(22.0, 0.05, 28.0), PI, 0.0)
	w.monster.set_physics_process(false)
	_victory = ""
	md.interact(w.player)
	for i: int in range(700):
		await _frames(2)
		if _victory != "":
			break
		if i == 150:
			await _shot("28_porte_ouverte")
	_check(_victory == "delivrance", "fin « Délivrance » atteinte (%s)" % _victory)
	await _wait(1.5)
	await _shot("29_ecran_fin")
