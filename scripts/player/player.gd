class_name Player
extends CharacterBody3D
## Joueur à la première personne : marche, course (endurance), accroupissement,
## balancement de tête, bruits de pas (entendus par le monstre), cachettes, capture.

const WALK_SPEED: float = 2.7
const SPRINT_SPEED: float = 4.7
const CROUCH_SPEED: float = 1.35
const ACCEL: float = 10.0
const GRAVITY: float = 18.0
const STAND_H: float = 1.75
const CROUCH_H: float = 1.05
const EYE_STAND: float = 1.6
const EYE_CROUCH: float = 0.92
const RADIUS: float = 0.3
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 15.0
const STAMINA_REGEN: float = 12.0

var head: Node3D
var cam_pivot: Node3D
var camera: Camera3D
var flashlight: Flashlight
var interaction: InteractionSystem
var col_shape: CollisionShape3D
var capsule: CapsuleShape3D
## Renvoie "wood" ou "stone" selon la position (fourni par GameWorld).
var surface_at: Callable = Callable()

var yaw: float = 0.0
var pitch: float = 0.0
var stamina: float = STAMINA_MAX
var exhausted: bool = false
var crouching: bool = false
var crouch_toggled: bool = false
var sprinting: bool = false
var control_enabled: bool = true
var look_enabled: bool = true
var is_hidden: bool = false
var hidden_in: HidingSpot = null
var caught: bool = false
var trauma: float = 0.0
var fov_offset: float = 0.0

var eye_height: float = EYE_STAND
## Vrai pendant les cinématiques (réveil, fin) : la hauteur des yeux est pilotée de l'extérieur.
var cinematic: bool = false
var _bob_t: float = 0.0
var _step_accum: float = 0.0
var _regen_delay: float = 0.0
var _breath: AudioStreamPlayer
var _shake_t: float = 0.0
var _hide_yaw: float = 0.0
var _tween: Tween
var _look_override: bool = false


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.DOORS
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	col_shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = STAND_H
	col_shape.shape = capsule
	col_shape.position = Vector3(0, STAND_H * 0.5, 0)
	add_child(col_shape)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)
	cam_pivot = Node3D.new()
	head.add_child(cam_pivot)
	camera = Camera3D.new()
	camera.near = 0.04
	camera.current = true
	cam_pivot.add_child(camera)
	flashlight = Flashlight.new()
	flashlight.follow = camera
	add_child(flashlight)
	interaction = InteractionSystem.new()
	interaction.player = self
	camera.add_child(interaction)
	_breath = AudioStreamPlayer.new()
	_breath.bus = "SFX"
	_breath.volume_db = -80.0
	add_child(_breath)
	_breath.stream = AudioManager.get_stream("breath_player")
	Events.camera_shake.connect(add_trauma)
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()
	yaw = rotation.y


func _apply_settings() -> void:
	camera.fov = Settings.fov
	camera.far = Settings.camera_far()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func set_view(p_yaw: float, p_pitch: float) -> void:
	yaw = p_yaw
	pitch = p_pitch
	rotation.y = yaw
	head.rotation.x = pitch


func eye_position() -> Vector3:
	return camera.global_position


func is_flashlight_on() -> bool:
	return flashlight.is_on


