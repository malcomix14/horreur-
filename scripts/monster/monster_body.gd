class_name MonsterBody
extends Node3D
## Modèle procédural du Veilleur (Gaspard) : 2,3 m, maigre, voûté, bras trop longs,
## yeux sans paupières qui accrochent la lumière, mâchoire décrochée.
## Squelette de pivots Node3D animé par code (marche, course, cri, saisie, fouille).
## Repère : pieds à l'origine, regarde vers -Z.

signal stepped(running: bool)

enum Pose { WALK, IDLE, SCREAM, GRAB, BASH, SEARCH, STATIC, CRAWL }

static var _meshes: Dictionary = {}

var pose: Pose = Pose.IDLE
var speed: float = 0.0
var run_blend: float = 0.0
var jaw_open: float = 0.1
var anim_enabled: bool = true

var root_bone: Node3D
var hips: Node3D
var spine: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var jaw: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var coat_tails: Array[Node3D] = []
var fingers: Array[Node3D] = []
var eye_light: OmniLight3D

var _phase: float = 0.0
var _last_sin: float = 0.0
var _t: float = 0.0
var _twitch_timer: float = 1.0
var _twitch: Vector3 = Vector3.ZERO
var _twitch_target: Vector3 = Vector3.ZERO
var _look_yaw: float = 0.0


func _ready() -> void:
	_build()


func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key] as Mesh
	var m: Mesh
	match key:
		"upper_arm":
			var c := CapsuleMesh.new()
			c.radius = 0.042
			c.height = 0.56
			c.radial_segments = 8
			c.rings = 2
			m = c
		"forearm":
			var c2 := CapsuleMesh.new()
			c2.radius = 0.034
			c2.height = 0.54
			c2.radial_segments = 8
			c2.rings = 2
			m = c2
		"thigh":
			var c3 := CapsuleMesh.new()
			c3.radius = 0.058
			c3.height = 0.6
			c3.radial_segments = 8
			c3.rings = 2
			m = c3
		"shin":
			var c4 := CapsuleMesh.new()
			c4.radius = 0.045
			c4.height = 0.58
			c4.radial_segments = 8
			c4.rings = 2
			m = c4
		"finger":
			var cy := CylinderMesh.new()
			cy.top_radius = 0.009
			cy.bottom_radius = 0.004
			cy.height = 0.17
			cy.radial_segments = 5
			cy.rings = 1
			m = cy
		_:
			m = BoxMesh.new()
	_meshes[key] = m
	return m


