class_name ItemVisuals
extends RefCounted
## Petits modèles 3D des objets ramassables, construits à partir de primitives.

static var _cache: Dictionary = {}


static func mesh_for(item_id: String) -> ArrayMesh:
	if _cache.has(item_id):
		return _cache[item_id] as ArrayMesh
	var b := MeshBatcher.new()
	match item_id:
		"key_iron":
			_key(b, "iron_black", 1.0)
		"key_silver":
			_key(b, "metal", 0.9)
		"key_brass":
			_key(b, "brass", 0.75)
		"key_bone":
			_key(b, "bone", 1.05)
		"battery":
			b.add_cylinder("metal", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.03, 0.0, 0.0)), 0.016, 0.016, 0.06, 10, Color(0.35, 0.3, 0.25))
			b.add_cylinder("brass", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.03, 0.0, 0.0)), 0.006, 0.006, 0.006, 6)
		"matches":
			b.add_box("wood_light", Transform3D(Basis.IDENTITY, Vector3(0, 0.009, 0)), Vector3(0.055, 0.018, 0.036), Color(0.6, 0.2, 0.15))
			b.add_box("paper", Transform3D(Basis.IDENTITY, Vector3(0, 0.0185, 0)), Vector3(0.045, 0.002, 0.026), Color(0.9, 0.85, 0.6))
		"fuse":
			b.add_cylinder("porcelain", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.035, 0.018, 0)), 0.016, 0.016, 0.07, 10)
			b.add_cylinder("brass", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.045, 0.018, 0)), 0.018, 0.018, 0.012, 10)
			b.add_cylinder("brass", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.033, 0.018, 0)), 0.018, 0.018, 0.012, 10)
		"crank":
			b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 0.006, 0)), Vector3(0.12, 0.012, 0.014))
			b.add_cylinder("brass", Transform3D(Basis.IDENTITY, Vector3(0.055, 0.0, 0)), 0.006, 0.006, 0.05, 6)
			b.add_cylinder("wood_dark", Transform3D(Basis.IDENTITY, Vector3(-0.055, 0.0, 0)), 0.01, 0.01, 0.04, 8)
		"register":
			b.add_box("leather", Transform3D(Basis.IDENTITY, Vector3(0, 0.025, 0)), Vector3(0.24, 0.05, 0.32), Color(0.35, 0.05, 0.04))
			b.add_box("paper", Transform3D(Basis.IDENTITY, Vector3(0.006, 0.025, 0)), Vector3(0.235, 0.042, 0.3), Color(0.8, 0.75, 0.6))
			b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 0.051, 0)), Vector3(0.06, 0.002, 0.06))
		"flashlight":
			b.add_cylinder("iron_black", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.1, 0.025, 0)), 0.018, 0.018, 0.17, 10)
			b.add_cylinder("metal", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.07, 0.025, 0)), 0.03, 0.02, 0.05, 10)
			b.add_cylinder("bulb", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.1205, 0.025, 0)), 0.026, 0.026, 0.002, 10)
		_:
			b.add_box("brass", Transform3D.IDENTITY, Vector3(0.06, 0.06, 0.06))
	var mesh := b.build(func(k: String) -> Material: return Assets.mat(k))
	_cache[item_id] = mesh
	return mesh


static func _key(b: MeshBatcher, mat: String, s: float) -> void:
	var y := 0.006
	b.add_cylinder(mat, Transform3D(Basis.IDENTITY, Vector3(-0.045 * s, 0.0, 0)), 0.018 * s, 0.018 * s, 0.01, 12)
	b.add_cylinder("black", Transform3D(Basis.IDENTITY, Vector3(-0.045 * s, 0.0005, 0)), 0.009 * s, 0.009 * s, 0.0102, 10)
	b.add_box(mat, Transform3D(Basis.IDENTITY, Vector3(0.01 * s, y, 0)), Vector3(0.08 * s, 0.009, 0.009))
	b.add_box(mat, Transform3D(Basis.IDENTITY, Vector3(0.042 * s, y, 0.012 * s)), Vector3(0.012 * s, 0.009, 0.02 * s))
	b.add_box(mat, Transform3D(Basis.IDENTITY, Vector3(0.026 * s, y, 0.01 * s)), Vector3(0.008 * s, 0.009, 0.016 * s))


static func clear_cache() -> void:
	_cache.clear()