# ============================================================ entrées

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing() or caught:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and look_enabled and not _look_override:
		var mm := event as InputEventMouseMotion
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		yaw -= mm.relative.x * sens
		var dy := mm.relative.y * sens
		pitch -= -dy if Settings.invert_y else dy
		if is_hidden and hidden_in != null:
			yaw = clampf(yaw, _hide_yaw - hidden_in.yaw_limit, _hide_yaw + hidden_in.yaw_limit)
			pitch = clampf(pitch, -hidden_in.pitch_limit, hidden_in.pitch_limit)
		else:
			pitch = clampf(pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = yaw
		head.rotation.x = pitch
	elif event.is_action_pressed("flashlight") and not is_hidden:
		flashlight.toggle()
	elif event.is_action_pressed("reload"):
		flashlight.use_battery()
	elif event.is_action_pressed("crouch_toggle") and not is_hidden:
		crouch_toggled = not crouch_toggled


# ============================================================ déplacement

func _physics_process(delta: float) -> void:
	if is_hidden or caught or not GameManager.is_playing():
		if not is_hidden and not caught:
			velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
			velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		_update_breath(delta, false)
		return
	var dir := Vector2.ZERO
	if control_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Accroupi
	var want_crouch := control_enabled and (Input.is_action_pressed("crouch") or crouch_toggled)
	if want_crouch and not crouching:
		_set_crouch(true)
	elif not want_crouch and crouching and _can_stand():
		_set_crouch(false)
	# Course et endurance
	var moving := dir.length() > 0.1
	var wants_sprint := control_enabled and Input.is_action_pressed("sprint") and moving and dir.y < 0.3 and not crouching
	sprinting = wants_sprint and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		_regen_delay = 1.0
		if stamina <= 0.0:
			exhausted = true
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0:
			stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta * (0.6 if exhausted else 1.0))
		if exhausted and stamina > 35.0:
			exhausted = false
	Events.stamina_changed.emit(stamina / STAMINA_MAX)
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	elif exhausted:
		speed = WALK_SPEED * 0.85
	var wish := (global_basis * Vector3(dir.x, 0.0, dir.y))
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * speed
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_update_steps(delta)
	_update_breath(delta, true)


func _set_crouch(on: bool) -> void:
	crouching = on
	capsule.height = CROUCH_H if on else STAND_H
	col_shape.position = Vector3(0, capsule.height * 0.5, 0)


func _can_stand() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS * 0.95
	shape.height = STAND_H
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_H * 0.5 + 0.02, 0))
	params.collision_mask = Layers.WORLD | Layers.DOORS
	params.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func _update_steps(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or hspeed < 0.3:
		return
	_step_accum += hspeed * delta
	var stride := 0.72
	if sprinting:
		stride = 0.95
	elif crouching:
		stride = 0.6
	if _step_accum >= stride:
		_step_accum = 0.0
		_footstep()


func _footstep() -> void:
	var surface := "wood"
	if surface_at.is_valid():
		surface = str(surface_at.call(global_position))
	var snd := "step_wood_%d" % randi_range(1, 3)
	if surface == "stone":
		snd = "step_stone_%d" % randi_range(1, 2)
	var vol := -9.0
	var radius := 3.2
	if sprinting:
		vol = -2.0
		radius = 11.0
	elif crouching:
		vol = -20.0
		radius = 0.0
	AudioManager.play_2d(snd, vol, randf_range(0.9, 1.1))
	if radius > 0.0:
		Events.noise_emitted.emit(global_position, radius, "step")


func _update_breath(delta: float, active_state: bool) -> void:
	var target_db := -80.0
	if active_state and (exhausted or stamina < 30.0):
		target_db = -10.0 if exhausted else -18.0
	if is_hidden:
		target_db = -22.0
	if target_db > -79.0 and not _breath.playing and _breath.stream != null:
		_breath.play()
	_breath.volume_db = move_toward(_breath.volume_db, target_db, 40.0 * delta)
	if _breath.volume_db <= -79.0 and _breath.playing:
		_breath.stop()


# ============================================================ caméra

func _process(delta: float) -> void:
	var target_eye := EYE_CROUCH if crouching else EYE_STAND
	if cinematic:
		head.position.y = eye_height
	elif not is_hidden and not caught:
		eye_height = lerpf(eye_height, target_eye, clampf(delta * 10.0, 0.0, 1.0))
		head.position.y = eye_height
	# Balancement de tête
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector3.ZERO
	if Settings.head_bob and is_on_floor() and hspeed > 0.3 and not is_hidden and not caught:
		_bob_t += delta * hspeed * 2.4
		var amp := 0.028 if not sprinting else 0.045
		bob = Vector3(cos(_bob_t) * amp * 0.6, absf(sin(_bob_t)) * amp, 0.0)
	# Tremblement (trauma)
	trauma = maxf(0.0, trauma - delta * 0.9)
	_shake_t += delta * 30.0
	var sh := trauma * trauma
	var rot := Vector3(sin(_shake_t * 1.3) * 0.06, sin(_shake_t * 1.7 + 1.0) * 0.06, sin(_shake_t * 2.1 + 2.0) * 0.09) * sh
	cam_pivot.position = cam_pivot.position.lerp(bob, clampf(delta * 12.0, 0.0, 1.0))
	cam_pivot.rotation = rot
	var target_fov := Settings.fov + (6.0 if sprinting and hspeed > 2.0 else 0.0) + fov_offset
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))