func _part(parent: Node3D, mesh: Mesh, mat: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Assets.mat(mat)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _batch(parent: Node3D, b: MeshBatcher) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(func(k: String) -> Material: return Assets.mat(k))
	parent.add_child(mi)
	return mi


func _bone(parent: Node3D, pos: Vector3, bone_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = bone_name
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	root_bone = _bone(self, Vector3.ZERO, "Root")
	hips = _bone(root_bone, Vector3(0, 1.14, 0), "Hips")
	var pb := MeshBatcher.new()
	pb.add_box("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), Vector3(0.3, 0.16, 0.18))
	pb.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), Vector3(0.31, 0.03, 0.19))
	_batch(hips, pb)
	spine = _bone(hips, Vector3(0, 0.06, 0), "Spine")
	var sb := MeshBatcher.new()
	sb.add_cylinder("cloth_black", Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 0.72)), Vector3(0, 0.0, 0)), 0.12, 0.135, 0.36, 10)
	sb.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.092)), Vector3(0.08, 0.3, 0.012))
	for i: int in range(3):
		sb.add_box("bone", Transform3D(Basis.IDENTITY, Vector3(0, 0.1 + float(i) * 0.08, -0.098)), Vector3(0.022, 0.03, 0.01), Color(0.42, 0.41, 0.37))
	for i: int in range(4):
		sb.add_sphere("cloth_black", Vector3(0, 0.05 + float(i) * 0.08, 0.1), Vector3(0.022, 0.022, 0.018), Color.WHITE, 6, 4)
	_batch(spine, sb)
	chest = _bone(spine, Vector3(0, 0.34, 0), "Chest")
	var cb := MeshBatcher.new()
	# Veste noire en lambeaux, ouverte sur une cage thoracique décharnée.
	cb.add_cylinder("cloth_black", Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 0.62)), Vector3(0, 0.0, 0)), 0.14, 0.2, 0.44, 12)
	cb.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.105)), Vector3(0.13, 0.36, 0.012))
	for i: int in range(5):
		var ry := 0.07 + float(i) * 0.065
		var rw := 0.12 - absf(float(i) - 1.5) * 0.012
		cb.add_box("bone", Transform3D(Basis(Vector3.BACK, 0.12 if i % 2 == 0 else -0.08), Vector3(0, ry, -0.113)), Vector3(rw, 0.014, 0.012), Color(0.42, 0.41, 0.37))
	cb.add_box("bone", Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.116)), Vector3(0.016, 0.34, 0.012), Color(0.38, 0.37, 0.33))
	cb.add_box("cloth_black", Transform3D(Basis(Vector3.BACK, 0.12), Vector3(0.085, 0.22, -0.118)), Vector3(0.05, 0.44, 0.02))
	cb.add_box("cloth_black", Transform3D(Basis(Vector3.BACK, -0.12), Vector3(-0.085, 0.22, -0.118)), Vector3(0.05, 0.44, 0.02))
	cb.add_box("cloth_black", Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.44, 0.07)), Vector3(0.22, 0.12, 0.06))
	for i: int in range(5):
		cb.add_sphere("cloth_black", Vector3(0, 0.04 + float(i) * 0.08, 0.125), Vector3(0.024, 0.024, 0.02), Color.WHITE, 6, 4)
	# Queue-de-pie en lambeaux (dos) et col.
	cb.add_box("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0.13)), Vector3(0.42, 0.5, 0.03))
	cb.add_sphere("cloth_black", Vector3(0.2, 0.39, 0.0), Vector3(0.08, 0.06, 0.09), Color.WHITE, 8, 5)
	cb.add_sphere("cloth_black", Vector3(-0.2, 0.39, 0.0), Vector3(0.08, 0.06, 0.09), Color.WHITE, 8, 5)
	cb.add_box("cloth_black", Transform3D(Basis(Vector3.FORWARD, 0.25), Vector3(-0.15, 0.25, -0.1)), Vector3(0.1, 0.4, 0.02))
	cb.add_box("cloth_black", Transform3D(Basis(Vector3.FORWARD, -0.25), Vector3(0.15, 0.25, -0.1)), Vector3(0.1, 0.4, 0.02))
	_batch(chest, cb)
	for i: int in range(3):
		var tail := _bone(chest, Vector3(-0.12 + float(i) * 0.12, -0.05, 0.14), "Tail%d" % i)
		var tb := MeshBatcher.new()
		var tl := 0.75 + 0.12 * float(i % 2)
		tb.add_box("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, -tl * 0.5, 0)), Vector3(0.11, tl, 0.012))
		tb.add_box("cloth_black", Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0.02, -tl - 0.05, 0)), Vector3(0.05, 0.14, 0.01))
		_batch(tail, tb)
		coat_tails.append(tail)
	# Cou et tête.
	neck = _bone(chest, Vector3(0, 0.44, -0.02), "Neck")
	var nb := MeshBatcher.new()
	nb.add_cylinder("skin", Transform3D.IDENTITY, 0.042, 0.036, 0.22, 8)
	nb.add_cylinder("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), 0.075, 0.06, 0.1, 10)
	nb.add_cylinder("skin_dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), 0.04, 0.04, 0.01, 8, Color.WHITE, false)
	_batch(neck, nb)
	head = _bone(neck, Vector3(0, 0.22, 0), "Head")
	build_head(head)
	jaw = head.get_node("Jaw") as Node3D
	# Bras.
	shoulder_l = _bone(chest, Vector3(0.22, 0.38, 0), "ShoulderL")
	shoulder_r = _bone(chest, Vector3(-0.22, 0.38, 0), "ShoulderR")
	var arm_bones: Array[Node3D] = [shoulder_l, shoulder_r]
	for s: int in range(2):
		var sh := arm_bones[s]
		_part(sh, _mesh("upper_arm"), "cloth_black", Vector3(0, -0.26, 0))
		var el := _bone(sh, Vector3(0, -0.53, 0), "Elbow")
		_part(el, _mesh("forearm"), "skin", Vector3(0, -0.25, 0))
		var eb := MeshBatcher.new()
		eb.add_cylinder("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), 0.05, 0.06, 0.14, 7)
		_batch(el, eb)
		var hand := _bone(el, Vector3(0, -0.52, 0), "Hand")
		var hb := MeshBatcher.new()
		hb.add_box("skin", Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0)), Vector3(0.07, 0.1, 0.03))
		_batch(hand, hb)
		for f: int in range(4):
			var fp := _bone(hand, Vector3(-0.027 + float(f) * 0.018, -0.1, 0), "Finger%d" % f)
			_part(fp, _mesh("finger"), "skin", Vector3(0, -0.085, 0))
			var nail := MeshBatcher.new()
			nail.add_cylinder("teeth", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.17, 0)), 0.006, 0.0, 0.035, 4)
			_batch(fp, nail)
			fp.rotation.x = 0.35
			fingers.append(fp)
		var th := _bone(hand, Vector3(0.04 if s == 0 else -0.04, -0.04, -0.01), "Thumb")
		_part(th, _mesh("finger"), "skin", Vector3(0, -0.07, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		th.rotation.z = 0.6 if s == 0 else -0.6
		if s == 0:
			elbow_l = el
			hand_l = hand
		else:
			elbow_r = el
			hand_r = hand
	# Jambes.
	leg_l = _bone(hips, Vector3(0.1, -0.03, 0), "LegL")
	leg_r = _bone(hips, Vector3(-0.1, -0.03, 0), "LegR")
	var leg_bones: Array[Node3D] = [leg_l, leg_r]
	for s2: int in range(2):
		var lg := leg_bones[s2]
		_part(lg, _mesh("thigh"), "cloth_black", Vector3(0, -0.28, 0))
		var kn := _bone(lg, Vector3(0, -0.55, 0), "Knee")
		_part(kn, _mesh("shin"), "cloth_black", Vector3(0, -0.27, 0))
		var kb := MeshBatcher.new()
		kb.add_cylinder("cloth_black", Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)), 0.065, 0.05, 0.12, 7)
		kb.add_cylinder("skin", Transform3D(Basis.IDENTITY, Vector3(0, -0.53, 0)), 0.035, 0.035, 0.06, 6)
		kb.add_sphere("cloth_black", Vector3(0, 0.0, -0.04), Vector3(0.045, 0.05, 0.035), Color.WHITE, 6, 4)
		_batch(kn, kb)
		var ft := _bone(kn, Vector3(0, -0.53, 0), "Foot")
		var fb := MeshBatcher.new()
		fb.add_box("skin", Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.06)), Vector3(0.07, 0.04, 0.22))
		for t: int in range(3):
			fb.add_box("skin", Transform3D(Basis(Vector3.UP, (float(t) - 1.0) * 0.12), Vector3(-0.02 + float(t) * 0.02, -0.03, -0.2)), Vector3(0.016, 0.018, 0.1))
		_batch(ft, fb)
		if s2 == 0:
			knee_l = kn
			foot_l = ft
		else:
			knee_r = kn
			foot_r = ft
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(0.85, 0.9, 1.0)
	eye_light.light_energy = 0.35
	eye_light.omni_range = 1.3
	eye_light.shadow_enabled = false
	eye_light.light_specular = 0.0
	eye_light.position = Vector3(0, 0.1, -0.3)
	head.add_child(eye_light)
	_set_no_shadow(self)


