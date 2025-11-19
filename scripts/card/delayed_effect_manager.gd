class_name DelayedEffectManager
extends RefCounted

var card_interface: CardSpriteInterface

var _pending_effects: Array[Dictionary] = []
var _active_fields: Array[Dictionary] = []

func _init(interface: CardSpriteInterface = null):
	card_interface = interface

func set_card_interface(interface: CardSpriteInterface):
	card_interface = interface

func queue_card_effect(card: Card, source_sprite: Sprite, target: Variant, metadata: Dictionary = {}):
	if not card or not source_sprite:
		return
	var entry = {
		"card": card.duplicate_card(),
		"source_sprite": source_sprite,
		"source_position": source_sprite.hex_position,
		"target": target,
		"metadata": metadata.duplicate(true)
	}
	_pending_effects.append(entry)

func has_pending_effects() -> bool:
	return _pending_effects.size() > 0

func resolve_pending_effects(game_map: GameMap, terrain_manager: TerrainManager, all_sprites: Array[Sprite]):
	if not card_interface:
		return
	if _pending_effects.is_empty():
		return
	var pending = _pending_effects.duplicate(true)
	_pending_effects.clear()
	for entry in pending:
		var source_sprite: Sprite = entry.get("source_sprite", null)
		var card: Card = entry.get("card", null)
		if not card or not source_sprite:
			continue
		if not is_instance_valid(source_sprite) or not source_sprite.is_alive:
			continue
		var target = entry.get("target")
		card_interface.apply_card_effect(card, source_sprite, target, game_map, terrain_manager, all_sprites)

func register_field_effect(field: Dictionary):
	if field.is_empty():
		return
	var center_coord = field.get("center_coord", null)
	if center_coord == null:
		return
	var duration = field.get("duration_turns", 0)
	if duration <= 0:
		return
	var stored = field.duplicate(true)
	stored["remaining_turns"] = duration
	_active_fields.append(stored)

func tick_active_fields(all_sprites: Array[Sprite], game_map: GameMap, terrain_manager: TerrainManager):
	if _active_fields.is_empty():
		return
	var ongoing: Array[Dictionary] = []
	for field in _active_fields:
		var remaining: int = field.get("remaining_turns", 0)
		if remaining <= 0:
			_handle_field_expire(field, terrain_manager)
			continue
		_apply_field_tick(field, all_sprites)
		remaining -= 1
		field["remaining_turns"] = remaining
		if remaining > 0:
			ongoing.append(field)
		else:
			_handle_field_expire(field, terrain_manager)
	_active_fields = ongoing

func _apply_field_tick(field: Dictionary, all_sprites: Array[Sprite]):
	var damage: int = field.get("damage", 0)
	if damage <= 0:
		return
	var center: Vector2i = field.get("center_coord", null)
	if center == null:
		return
	var radius: int = field.get("radius", 0)
	var alignment: String = field.get("target_alignment", "all")
	var owner_id: int = field.get("owner_player_id", -1)
	var affected_tiles = HexGrid.get_hexes_in_range(center, radius)
	for sprite in all_sprites:
		if not sprite or not sprite.is_alive:
			continue
		if sprite.hex_position not in affected_tiles:
			continue
		if not _matches_alignment(sprite, owner_id, alignment):
			continue
		sprite.take_damage(damage)

func _handle_field_expire(field: Dictionary, terrain_manager: TerrainManager):
	var expire_actions = field.get("expire_actions", [])
	if expire_actions.is_empty():
		return
	for action in expire_actions:
		var action_type: String = action.get("action", "")
		match action_type:
			"terrain_change":
				var coord: Vector2i = action.get("coord", null)
				if coord == null:
					continue
				var terrain_type = action.get("terrain_type", "normal")
				var set_height = action.get("set_height", -1)
				var height_delta = action.get("height_delta", 0)
				var owner_id = action.get("owner_player_id", -1)
				terrain_manager.request_terrain_change(owner_id, coord, _terrain_type_from_string(terrain_type), set_height, -1, height_delta)

func _matches_alignment(sprite: Sprite, owner_id: int, alignment: String) -> bool:
	match alignment:
		"ally", "allies":
			return owner_id >= 0 and sprite.owner_player_id == owner_id
		"enemy", "enemies":
			return owner_id >= 0 and sprite.owner_player_id != owner_id
		"self":
			return owner_id >= 0 and sprite.owner_player_id == owner_id
		_:
			return true

func _terrain_type_from_string(type_name: String) -> TerrainTile.TerrainType:
	var lowered = type_name.to_lower()
	match lowered:
		"water":
			return TerrainTile.TerrainType.WATER
		"forest":
			return TerrainTile.TerrainType.FOREST
		"bedrock":
			return TerrainTile.TerrainType.BEDROCK
		"scorched":
			return TerrainTile.TerrainType.SCORCHED
		_:
			return TerrainTile.TerrainType.NORMAL