# ============================================================ cachettes

func enter_hiding(spot: HidingSpot) -> void:
	if is_hidden or caught:
		return
	is_hidden = true
	hidden_in = spot
	spot.occupied = true
	control_enabled = false
	col_shape.disabled = true
	velocity = Vector3.ZERO
	_set_crouch(false)
	crouch_toggled = false
	flashlight.set_on(false)
	var eye := spot.eye_global()
	var fwd := -eye.basis.z
	_hide_yaw = atan2(-fwd.x, -fwd.z)
	spot.play_enter()
	AudioManager.play_3d("hide", spot.global_position + Vector3(0, 1, 0), -4.0)
	Events.noise_emitted.emit(spot.global_position, 2.0, "hide")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "global_position", eye.origin - Vector3(0, EYE_STAND, 0), 0.45).set_trans(Tween.TRANS_SINE)
	_tween.tween_method(func(v: float) -> void: set_view(lerp_angle(yaw, _hide_yaw, v), lerpf(pitch, 0.0, v)), 0.0, 1.0, 0.45)
	eye_height = EYE_STAND
	head.position.y = EYE_STAND
	AudioManager.set_muffled(true)
	Events.hide_state_changed.emit(true, spot.kind)


func exit_hiding() -> void:
	if not is_hidden or hidden_in == null or caught:
		return
	var spot := hidden_in
	spot.play_exit()
	AudioManager.play_3d("hide", spot.global_position + Vector3(0, 1, 0), -4.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", spot.exit_global(), 0.4).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		col_shape.disabled = false
		control_enabled = true
		is_hidden = false
		spot.occupied = false
		hidden_in = null
		AudioManager.set_muffled(false)
		Events.hide_state_changed.emit(false, spot.kind))


## Sortie forcée (capture dans une cachette) : pas d'animation.
func force_out_of_hiding() -> void:
	if not is_hidden or hidden_in == null:
		return
	var spot := hidden_in
	if _tween != null and _tween.is_valid():
		_tween.kill()
	global_position = spot.exit_global()
	col_shape.disabled = false
	is_hidden = false
	spot.occupied = false
	hidden_in = null
	AudioManager.set_muffled(false)
	Events.hide_state_changed.emit(false, spot.kind)


# ============================================================ capture

## Le monstre a attrapé le joueur : la caméra est forcée vers son visage.
func on_caught(face_pos: Vector3) -> void:
	if caught:
		return
	force_out_of_hiding()
	caught = true
	control_enabled = false
	look_enabled = false
	velocity = Vector3.ZERO
	trauma = 1.0
	flashlight.flicker(1.5)
	var dir := face_pos - camera.global_position
	var target_yaw := atan2(-dir.x, -dir.z)
	var flat := Vector2(dir.x, dir.z).length()
	var target_pitch := clampf(atan2(dir.y, flat), -1.2, 1.2)
	var start_yaw := yaw
	var start_pitch := pitch
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float) -> void: set_view(lerp_angle(start_yaw, target_yaw, v), lerpf(start_pitch, target_pitch, v)), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "fov_offset", -22.0, 0.5)
	_tween.tween_property(head, "position:y", EYE_STAND - 0.35, 1.2).set_trans(Tween.TRANS_BOUNCE)


func reset_state() -> void:
	caught = false
	control_enabled = true
	look_enabled = true
	fov_offset = 0.0
	trauma = 0.0