## Tête seule (réutilisée par les screamers : visage dans le miroir, flash...).
static func build_head(parent: Node3D) -> void:
	var b := MeshBatcher.new()
	# Crâne allongé, joues creusées, orbites profondes, yeux sans paupières, sourire trop large.
	b.add_sphere("skin", Vector3(0, 0.11, 0.015), Vector3(0.108, 0.16, 0.13), Color.WHITE, 14, 10)
	b.add_sphere("skin", Vector3(0, 0.155, -0.075), Vector3(0.095, 0.035, 0.05), Color(0.8, 0.8, 0.78), 10, 6)
	b.add_sphere("skin_dark", Vector3(0.062, 0.05, -0.07), Vector3(0.03, 0.045, 0.04), Color.WHITE, 8, 5)
	b.add_sphere("skin_dark", Vector3(-0.062, 0.05, -0.07), Vector3(0.03, 0.045, 0.04), Color.WHITE, 8, 5)
	b.add_sphere("black", Vector3(0.045, 0.118, -0.098), Vector3(0.038, 0.034, 0.025), Color.WHITE, 8, 5)
	b.add_sphere("black", Vector3(-0.045, 0.118, -0.098), Vector3(0.038, 0.034, 0.025), Color.WHITE, 8, 5)
	b.add_sphere("eye_white", Vector3(0.045, 0.117, -0.108), Vector3(0.026, 0.026, 0.022), Color.WHITE, 10, 6)
	b.add_sphere("eye_white", Vector3(-0.045, 0.117, -0.108), Vector3(0.026, 0.026, 0.022), Color.WHITE, 10, 6)
	b.add_sphere("black", Vector3(0.047, 0.118, -0.128), Vector3(0.011, 0.011, 0.004), Color.WHITE, 6, 4)
	b.add_sphere("black", Vector3(-0.043, 0.118, -0.128), Vector3(0.011, 0.011, 0.004), Color.WHITE, 6, 4)
	b.add_sphere("eye_glow", Vector3(0.047, 0.118, -0.131), Vector3(0.0045, 0.0045, 0.002), Color.WHITE, 6, 4)
	b.add_sphere("eye_glow", Vector3(-0.043, 0.118, -0.131), Vector3(0.0045, 0.0045, 0.002), Color.WHITE, 6, 4)
	b.add_sphere("black", Vector3(0, 0.075, -0.118), Vector3(0.014, 0.018, 0.012), Color.WHITE, 6, 4)
	b.add_sphere("mouth", Vector3(0, 0.022, -0.09), Vector3(0.078, 0.028, 0.04), Color.WHITE, 12, 6)
	for i: int in range(12):
		var a := (float(i) - 5.5) / 5.5
		b.add_cylinder("teeth", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(a * 0.07, 0.042, -0.122 + a * a * 0.045)), 0.0065, 0.0, 0.026 + 0.008 * (1.0 - absf(a)), 4)
	for i: int in range(6):
		var hx := -0.07 + float(i) * 0.028
		b.add_box("cloth_black", Transform3D(Basis(Vector3.FORWARD, (float(i) - 2.5) * 0.08), Vector3(hx, 0.02, 0.1)), Vector3(0.012, 0.32, 0.01))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(func(k: String) -> Material: return Assets.mat(k))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var jaw_node := Node3D.new()
	jaw_node.name = "Jaw"
	jaw_node.position = Vector3(0, 0.03, -0.02)
	parent.add_child(jaw_node)
	var jb := MeshBatcher.new()
	jb.add_sphere("skin", Vector3(0, -0.035, -0.055), Vector3(0.075, 0.03, 0.07), Color.WHITE, 10, 6)
	jb.add_sphere("mouth", Vector3(0, -0.012, -0.06), Vector3(0.065, 0.012, 0.055), Color.WHITE, 10, 4)
	for i: int in range(10):
		var a2 := (float(i) - 4.5) / 4.5
		jb.add_cylinder("teeth", Transform3D(Basis.IDENTITY, Vector3(a2 * 0.06, -0.02, -0.112 + a2 * a2 * 0.04)), 0.0055, 0.0, 0.024, 4)
	var jmi := MeshInstance3D.new()
	jmi.mesh = jb.build(func(k: String) -> Material: return Assets.mat(k))
	jmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jaw_node.add_child(jmi)
	jaw_node.rotation.x = -0.35


