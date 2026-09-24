class_name Monster
extends CharacterBody3D
## Le Veilleur — IA à états : Patrouille -> Enquête -> Poursuite -> Capture, et Recherche
## quand il perd le joueur. Vue (cône + rayons), ouïe (bruits via Events), NavigationAgent3D.
## Il ouvre les portes. Il ne tue qu'en ATTRAPANT le joueur (contact après poursuite).
## Équité : il crie avant de charger (avance au joueur), il est un peu plus lent qu'un sprint,
## il ne voit pas un joueur caché hors de sa vue, et il s'éloigne un moment après une fouille.

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, CAPTURE }

const PATROL_SPEED: float = 1.45
const INVESTIGATE_SPEED: float = 2.2
const SEARCH_SPEED: float = 1.8
const CHASE_SPEED: float = 4.0
const CAPTURE_DIST: float = 1.25
const EYE_HEIGHT: float = 2.05
const FOV_COS: float = 0.47
const FOV_COS_CHASE: float = 0.17
const CHASE_MEMORY: float = 3.0
const RETREAT_TIME: float = 35.0

var body: MonsterBody
var agent: NavigationAgent3D
var player: Player
var patrol_points: Array[Vector3] = []
var nav_ready: bool = false
var state: State = State.DORMANT
var state_time: float = 0.0
var detection: float = 0.0
var last_known: Vector3 = Vector3.ZERO
var last_seen_time: float = -999.0
var enraged: bool = false
var retreat_until: float = 0.0
var last_near_time: float = 0.0

var _now: float = 0.0
var _action_lock: float = 0.0
var _idle_timer: float = 0.0
var _vision_timer: float = 0.0
var _can_see: bool = false
var _door_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_count: int = 0
var _search_points: Array[Vector3] = []
var _search_idx: int = 0
var _search_spot: HidingSpot = null
var _target_spot: HidingSpot = null
var _last_wp: int = -1
var _target: Vector3 = Vector3.ZERO
var _was_hidden: bool = false
var _breath: AudioStreamPlayer3D
var _growl_timer: float = 10.0
var _occl_timer: float = 0.0
var _occluded: bool = false
var _action_pose: MonsterBody.Pose = MonsterBody.Pose.IDLE
var _action_pose_time: float = 0.0


