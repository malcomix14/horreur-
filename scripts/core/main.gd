class_name MainController
extends Node
## Nœud racine : démarrage (génération des ressources), menus, chargement du monde,
## pause, lecture des documents, écrans de mort et de victoire.

var world: GameWorld = null
var hud: HUD
var post: PostProcess
var loading: LoadingScreen
var menu: MainMenu
var pause_menu: PauseMenu
var notes: NoteViewer
var keypad: KeypadUI
var journal: JournalUI
var end_screen: EndScreen
var _busy: bool = false
var _note_from_journal: bool = false


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	InputSetup.ensure_actions()
	randomize()
	post = PostProcess.new()
	add_child(post)
	hud = HUD.new()
	add_child(hud)
	notes = NoteViewer.new()
	add_child(notes)
	keypad = KeypadUI.new()
	add_child(keypad)
	journal = JournalUI.new()
	add_child(journal)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	end_screen = EndScreen.new()
	add_child(end_screen)
	menu = MainMenu.new()
	add_child(menu)
	loading = LoadingScreen.new()
	add_child(loading)
	post.visible = false
	Settings.apply_all()
	menu.new_game_requested.connect(start_new_game)
	menu.continue_requested.connect(continue_game)
	menu.quit_requested.connect(quit_game)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.menu_requested.connect(back_to_menu)
	pause_menu.quit_requested.connect(quit_game)
	end_screen.retry_requested.connect(continue_game)
	end_screen.restart_requested.connect(start_new_game)
	end_screen.menu_requested.connect(back_to_menu)
	notes.closed.connect(_on_note_closed)
	keypad.closed.connect(_close_ui)
	journal.closed.connect(_close_ui)
	journal.note_open_requested.connect(func(id: String) -> void:
		_note_from_journal = true
		journal.visible = false
		notes.open(id))
	Events.note_requested.connect(_open_note)
	Events.keypad_requested.connect(_open_keypad)
	Events.player_died.connect(_on_player_died)
	Events.victory.connect(_on_victory)
	_boot()


func _boot() -> void:
	GameManager.set_phase(GameManager.Phase.BOOT)
	loading.show_loading("Préparation du manoir… (le premier lancement génère les textures et les sons)")
	await Assets.prepare(func(r: float, t: String) -> void: loading.set_progress(r * 0.45, t))
	await AudioManager.prepare(func(r: float, t: String) -> void: loading.set_progress(0.45 + r * 0.55, t))
	loading.hide_loading()
	if OS.get_cmdline_user_args().has("--autotest"):
		var at := AutoTest.new()
		at.main = self
		add_child(at)
		return
	show_menu()


func show_menu() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	hud.visible = false
	post.visible = false
	end_screen.close()
	menu.open()
	AudioManager.start_music()
	AudioManager.set_music_targets(0.7, 0.0, 0.0, 0.5)


# ============================================================ parties

func start_new_game() -> void:
	SaveSystem.erase_save()
	GameManager.new_game()
	await _start_world({}, true)


func continue_game() -> void:
	var d := SaveSystem.read_save()
	if d.is_empty():
		await start_new_game()
		return
	var deaths := GameManager.deaths
	GameManager.deserialize(d)
	GameManager.deaths = maxi(deaths, GameManager.deaths)
	await _start_world(d, false)


func _start_world(save: Dictionary, intro: bool) -> void:
	if _busy:
		return
	_busy = true
	menu.visible = false
	end_screen.close()
	pause_menu.close()
	notes.visible = false
	keypad.visible = false
	journal.visible = false
	get_tree().paused = false
	_free_world()
	GameManager.set_phase(GameManager.Phase.LOADING)
	loading.show_loading("Le manoir s'éveille…")
	world = GameWorld.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	await world.build(save, func(r: float, t: String) -> void: loading.set_progress(r, t))
	hud.player = world.player
	hud.reset()
	post.reset()
	hud.visible = true
	post.visible = true
	loading.hide_loading()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_phase(GameManager.Phase.PLAYING)
	AudioManager.start_music()
	if intro:
		world.play_intro()
	else:
		world._update_objective()
		Events.message_requested.emit("Reprise au dernier point de sauvegarde.", 3.0)
	_busy = false


func _free_world() -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
		world = null
	AudioManager.stop_all_3d()
	AudioManager.set_muffled(false)


## Fermeture propre : coupe le son, libère le monde, puis quitte.
func quit_game(code: int = 0) -> void:
	Settings.save_settings()
	get_tree().paused = false
	_free_world()
	AudioManager.shutdown()
	# Laisse au serveur audio le temps de libérer les sons arrêtés (sinon fuites signalées à la fermeture).
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 200:
		await get_tree().process_frame
	get_tree().quit(code)


func back_to_menu() -> void:
	get_tree().paused = false
	pause_menu.close()
	_free_world()
	show_menu()


# ============================================================ pause et interfaces

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		Settings.show_fps = not Settings.show_fps
		Settings.save_settings()
		return
	match GameManager.phase:
		GameManager.Phase.PLAYING:
			if world == null or world.player == null or world.player.caught:
				return
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_pause()
			elif event.is_action_pressed("journal"):
				get_viewport().set_input_as_handled()
				_open_ui()
				journal.open()
		GameManager.Phase.PAUSED:
			if event.is_action_pressed("pause") and not pause_menu.is_in_options():
				get_viewport().set_input_as_handled()
				_resume()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameManager.phase == GameManager.Phase.PLAYING:
		if world != null and world.player != null and not world.player.caught:
			_pause()


func _pause() -> void:
	GameManager.set_phase(GameManager.Phase.PAUSED)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.open()


func _resume() -> void:
	pause_menu.close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_phase(GameManager.Phase.PLAYING)


func _open_ui() -> void:
	GameManager.set_phase(GameManager.Phase.UI)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.interact_prompt_changed.emit("")


func _close_ui() -> void:
	if GameManager.phase != GameManager.Phase.UI:
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_phase(GameManager.Phase.PLAYING)


func _open_note(note_id: String) -> void:
	_note_from_journal = false
	_open_ui()
	notes.open(note_id)


func _on_note_closed(note_id: String) -> void:
	if _note_from_journal:
		_note_from_journal = false
		journal.open()
		return
	_close_ui()
	Events.note_closed.emit(note_id)


func _open_keypad(target: Node) -> void:
	if target is Safe:
		_open_ui()
		keypad.open(target as Safe)


# ============================================================ fin de partie

func _on_player_died() -> void:
	GameManager.deaths += 1
	GameManager.set_phase(GameManager.Phase.DEAD)
	hud.fade(1.0, 0.5)
	var dead_world := world
	await get_tree().create_timer(0.8, true).timeout
	# Si une nouvelle partie a été lancée entre-temps, on n'affiche rien.
	if world != dead_world or GameManager.phase != GameManager.Phase.DEAD:
		return
	get_tree().paused = true
	end_screen.show_death()


func _on_victory(ending: String) -> void:
	GameManager.set_phase(GameManager.Phase.VICTORY)
	get_tree().paused = true
	AudioManager.stop_music()
	AudioManager.play_2d("victory", -4.0, 1.0, "Music")
	end_screen.show_victory(ending)


func _process(_delta: float) -> void:
	if world != null and world.ambience != null:
		post.fear = world.ambience.fear


## Vide les caches statiques pour une sortie propre (aucune fuite signalée).
func _exit_tree() -> void:
	Door.clear_cache()
	ItemVisuals.clear_cache()
	MonsterBody.clear_cache()
	UITheme.clear_cache()