func _set_no_shadow(n: Node) -> void:
	for c: Node in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_set_no_shadow(c)


func set_look_yaw(v: float) -> void:
	_look_yaw = v


# ============================================================ animation procédurale

func _process(delta: float) -> void:
	if not anim_enabled or not is_visible_in_tree():
		return
	animate(delta)


func animate(delta: float) -> void:
	_t += delta
	var target_run := clampf((speed - 2.2) / 1.6, 0.0, 1.0)
	run_blend = lerpf(run_blend, target_run, clampf(delta * 4.0, 0.0, 1.0))
	var moving := speed > 0.15 and (pose == Pose.WALK or pose == Pose.SEARCH)
	var freq := 0.35 + speed * 0.5
	if moving:
		_phase += delta * freq * TAU
	var s := sin(_phase)
	var c := cos(_phase)
	if moving:
		if (s >= 0.0) != (_last_sin >= 0.0):
			stepped.emit(run_blend > 0.5)
		_last_sin = s
	var leg_amp := lerpf(0.42, 0.85, run_blend) if moving else 0.0
	var knee_amp := lerpf(0.65, 1.3, run_blend) if moving else 0.0
	# Tics nerveux de la tête.
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(0.6, 2.8)
		_twitch_target = Vector3(randf_range(-0.25, 0.25), randf_range(-0.4, 0.4), randf_range(-0.45, 0.45)) if randf() < 0.7 else Vector3.ZERO
	_twitch = _twitch.lerp(_twitch_target, clampf(delta * 18.0, 0.0, 1.0))
	var breath := sin(_t * 1.7)
	# Valeurs de base (marche voûtée).
	var hunch := lerpf(-0.32, -0.62, run_blend)
	var spine_x := hunch
	var chest_x := -0.18 + breath * 0.03
	var neck_x := 0.12
	var head_x := 0.0
	var head_tilt := 0.1
	var head_y := _look_yaw
	var head_z := 0.0
	var sh_l := Vector3(-s * leg_amp * 0.7, 0.0, 0.12)
	var sh_r := Vector3(s * leg_amp * 0.7, 0.0, -0.12)
	var el_l := 0.35 + maxf(0.0, s) * 0.3
	var el_r := 0.35 + maxf(0.0, -s) * 0.3
	var lg_l := s * leg_amp
	var lg_r := -s * leg_amp
	var kn_l := -maxf(0.0, sin(_phase + 1.3)) * knee_amp - 0.08
	var kn_r := -maxf(0.0, sin(_phase + 1.3 + PI)) * knee_amp - 0.08
	var bob := absf(c) * 0.06 * clampf(speed, 0.0, 1.0)
	var jaw_target := 0.25 + jaw_open * 0.6
	var finger_curl := 0.35
	match pose:
		Pose.WALK:
			if run_blend > 0.2:
				# Course : bras tendus vers l'avant, prêts à saisir.
				sh_l = sh_l.lerp(Vector3(1.15 - s * 0.35, 0.0, 0.25), run_blend)
				sh_r = sh_r.lerp(Vector3(1.15 + s * 0.35, 0.0, -0.25), run_blend)
				el_l = lerpf(el_l, 0.2, run_blend)
				el_r = lerpf(el_r, 0.2, run_blend)
				jaw_target = lerpf(jaw_target, 0.7 + 0.15 * sin(_t * 20.0), run_blend)
				finger_curl = 0.1
		Pose.IDLE:
			sh_l = Vector3(0.05 + breath * 0.03, 0.0, 0.1)
			sh_r = Vector3(0.05 + breath * 0.03, 0.0, -0.1)
			head_y += sin(_t * 0.5) * 0.3
		Pose.SEARCH:
			head_y += sin(_t * 1.3) * 0.9
			head_z += 0.5 * sin(_t * 0.7)
			spine_x = hunch - 0.15
		Pose.SCREAM:
			spine_x = -0.1
			chest_x = 0.15 + sin(_t * 30.0) * 0.03
			neck_x = -0.1
			head_tilt = -0.6
			jaw_target = 1.25
			sh_l = Vector3(0.3, 0.0, 1.1 + sin(_t * 25.0) * 0.05)
			sh_r = Vector3(0.3, 0.0, -1.1 - sin(_t * 25.0) * 0.05)
			el_l = 0.6
			el_r = 0.6
			finger_curl = -0.2
			lg_l = 0.1
			lg_r = -0.1
			bob = 0.0
		Pose.GRAB:
			spine_x = -1.0
			chest_x = -0.25
			neck_x = 0.2
			head_tilt = -0.35
			jaw_target = 1.3
			sh_l = Vector3(1.45, 0.0, -0.15)
			sh_r = Vector3(1.45, 0.0, 0.15)
			el_l = 0.5
			el_r = 0.5
			finger_curl = 0.8
			bob = 0.0
		Pose.BASH:
			spine_x = -0.45
			sh_r = Vector3(1.6 + sin(_t * 18.0) * 0.4, 0.0, -0.2)
			el_r = 0.1
			jaw_target = 0.9
		Pose.CRAWL:
			spine_x = -1.35
			chest_x = -0.2
			neck_x = 0.4
			head_tilt = 0.2
			sh_l = Vector3(1.4 - s * 0.5, 0.0, 0.2)
			sh_r = Vector3(1.4 + s * 0.5, 0.0, -0.2)
			lg_l = 0.9 + s * 0.4
			lg_r = 0.9 - s * 0.4
			kn_l = 1.6
			kn_r = 1.6
			bob = -0.62
		Pose.STATIC:
			sh_l = Vector3(0.0, 0.0, 0.08)
			sh_r = Vector3(0.0, 0.0, -0.08)
			el_l = 0.15
			el_r = 0.15
			lg_l = 0.0
			lg_r = 0.0
			kn_l = -0.05
			kn_r = -0.05
			head_tilt = -0.15
			head_z = 0.35
	# La tête compense l'inclinaison du dos : le regard reste braqué devant lui.
	head_x = -(spine_x + chest_x + neck_x) + head_tilt
	var k := clampf(delta * 12.0, 0.0, 1.0)
	root_bone.position.y = lerpf(root_bone.position.y, bob, k)
	spine.rotation.x = lerpf(spine.rotation.x, spine_x, k)
	chest.rotation.x = lerpf(chest.rotation.x, chest_x, k)
	neck.rotation.x = lerpf(neck.rotation.x, neck_x, k)
	head.rotation = head.rotation.lerp(Vector3(head_x, head_y, head_z) + _twitch, k)
	shoulder_l.rotation = shoulder_l.rotation.lerp(sh_l, k)
	shoulder_r.rotation = shoulder_r.rotation.lerp(sh_r, k)
	elbow_l.rotation.x = lerpf(elbow_l.rotation.x, el_l, k)
	elbow_r.rotation.x = lerpf(elbow_r.rotation.x, el_r, k)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, lg_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lg_r, k)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, kn_l, k)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, kn_r, k)
	foot_l.rotation.x = -(lg_l + kn_l) * 0.6
	foot_r.rotation.x = -(lg_r + kn_r) * 0.6
	jaw.rotation.x = lerpf(jaw.rotation.x, -jaw_target, clampf(delta * 16.0, 0.0, 1.0))
	for f: Node3D in fingers:
		f.rotation.x = lerpf(f.rotation.x, finger_curl, k)
	for i: int in range(coat_tails.size()):
		coat_tails[i].rotation.x = 0.15 + run_blend * 0.9 + sin(_t * (3.0 + speed) + float(i)) * (0.05 + 0.1 * run_blend)
		coat_tails[i].rotation.z = sin(_t * 2.1 + float(i) * 1.7) * 0.06


static func clear_cache() -> void:
	_meshes.clear()