func _ready() -> void:
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(46.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 2.1
	cs.shape = cap
	cs.position = Vector3(0, 1.05, 0)
	add_child(cs)
	body = MonsterBody.new()
	add_child(body)
	body.stepped.connect(_on_step)
	agent = NavigationAgent3D.new()
	agent.radius = 0.4
	agent.height = 2.2
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.7
	agent.path_max_distance = 3.0
	agent.avoidance_enabled = false
	add_child(agent)
	_breath = AudioManager.make_emitter("breath_monster", self, -2.0, 2.6, 18.0, false)
	_breath.position = Vector3(0, 2.0, 0)
	Events.noise_emitted.connect(_on_noise)
	Events.register_burned.connect(_on_enrage)
	enraged = GameManager.get_flag("register_burned")
	visible = false


# ============================================================ activation

func activate(spawn: Vector3) -> void:
	global_position = spawn
	visible = true
	_set_state(State.PATROL)
	_idle_timer = 1.0
	last_near_time = _now
	if _breath.stream != null:
		_breath.play()


func is_active() -> bool:
	return state != State.DORMANT


func is_chasing() -> bool:
	return state == State.CHASE


func state_name() -> String:
	return State.keys()[state]


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	state_time = 0.0
	_idle_timer = 0.0
	_stuck_count = 0
	Events.monster_state_changed.emit(state_name())


# ============================================================ boucle

func _physics_process(delta: float) -> void:
	if state == State.DORMANT or player == null:
		return
	_now += delta
	state_time += delta
	if state == State.CAPTURE:
		velocity = Vector3.ZERO
		_face(player.global_position, delta, 14.0)
		body.speed = 0.0
		body.pose = MonsterBody.Pose.GRAB
		return
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = 0.1
		_can_see = _check_vision()
	_update_detection(delta)
	_check_hidden_transition()
	if player.global_position.distance_to(global_position) < 14.0:
		last_near_time = _now
	match state:
		State.PATROL:
			_update_patrol(delta)
		State.INVESTIGATE:
			_update_investigate(delta)
		State.CHASE:
			_update_chase(delta)
		State.SEARCH:
			_update_search(delta)
	if state == State.CAPTURE:
		return
	_move(delta)
	_handle_doors(delta)
	_update_audio(delta)
	_update_lod()


# ============================================================ sens

func _check_vision() -> bool:
	if player.is_hidden or player.caught:
		return false
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var head_p := player.eye_position()
	var chest_p := player.global_position + Vector3(0, 0.5 if player.crouching else 0.95, 0)
	var to := head_p - eye
	var dist := to.length()
	var flat_d := Vector2(to.x, to.z).length()
	if flat_d < 1.6 and absf(player.global_position.y - global_position.y) < 1.4:
		return true
	var max_d := 20.0 if player.is_flashlight_on() else 12.0
	if player.crouching:
		max_d *= 0.75
	if enraged:
		max_d += 4.0
	if state == State.CHASE:
		max_d = 28.0
	if dist > max_d:
		return false
	var fwd := -body.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dir := Vector3(to.x, 0.0, to.z).normalized()
	var min_cos := FOV_COS_CHASE if state == State.CHASE else FOV_COS
	if fwd.dot(dir) < min_cos:
		return false
	var space := get_world_3d().direct_space_state
	for t: Vector3 in [head_p, chest_p]:
		var q := PhysicsRayQueryParameters3D.create(eye, t, Layers.WORLD | Layers.DOORS)
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _has_los(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), p + Vector3(0, 0.5, 0), Layers.WORLD | Layers.DOORS)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_detection(delta: float) -> void:
	if _can_see:
		var d := global_position.distance_to(player.global_position)
		var rate := 1.0 / (0.22 + d * 0.065)
		if state == State.INVESTIGATE or state == State.SEARCH:
			rate *= 1.6
		if enraged:
			rate *= 1.4
		detection = minf(detection + rate * delta, 1.5)
		last_known = player.global_position
		last_seen_time = _now
		if state == State.CHASE:
			return
		if detection >= 1.0:
			_start_chase()
		elif detection > 0.3 and state == State.PATROL:
			_investigate(player.global_position, false)
	else:
		detection = maxf(0.0, detection - 0.3 * delta)


func _on_noise(pos: Vector3, radius: float, source: String) -> void:
	if state == State.DORMANT or state == State.CAPTURE or radius <= 0.0:
		return
	var eff := radius
	if absf(pos.y - global_position.y) > 2.0:
		eff *= 0.45
	elif not _has_los(pos):
		eff *= 0.7
	if enraged:
		eff *= 1.3
	if global_position.distance_to(pos) > eff:
		return
	if state == State.CHASE:
		if source == "step" or source == "door":
			last_known = pos
			last_seen_time = maxf(last_seen_time, _now - 1.5)
		return
	_investigate(pos, true)


func _check_hidden_transition() -> void:
	var hidden := player.is_hidden
	if hidden and not _was_hidden:
		var spot := player.hidden_in
		if spot != null:
			var saw_recently := (_now - last_seen_time) < 1.3
			var close := global_position.distance_to(spot.global_position) < 4.5
			if (state == State.CHASE and (saw_recently or close)) or (state == State.INVESTIGATE and saw_recently and close):
				spot.compromised = true
				_target_spot = spot
	elif not hidden and _was_hidden:
		for n: Node in get_tree().get_nodes_in_group("hiding_spots"):
			(n as HidingSpot).compromised = false
		_target_spot = null
	_was_hidden = hidden


# ============================================================ états

