class_name Inventory
extends RefCounted
## Inventaire simple : identifiant d'objet -> quantité.

signal changed

var _items: Dictionary = {}


func add(id: String, amount: int = 1) -> void:
	_items[id] = count(id) + amount
	changed.emit()


func remove(id: String, amount: int = 1) -> bool:
	var current := count(id)
	if current < amount:
		return false
	if current == amount:
		_items.erase(id)
	else:
		_items[id] = current - amount
	changed.emit()
	return true


func has_item(id: String) -> bool:
	return count(id) > 0


func count(id: String) -> int:
	if not _items.has(id):
		return 0
	return int(_items[id])


func ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _items.keys():
		out.append(str(k))
	return out


func clear() -> void:
	_items.clear()
	changed.emit()


func to_dict() -> Dictionary:
	return _items.duplicate()


func from_dict(d: Dictionary) -> void:
	_items.clear()
	for k: Variant in d.keys():
		var n := int(d[k])
		if n > 0:
			_items[str(k)] = n
	changed.emit()
