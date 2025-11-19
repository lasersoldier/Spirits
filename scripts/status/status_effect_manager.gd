class_name StatusEffectManager
extends RefCounted

static var _instance: StatusEffectManager

var _statuses_by_sprite: Dictionary = {}  # key: int(instance_id) -> {"sprite": Sprite, "statuses": Array}

func _init():
	_instance = self

static func get_instance() -> StatusEffectManager:
	return _instance

func _get_entry(sprite: Sprite) -> Dictionary:
	if not sprite:
		return {}
	var key = sprite.get_instance_id()
	if not _statuses_by_sprite.has(key):
		_statuses_by_sprite[key] = {
			"sprite": sprite,
			"statuses": []
		}
	return _statuses_by_sprite[key]

func apply_status(sprite: Sprite, status_def: Dictionary):
	if not sprite or status_def.is_empty():
		return
	var normalized = _normalize_status_def(status_def)
	if normalized.is_empty():
		return
	var entry = _get_entry(sprite)
	var statuses: Array = entry.get("statuses", [])
	var status_id: String = normalized.get("id", "")
	var max_stack: int = normalized.get("max_stack", -1)
	if max_stack > 0 and not status_id.is_empty():
		var current_count = 0
		for status in statuses:
			if status.get("id", "") == status_id:
				current_count += 1
		if current_count >= max_stack:
			return
	statuses.append(normalized)
	entry["statuses"] = statuses
	_statuses_by_sprite[sprite.get_instance_id()] = entry

func clear_statuses(sprite: Sprite):
	if not sprite:
		return
	_statuses_by_sprite.erase(sprite.get_instance_id())

func advance_round():
	var keys = _statuses_by_sprite.keys()
	for key in keys:
		var entry = _statuses_by_sprite.get(key, {})
		if entry.is_empty():
			continue
		var statuses: Array = entry.get("statuses", [])
		var updated: Array = []
		for status in statuses:
			var duration: int = status.get("duration", -1)
			if duration > 0:
				duration -= 1
				status["duration"] = duration
			if duration != 0:
				updated.append(status)
		if updated.is_empty():
			_statuses_by_sprite.erase(key)
		else:
			entry["statuses"] = updated
			_statuses_by_sprite[key] = entry

func get_movement_bonus(sprite: Sprite) -> int:
	var total := 0
	var entry = _get_entry(sprite)
	for status in entry.get("statuses", []):
		var modifiers: Dictionary = status.get("modifiers", {})
		if modifiers.has("movement_range_bonus"):
			total += int(modifiers.get("movement_range_bonus", 0))
		elif status.get("id", "") == "movement_bonus":
			total += int(status.get("magnitude", 0))
	return total

func modify_incoming_damage(sprite: Sprite, damage: int) -> int:
	var entry = _get_entry(sprite)
	var final_damage = damage
	for status in entry.get("statuses", []):
		var modifiers: Dictionary = status.get("modifiers", {})
		if modifiers.has("damage_taken_bonus"):
			final_damage += int(modifiers.get("damage_taken_bonus", 0))
		elif status.get("id", "") == "vulnerable":
			final_damage += int(status.get("magnitude", 0))
	return max(0, final_damage)

func _normalize_status_def(status_def: Dictionary) -> Dictionary:
	var payload := status_def.duplicate(true)
	if payload.has("status"):
		payload = payload.get("status").duplicate(true)
	var status_id: String = payload.get("status_id", payload.get("status_type", ""))
	if status_id.is_empty():
		return {}
	var duration = payload.get("duration", payload.get("duration_turns", 0))
	if duration == 0:
		duration = 1
	var modifiers: Dictionary = payload.get("modifiers", {})
	var normalized = {
		"id": status_id,
		"duration": duration,
		"modifiers": modifiers.duplicate(true),
		"magnitude": payload.get("magnitude", 0),
		"max_stack": payload.get("max_stack", -1)
	}
	if payload.has("source_player_id"):
		normalized["source_player_id"] = payload.get("source_player_id")
	return normalized