func _update_patrol(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_next_waypoint()
		return
	if _reached(_target, 1.0) or (nav_ready and agent.is_navigation_finished() and state_time > 1.0):
		_idle_timer = randf_range(1.2, 3.5)
		if randf() < 0.35:
			_growl()


func _next_waypoint() -> void:
	if patrol_points.is_empty():
		return
	var pp := player.global_position
	var candidates: Array[int] = []
	var mode := "random"
	if _now < retreat_until:
		mode = "far"
	elif _now - last_near_time > 70.0:
		mode = "hunt"
	elif randf() < 0.4:
		mode = "near"
	for i: int in range(patrol_points.size()):
		if i == _last_wp:
			continue
		var p := patrol_points[i]
		if p.distance_to(global_position) < 3.0:
			continue
		var d := p.distance_to(pp)
		match mode:
			"far":
				if d > 20.0:
					candidates.append(i)
			"hunt":
				if d > 5.0 and d < 15.0:
					candidates.append(i)
			"near":
				if d > 8.0 and d < 20.0:
					candidates.append(i)
			_:
				candidates.append(i)
	if candidates.is_empty():
		for i: int in range(patrol_points.size()):
			if i != _last_wp:
				candidates.append(i)
	var idx := candidates[randi() % candidates.size()]
	_last_wp = idx
	_set_target(patrol_points[idx])
	state_time = 0.0


func _investigate(pos: Vector3, from_noise: bool) -> void:
	if state == State.CHASE or state == State.CAPTURE:
		return
	var was := state
	_set_state(State.INVESTIGATE)
	_set_target(pos)
	if was == State.PATROL:
		# Il s'arrête, tend l'oreille, puis se dirige vers la source.
		_lock(0.7 if from_noise else 0.4, MonsterBody.Pose.SEARCH)
	body.set_look_yaw(0.0)


func _update_investigate(_delta: float) -> void:
	if _reached(_target, 1.3) or (nav_ready and agent.is_navigation_finished() and state_time > 1.0) or state_time > 25.0:
		_start_search(_target, 3)


func _start_chase() -> void:
	if state == State.CHASE:
		return
	var was_searching := state == State.SEARCH or state == State.INVESTIGATE
	_set_state(State.CHASE)
	detection = 1.0
	# Cri avant la charge : le joueur a une petite avance.
	_lock(0.5 if was_searching else 0.85, MonsterBody.Pose.SCREAM)
	AudioManager.play_3d("monster_scream", global_position + Vector3(0, 2.0, 0), 6.0, randf_range(0.92, 1.05), 60.0, 8.0)
	Events.camera_shake.emit(0.25)


func _update_chase(_delta: float) -> void:
	var target := last_known
	if player.is_hidden:
		if _target_spot != null and _target_spot == player.hidden_in and _target_spot.compromised:
			target = _target_spot.search_point()
			if _reached(target, 1.2):
				_capture_from_spot(_target_spot)
				return
		else:
			if _now - last_seen_time > 1.0:
				_start_search(last_known, 4)
				return
	else:
		var memory := CHASE_MEMORY + (2.0 if enraged else 0.0)
		if _can_see or _now - last_seen_time < memory:
			target = player.global_position
		elif _reached(last_known, 1.3):
			_start_search(last_known, 4)
			return
		var d := global_position.distance_to(player.global_position)
		if d < CAPTURE_DIST and absf(player.global_position.y - global_position.y) < 1.3 and _action_lock <= 0.0:
			_capture()
			return
	if state_time > 60.0 and _now - last_seen_time > 6.0:
		_start_search(last_known, 3)
		return
	_set_target(target)


func _start_search(center: Vector3, count: int) -> void:
	_set_state(State.SEARCH)
	_search_points.clear()
	_search_idx = 0
	_search_spot = null
	var map := agent.get_navigation_map()
	_search_points.append(center)
	for i: int in range(count):
		var ang := randf() * TAU
		var r := randf_range(2.0, 7.0)
		var p := center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if nav_ready:
			p = NavigationServer3D.map_get_closest_point(map, p)
		if absf(p.y - center.y) < 1.5:
			_search_points.append(p)
	# Il inspecte parfois la cachette la plus proche (sans trouver le joueur s'il ne l'a pas vu entrer).
	var best_d := 7.0
	for n: Node in get_tree().get_nodes_in_group("hiding_spots"):
		var hs := n as HidingSpot
		var d := hs.global_position.distance_to(center)
		if d < best_d and absf(hs.global_position.y - center.y) < 1.5:
			best_d = d
			_search_spot = hs
	if _search_spot != null and randf() < 0.75:
		_search_points.insert(mini(1, _search_points.size()), _search_spot.search_point())
	else:
		_search_spot = null
	_set_target(_search_points[0])


func _update_search(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		body.pose = MonsterBody.Pose.SEARCH
		if _idle_timer <= 0.0:
			_search_idx += 1
			if _search_idx >= _search_points.size():
				_end_search()
				return
			_set_target(_search_points[_search_idx])
		return
	var tgt := _search_points[_search_idx]
	if _reached(tgt, 1.1) or (nav_ready and agent.is_navigation_finished() and state_time > 1.5):
		_idle_timer = randf_range(1.2, 2.6)
		if _search_spot != null and tgt.distance_to(_search_spot.search_point()) < 0.5:
			_face(_search_spot.global_position, 1.0, 100.0)
			_idle_timer = 3.0
			_growl()
			if player.is_hidden and player.hidden_in == _search_spot and _search_spot.compromised:
				_capture_from_spot(_search_spot)
				return
	if state_time > 26.0:
		_end_search()


func _end_search() -> void:
	_set_state(State.PATROL)
	detection = 0.0
	retreat_until = _now + RETREAT_TIME
	_next_waypoint()


func _capture_from_spot(spot: HidingSpot) -> void:
	spot.play_yank()
	player.force_out_of_hiding()
	_capture()


func _capture() -> void:
	_set_state(State.CAPTURE)
	velocity = Vector3.ZERO
	# Se place juste devant le joueur pour que le visage soit bien cadré.
	var to_me := global_position - player.global_position
	to_me.y = 0.0
	if to_me.length() < 0.1:
		to_me = -player.global_basis.z
	global_position = player.global_position + to_me.normalized() * 1.35
	_face(player.global_position, 1.0, 100.0)
	body.pose = MonsterBody.Pose.GRAB
	body.jaw_open = 1.0
	AudioManager.play_2d("capture", 0.0)
	Events.screen_flash.emit(Color(0.6, 0.0, 0.0, 0.55), 0.6)
	player.on_caught(body.head.global_position + Vector3(0, 0.05, 0))
	Events.player_caught.emit()
	var _delay_tw4 := create_tween()
	_delay_tw4.tween_interval(1.7)
	_delay_tw4.tween_callback(func() -> void: Events.player_died.emit())


# ============================================================ mouvement

## Force le recalcul du chemin (après un nouveau navmesh).
func refresh_path() -> void:
	if nav_ready:
		agent.target_position = _target + Vector3(0.01, 0, 0)


func _set_target(p: Vector3) -> void:
	_target = p
	if nav_ready and agent.target_position.distance_to(p) > 0.4:
		agent.target_position = p


func _reached(p: Vector3, tol: float) -> bool:
	var d := global_position - p
	d.y *= 0.3
	return d.length() < tol


func _lock(duration: float, pose: MonsterBody.Pose) -> void:
	_action_lock = maxf(_action_lock, duration)
	_action_pose = pose
	_action_pose_time = duration


func _current_speed() -> float:
	var s := 0.0
	match state:
		State.PATROL:
			s = PATROL_SPEED
		State.INVESTIGATE:
			s = INVESTIGATE_SPEED
		State.SEARCH:
			s = SEARCH_SPEED
		State.CHASE:
			s = CHASE_SPEED
	if enraged:
		s *= 1.12
	return s


func _move(delta: float) -> void:
	var speed := _current_speed()
	if _action_lock > 0.0:
		_action_lock -= delta
		speed = 0.0
	if _idle_timer > 0.0:
		speed = 0.0
	var dir := Vector3.ZERO
	if speed > 0.0 and nav_ready and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		dir = next - global_position
		dir.y = 0.0
		if dir.length() > 0.02:
			dir = dir.normalized()
	var desired := dir * speed
	velocity.x = move_toward(velocity.x, desired.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 14.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	body.speed = hv.length()
	if state == State.CHASE and _can_see and global_position.distance_to(player.global_position) < 5.0:
		_face(player.global_position, delta, 10.0)
	elif hv.length() > 0.2:
		_face(global_position + hv, delta, 7.0)
	# Pose.
	if _action_pose_time > 0.0:
		_action_pose_time -= delta
		body.pose = _action_pose
	elif hv.length() > 0.15:
		body.pose = MonsterBody.Pose.WALK
	elif state == State.SEARCH or state == State.INVESTIGATE:
		body.pose = MonsterBody.Pose.SEARCH
	else:
		body.pose = MonsterBody.Pose.IDLE
	body.jaw_open = 0.9 if state == State.CHASE else 0.15
	# Anti-blocage.
	_stuck_timer += delta
	if _stuck_timer > 1.5:
		_stuck_timer = 0.0
		var moved := global_position.distance_to(_stuck_pos)
		_stuck_pos = global_position
		if speed > 0.0 and moved < 0.3 and _action_lock <= 0.0:
			_stuck_count += 1
			if nav_ready:
				agent.target_position = _target + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			if _stuck_count >= 3:
				_stuck_count = 0
				match state:
					State.PATROL:
						_next_waypoint()
					State.SEARCH:
						_idle_timer = 0.01
					State.INVESTIGATE:
						_start_search(global_position, 2)
		else:
			_stuck_count = 0


func _face(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var target_yaw := atan2(-d.x, -d.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(delta * rate, 0.0, 1.0))


func _handle_doors(delta: float) -> void:
	_door_timer -= delta
	if _door_timer > 0.0:
		return
	_door_timer = 0.12
	if _current_speed() <= 0.0 or _idle_timer > 0.0:
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	for n: Node in get_tree().get_nodes_in_group("doors"):
		var door := n as Door
		if door.is_open or absf(door.global_position.y - global_position.y) > 1.5:
			continue
		var to := door.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 1.8:
			continue
		var ahead := dist < 1.0 or hv.length() < 0.2 or hv.normalized().dot(to.normalized()) > 0.1
		if not ahead:
			continue
		var t := door.monster_open(global_position)
		if t > 0.0:
			_lock(t * (1.2 if state == State.CHASE else 1.0), MonsterBody.Pose.BASH)


# ============================================================ sons et rendu

func _on_step(running: bool) -> void:
	var vol := 1.0 if running else -5.0
	if _occluded:
		vol -= 6.0
	AudioManager.play_3d("step_monster_%d" % randi_range(1, 2), global_position, vol, randf_range(0.9, 1.1), 32.0, 3.5)


func _growl() -> void:
	AudioManager.play_3d("monster_growl", global_position + Vector3(0, 2.0, 0), -2.0 - (6.0 if _occluded else 0.0), randf_range(0.85, 1.1), 26.0, 3.0)


func _update_audio(delta: float) -> void:
	_occl_timer -= delta
	if _occl_timer <= 0.0:
		_occl_timer = 0.3
		var q := PhysicsRayQueryParameters3D.create(player.eye_position(), global_position + Vector3(0, 1.9, 0), Layers.WORLD | Layers.DOORS)
		_occluded = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		var base := 2.0 if state == State.CHASE else -3.0
		_breath.volume_db = base - (9.0 if _occluded else 0.0)
		_breath.attenuation_filter_cutoff_hz = 1200.0 if _occluded else 5000.0
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(9.0, 22.0)
		if state == State.PATROL or state == State.SEARCH:
			_growl()


func _update_lod() -> void:
	var d := global_position.distance_to(player.global_position)
	var near := d < 32.0
	body.visible = near
	body.anim_enabled = near
	body.eye_light.visible = d < 12.0


func _on_enrage() -> void:
	enraged = true
	retreat_until = 0.0
	last_near_time = -999.0
	if state != State.DORMANT:
		AudioManager.play_2d("monster_scream", -2.0, 0.8)
		Events.camera_shake.emit(0.4)


## Place le monstre loin du joueur (chargement de sauvegarde, réveil).
func pick_far_spawn(from: Vector3) -> Vector3:
	var best := patrol_points[0] if not patrol_points.is_empty() else Vector3.ZERO
	var best_d := -1.0
	for p: Vector3 in patrol_points:
		var d := p.distance_to(from)
		if absf(p.y - from.y) > 2.0:
			d *= 0.6
		if d > best_d:
			best_d = d
			best = p
	return best
