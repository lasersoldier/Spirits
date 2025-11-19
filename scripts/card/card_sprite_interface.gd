class_name CardSpriteInterface
extends RefCounted

# 卡牌库引用
var card_library: CardLibrary

func _init(library: CardLibrary):
	card_library = library

# 检查卡牌是否可以用于目标精灵（拖动卡牌到精灵时使用）
func can_use_card_on_sprite(card: Card, target_sprite: Sprite, all_friendly_sprites: Array[Sprite], game_map: GameMap) -> Dictionary:
	var result = {
		"can_use": false,
		"reason": "",
		"partner_sprite": null  # 双属性卡牌需要的另一个属性精灵
	}
	
	if card.is_single_attribute():
		# 单属性卡牌：目标精灵属性必须与卡牌属性相同
		var required_attr = card.attributes[0]
		var current_attr = target_sprite.attribute
		if target_sprite.attribute == required_attr:
			result.can_use = true
		else:
			result.reason = "该卡牌需要" + required_attr + "属性的精灵，当前精灵为" + (current_attr if current_attr != "" else "无属性")
	
	elif card.is_dual_attribute():
		# 双属性卡牌：目标精灵属性必须是双属性之一
		var attr1 = card.attributes[0]
		var attr2 = card.attributes[1]
		var current_attr = target_sprite.attribute
		
		if current_attr != attr1 and current_attr != attr2:
			result.reason = "该卡牌需要" + attr1 + "或" + attr2 + "属性的精灵，当前精灵为" + (current_attr if current_attr != "" else "无属性")
			return result
		
		# 确定目标精灵的属性，以及需要寻找的另一个属性
		var target_attr = current_attr
		var required_partner_attr: String
		if target_attr == attr1:
			required_partner_attr = attr2
		else:
			required_partner_attr = attr1
		
		# 检查目标精灵范围内是否存在另一个属性的己方精灵
		var range_coords = HexGrid.get_hexes_in_range(target_sprite.hex_position, card.dual_attribute_range)
		var found_partner = false
		
		for sprite in all_friendly_sprites:
			# 必须是己方精灵（同一玩家）
			if sprite.owner_player_id != target_sprite.owner_player_id:
				continue
			# 不能是目标精灵自己
			if sprite == target_sprite:
				continue
			# 必须是另一个属性
			if sprite.attribute != required_partner_attr:
				continue
			# 必须在范围内
			if sprite.hex_position not in range_coords:
				continue
			
			# 找到匹配的伙伴精灵
			result.can_use = true
			result.partner_sprite = sprite
			found_partner = true
			break
		
		if not found_partner:
			result.reason = "还需要在" + str(card.dual_attribute_range) + "格范围内拥有" + required_partner_attr + "属性的己方精灵"
	else:
		result.reason = "卡牌未配置可用的属性要求"
	
	return result

# 校验卡牌属性与精灵属性的匹配性（旧版本，保留兼容性）
func check_attribute_match(card: Card, sprites: Array[Sprite], allow_rent: bool = false) -> Dictionary:
	var result = {
		"matched": false,
		"matched_sprites": [],
		"need_rent": false,
		"rent_attributes": [],
		"reason": ""
	}
	
	if card.is_single_attribute():
		# 单属性卡牌：必须使用自身对应属性的精灵
		var required_attr = card.attributes[0]
		for sprite in sprites:
			if sprite.attribute == required_attr:
				result.matched = true
				result.matched_sprites.append(sprite)
		
		if not result.matched:
			result.reason = "没有匹配的" + required_attr + "属性精灵"
	
	elif card.is_dual_attribute():
		# 双属性卡牌：至少需要1种属性对应自身精灵
		var attr1 = card.attributes[0]
		var attr2 = card.attributes[1]
		
		var has_attr1 = false
		var has_attr2 = false
		var matched_sprites_attr1: Array[Sprite] = []
		var matched_sprites_attr2: Array[Sprite] = []
		
		for sprite in sprites:
			if sprite.attribute == attr1:
				has_attr1 = true
				matched_sprites_attr1.append(sprite)
			if sprite.attribute == attr2:
				has_attr2 = true
				matched_sprites_attr2.append(sprite)
		
		# 如果两种属性都有，直接匹配
		if has_attr1 and has_attr2:
			result.matched = true
			result.matched_sprites = matched_sprites_attr1 + matched_sprites_attr2
		# 如果只有一种属性，需要租用另一种
		elif has_attr1 or has_attr2:
			if allow_rent:
				result.matched = true
				if has_attr1:
					result.matched_sprites = matched_sprites_attr1
					result.need_rent = true
					result.rent_attributes.append(attr2)
				else:
					result.matched_sprites = matched_sprites_attr2
					result.need_rent = true
					result.rent_attributes.append(attr1)
			else:
				result.reason = "需要租用其他玩家的精灵"
		else:
			result.reason = "没有匹配的属性精灵"
	
	return result

# 状态与延迟管理器引用
var status_manager: StatusEffectManager
var delayed_effect_manager: DelayedEffectManager

func set_aux_managers(status_mgr: StatusEffectManager, delayed_mgr: DelayedEffectManager):
	status_manager = status_mgr
	delayed_effect_manager = delayed_mgr

# 传递卡牌效果至目标精灵/地形
func apply_card_effect(card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager, all_sprites: Array[Sprite] = []) -> Dictionary:
	var result = {
		"success": false,
		"effect_applied": false,
		"message": ""
	}
	
	if all_sprites == null:
		all_sprites = []
	
	if card.effects.is_empty():
		result.message = "卡牌未配置结构化效果"
		return result
	
	var messages: Array[String] = []
	for effect in card.effects:
		var effect_result = _apply_effect_by_tag(effect, card, source_sprite, target, game_map, terrain_manager, all_sprites)
		var error_message: String = effect_result.get("error", "")
		if not error_message.is_empty():
			result.message = error_message
			return result
		
		if effect_result.get("success", false):
			result.effect_applied = true
			var msg = effect_result.get("message", "")
			if not msg.is_empty():
				messages.append(msg)
	
	result.success = result.effect_applied
	if messages.size() > 0:
		result.message = "；".join(messages)
	
	return result
	
func _apply_effect_by_tag(effect: Dictionary, card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager, all_sprites: Array[Sprite]) -> Dictionary:
	var tag: String = effect.get("tag", "")
	match tag:
		"damage", "area_damage":
			return _effect_damage(effect, card, source_sprite, target, game_map, terrain_manager, all_sprites)
		"persistent_area_damage", "damage_over_time_field":
			return _effect_persistent_area_damage(effect, card, source_sprite, target, game_map, terrain_manager)
		"status", "apply_status", "area_status":
			return _effect_status(effect, card, source_sprite, target, all_sprites)
		"height_based_damage":
			return _effect_height_based_damage(effect, source_sprite, target, game_map)
		"single_attack":
			return _effect_single_attack(effect, source_sprite, target, game_map, terrain_manager)
		"terrain_change":
			return _effect_terrain_change(effect, source_sprite, target, game_map, terrain_manager)
		"terrain_extend_duration":
			return _effect_terrain_extend_duration(effect, source_sprite, target, game_map)
		"heal":
			return _effect_heal(effect, source_sprite, target, all_sprites)
		_:
			return {
				"success": false,
				"error": "未知的卡牌效果标签: " + tag
			}

func _effect_damage(effect: Dictionary, card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager, all_sprites: Array[Sprite]) -> Dictionary:
	var amount: int = effect.get("amount", 0)
	var terrain_height_delta: int = effect.get("terrain_height_delta", 0)
	var has_damage_component = amount != 0
	if not has_damage_component and terrain_height_delta == 0:
		return {"success": false, "message": ""}
	var radius: int = effect.get("radius", 0)
	var alignment: String = effect.get("affects", effect.get("target_alignment", "enemy"))
	var center_mode: String = effect.get("center", "target_sprite")
	var burn_forest: bool = effect.get("burn_forest", false)
	var knockback_data = effect.get("knockback", {})
	var owner_id = source_sprite.owner_player_id
	var affected_hexes: Array[Vector2i] = []
	var targets: Array[Sprite] = []
	if radius > 0:
		var center_coord = _resolve_center_coord(center_mode, source_sprite, target)
		if center_coord == null:
			return {"success": false, "error": "范围效果缺少中心坐标"}
		affected_hexes = HexGrid.get_hexes_in_range(center_coord, radius)
		targets = _collect_targets_in_radius(center_coord, radius, alignment, owner_id, all_sprites)
	else:
		if target is Sprite:
			targets.append(target)
			affected_hexes.append(target.hex_position)
		elif alignment == "ally":
			targets.append(source_sprite)
			affected_hexes.append(source_sprite.hex_position)
		else:
			return {"success": false, "error": "伤害效果缺少有效目标"}
	if burn_forest and affected_hexes.size() > 0:
		_burn_tiles_in_hexes(affected_hexes, owner_id, game_map, terrain_manager)
	var bonus_vs_terrain = effect.get("bonus_vs_terrain", [])
	var messages: Array[String] = []
	for sprite in targets:
		var target_damage = amount
		var terrain = game_map.get_terrain(sprite.hex_position)
		for bonus_def in bonus_vs_terrain:
			if typeof(bonus_def) != TYPE_DICTIONARY:
				continue
			var terrain_name: String = bonus_def.get("terrain", "")
			var bonus_value: int = bonus_def.get("bonus", 0)
			if terrain and _terrain_matches_string(terrain, terrain_name):
				target_damage += bonus_value
		if target_damage > 0:
			sprite.take_damage(target_damage)
			messages.append("对" + sprite.sprite_name + "造成" + str(target_damage) + "点伤害")
		if terrain_height_delta != 0:
			terrain_manager.request_terrain_change(
				owner_id,
				sprite.hex_position,
				TerrainTile.TerrainType.NORMAL,
				-1,
				-1,
				terrain_height_delta
			)
		if knockback_data and sprite != source_sprite:
			_apply_knockback(source_sprite, sprite, knockback_data, game_map, all_sprites)
	if messages.is_empty():
		return {"success": true, "message": "范围内没有可攻击目标"}
	return {"success": true, "message": "；".join(messages)}

func _effect_persistent_area_damage(effect: Dictionary, card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager) -> Dictionary:
	if not delayed_effect_manager:
		return {"success": false, "error": "延迟效果系统未初始化"}
	var center_coord = _resolve_center_coord(effect.get("center", "target_tile"), source_sprite, target)
	if center_coord == null:
		return {"success": false, "error": "持续效果缺少中心"}
	var duration = effect.get("duration", effect.get("duration_turns", 0))
	if duration <= 0:
		return {"success": false, "error": "持续效果缺少持续时间"}
	var alignment = effect.get("affects", effect.get("target_alignment", "enemy"))
	var field_data = {
		"center_coord": center_coord,
		"radius": effect.get("radius", 0),
		"damage": effect.get("damage", 0),
		"duration_turns": duration,
		"target_alignment": alignment,
		"owner_player_id": source_sprite.owner_player_id
	}
	var expire_def = effect.get("on_expire")
	if expire_def and typeof(expire_def) == TYPE_DICTIONARY:
		var action = expire_def.duplicate(true)
		if action.get("target", "") == "target_tile":
			action["coord"] = center_coord
		action["owner_player_id"] = source_sprite.owner_player_id
		field_data["expire_actions"] = [action]
	var final_terrain = effect.get("final_terrain")
	if final_terrain and typeof(final_terrain) == TYPE_DICTIONARY:
		var expire_action = {
			"action": "terrain_change",
			"coord": center_coord,
			"terrain_type": final_terrain.get("terrain_type", "normal"),
			"set_height": final_terrain.get("set_height", -1),
			"height_delta": final_terrain.get("height_delta", 0),
			"owner_player_id": source_sprite.owner_player_id
		}
		if not field_data.has("expire_actions"):
			field_data["expire_actions"] = []
		field_data["expire_actions"].append(expire_action)
	delayed_effect_manager.register_field_effect(field_data)
	return {"success": true, "message": card.card_name + "将在" + str(duration) + "回合内持续生效"}

func _effect_status(effect: Dictionary, card: Card, source_sprite: Sprite, target: Variant, all_sprites: Array[Sprite]) -> Dictionary:
	if not status_manager:
		return {"success": false, "error": "状态系统未初始化"}
	var radius: int = effect.get("radius", 0)
	var alignment: String = effect.get("affects", effect.get("target_alignment", "ally"))
	var targets: Array[Sprite] = []
	if radius > 0:
		var center_coord = _resolve_center_coord(effect.get("center", "target_tile"), source_sprite, target)
		if center_coord == null:
			return {"success": false, "error": "状态效果缺少中心"}
		targets = _collect_targets_in_radius(center_coord, radius, alignment, source_sprite.owner_player_id, all_sprites)
	else:
		var scope = effect.get("target_scope", "target")
		match scope:
			"self", "caster":
				targets.append(source_sprite)
			"target", "primary":
				var resolved = _resolve_sprite_target(target)
				if resolved:
					targets.append(resolved)
				else:
					targets.append(source_sprite)
			_:
				var resolved_default = _resolve_sprite_target(target)
				targets.append(resolved_default if resolved_default else source_sprite)
	if targets.is_empty():
		return {"success": true, "message": "范围内没有可用目标"}
	var status_payload: Dictionary
	if effect.has("status"):
		status_payload = effect.get("status").duplicate(true)
	else:
		status_payload = {
			"status_id": effect.get("status_id", effect.get("status_type", "")),
			"duration": effect.get("duration", effect.get("duration_turns", 0)),
			"modifiers": effect.get("modifiers", {}),
			"magnitude": effect.get("magnitude", effect.get("amount", 0)),
			"max_stack": effect.get("max_stack", -1)
		}
	if status_payload.get("status_id", "").is_empty():
		return {"success": false, "error": "状态缺少标识"}
	status_payload["source_player_id"] = source_sprite.owner_player_id
	for sprite in targets:
		status_manager.apply_status(sprite, status_payload)
	return {"success": true, "message": "状态" + status_payload.get("status_id", "") + "已应用"}

func _effect_height_based_damage(effect: Dictionary, source_sprite: Sprite, target: Variant, game_map: GameMap) -> Dictionary:
	var target_sprite = _resolve_sprite_target(target)
	if not target_sprite:
		return {"success": false, "error": "需要精灵目标"}
	var terrain = game_map.get_terrain(target_sprite.hex_position)
	if not terrain:
		return {"success": false, "message": ""}
	var mapping: Dictionary = effect.get("mapping", {})
	var pending_delta: int = effect.get("pending_height_delta", 0)
	var use_post_change: bool = effect.get("use_post_change_height", false)
	var effective_height = terrain.height_level
	if use_post_change:
		effective_height += pending_delta
	effective_height = clamp(effective_height, 0, 10)
	var key = str(effective_height)
	var damage: int = mapping.get(key, 0)
	if damage <= 0:
		return {"success": true, "message": "没有造成伤害"}
	target_sprite.take_damage(damage)
	return {"success": true, "message": "根据高度造成" + str(damage) + "点伤害"}

func _effect_single_attack(effect: Dictionary, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager) -> Dictionary:
	if not (target is Sprite):
		return {"success": false, "error": "攻击卡牌需要精灵目标"}
	
	var damage: int = effect.get("damage", 0)
	var terrain = game_map.get_terrain(target.hex_position)
	var bonus_vs_terrain = effect.get("bonus_vs_terrain", [])
	
	for bonus_def in bonus_vs_terrain:
		if typeof(bonus_def) != TYPE_DICTIONARY:
			continue
		var terrain_name: String = bonus_def.get("terrain", "")
		var bonus_value: int = bonus_def.get("bonus", 0)
		if terrain and _terrain_matches_string(terrain, terrain_name):
			damage += bonus_value
	
	damage = max(damage, 0)
	if damage > 0:
		target.take_damage(damage)
	
	var height_delta: int = effect.get("terrain_height_delta", 0)
	if height_delta != 0:
		terrain_manager.request_terrain_change(
			source_sprite.owner_player_id,
			target.hex_position,
			TerrainTile.TerrainType.NORMAL,
			-1,
			-1,
			height_delta
		)
	
	var msg_parts: Array[String] = []
	msg_parts.append("对" + target.sprite_name + "造成" + str(damage) + "点伤害")
	if height_delta > 0:
		msg_parts.append("抬高该地形" + str(height_delta) + "级")
	elif height_delta < 0:
		msg_parts.append("降低该地形" + str(abs(height_delta)) + "级")
	
	return {
		"success": true,
		"message": "，".join(msg_parts)
	}

func _effect_terrain_change(effect: Dictionary, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager) -> Dictionary:
	var hex_coord = _resolve_hex_coord(target)
	if hex_coord == null:
		return {"success": false, "error": "地形卡牌需要有效的六边形坐标"}
	
	var terrain_type_name: String = effect.get("terrain_type", "normal")
	var terrain_type = _terrain_type_from_string(terrain_type_name)
	var duration: int = effect.get("duration", -1)
	var set_height: int = effect.get("set_height", -1)
	var height_delta: int = effect.get("height_delta", 0)
	
	terrain_manager.request_terrain_change(
		source_sprite.owner_player_id,
		hex_coord,
		terrain_type,
		set_height,
		duration,
		height_delta
	)
	
	var msg_parts: Array[String] = []
	if height_delta > 0:
		msg_parts.append("抬高地形" + str(height_delta) + "级")
	elif height_delta < 0:
		msg_parts.append("降低地形" + str(abs(height_delta)) + "级")
	
	if set_height > 0:
		msg_parts.append("将地形设为" + str(set_height) + "级")
	
	if terrain_type != TerrainTile.TerrainType.NORMAL:
		msg_parts.append("创建" + _terrain_type_to_text(terrain_type) + "地形")
	else:
		msg_parts.append("修改地形")
	
	if duration == -1:
		msg_parts.append("（永久）")
	elif duration > 0:
		msg_parts.append("持续" + str(duration) + "回合")
	
	return {
		"success": true,
		"message": "，".join(msg_parts)
	}

func _effect_terrain_extend_duration(effect: Dictionary, source_sprite: Sprite, target: Variant, game_map: GameMap) -> Dictionary:
	var hex_coord = _resolve_hex_coord(target)
	if hex_coord == null:
		return {"success": false, "error": "地形延长效果需要有效坐标"}
	
	var terrain_type_name: String = effect.get("terrain_type", "water")
	var target_type = _terrain_type_from_string(terrain_type_name)
	var extra_duration: int = effect.get("extra_duration", 0)
	if extra_duration <= 0:
		return {"success": false, "error": "延长回合数必须大于0"}
	
	var existing_terrain = game_map.get_terrain(hex_coord)
	if existing_terrain and existing_terrain.terrain_type == target_type:
		if existing_terrain.effect_duration > 0:
			existing_terrain.effect_duration += extra_duration
		return {
			"success": true,
			"message": "延长" + _terrain_type_to_text(target_type) + "地形" + str(extra_duration) + "回合"
		}
	
	return {"success": false, "message": ""}

func _effect_heal(effect: Dictionary, source_sprite: Sprite, target: Variant, all_sprites: Array[Sprite]) -> Dictionary:
	var amount: int = effect.get("amount", 0)
	if amount <= 0:
		return {"success": false, "message": ""}
	var radius: int = effect.get("radius", 0)
	var alignment: String = effect.get("target_alignment", "ally")
	var targets: Array[Sprite] = []
	if radius > 0:
		var center = _resolve_center_coord(effect.get("center", "target"), source_sprite, target)
		if center == null:
			center = source_sprite.hex_position
		targets = _collect_targets_in_radius(center, radius, alignment, source_sprite.owner_player_id, all_sprites)
	else:
		var scope = effect.get("target", "target")
		if scope == "self":
			targets.append(source_sprite)
		elif scope == "target" and target is Sprite:
			targets.append(target)
		else:
			targets.append(source_sprite)
	if targets.is_empty():
		return {"success": true, "message": "没有可治疗目标"}
	for sprite in targets:
		sprite.heal(amount)
	return {"success": true, "message": "恢复" + str(amount) + "点生命"}

func _resolve_sprite_target(target: Variant) -> Sprite:
	if target is Sprite:
		return target
	return null

func _collect_targets_in_radius(center: Vector2i, radius: int, alignment: String, owner_id: int, all_sprites: Array[Sprite]) -> Array[Sprite]:
	var results: Array[Sprite] = []
	if center == null:
		return results
	var affected_hexes = HexGrid.get_hexes_in_range(center, radius)
	for sprite in all_sprites:
		if not sprite or not sprite.is_alive:
			continue
		if sprite.hex_position not in affected_hexes:
			continue
		if not _matches_alignment(sprite, owner_id, alignment):
			continue
		results.append(sprite)
	return results

func _resolve_center_coord(center_mode: String, source_sprite: Sprite, target: Variant) -> Variant:
	match center_mode:
		"source", "caster", "self":
			return source_sprite.hex_position
		"target_sprite":
			var sprite = _resolve_sprite_target(target)
			return sprite.hex_position if sprite else null
		"target_tile", "target":
			return _resolve_hex_coord(target)
		_:
			return _resolve_hex_coord(target)

func _matches_alignment(sprite: Sprite, owner_id: int, alignment: String) -> bool:
	match alignment:
		"ally", "allies":
			return owner_id >= 0 and sprite.owner_player_id == owner_id
		"enemy", "enemies":
			return owner_id >= 0 and sprite.owner_player_id != owner_id
		"self":
			return sprite.owner_player_id == owner_id
		_:
			return true

func _burn_tiles_in_hexes(hexes: Array[Vector2i], owner_id: int, game_map: GameMap, terrain_manager: TerrainManager):
	for hex in hexes:
		var terrain = game_map.get_terrain(hex)
		if not terrain:
			continue
		if terrain.terrain_type != TerrainTile.TerrainType.FOREST or terrain.is_burned:
			continue
		terrain_manager.request_terrain_change(owner_id, hex, TerrainTile.TerrainType.SCORCHED, terrain.height_level, -1, 0, false)

func _apply_knockback(source_sprite: Sprite, target_sprite: Sprite, knockback_data: Dictionary, game_map: GameMap, all_sprites: Array[Sprite]):
	var distance: int = max(1, knockback_data.get("distance", 1))
	var direction = _get_knockback_direction(source_sprite.hex_position, target_sprite.hex_position)
	if direction == Vector2i.ZERO:
		return
	var destination = target_sprite.hex_position
	for i in range(distance):
		destination += direction
	var origin_terrain = game_map.get_terrain(target_sprite.hex_position)
	var dest_terrain = game_map.get_terrain(destination)
	var block_damage: int = knockback_data.get("blocked_damage", knockback_data.get("block_damage", 0))
	if dest_terrain == null:
		_apply_knockback_block_damage(target_sprite, block_damage)
		return
	var origin_height = origin_terrain.height_level if origin_terrain else 1
	if dest_terrain.height_level > origin_height or _is_tile_occupied(destination, all_sprites):
		_apply_knockback_block_damage(target_sprite, block_damage)
		return
	target_sprite.move_to(destination)

func _apply_knockback_block_damage(sprite: Sprite, damage: int):
	if damage > 0:
		sprite.take_damage(damage)

func _get_knockback_direction(source_coord: Vector2i, target_coord: Vector2i) -> Vector2i:
	if source_coord == target_coord:
		return Vector2i.ZERO
	var best_dir = Vector2i.ZERO
	var best_distance = -INF
	for dir in HexGrid.HEX_DIRECTIONS:
		var candidate = target_coord + dir
		var distance = HexGrid.hex_distance(candidate, source_coord)
		if distance > best_distance:
			best_distance = distance
			best_dir = dir
	return best_dir

func _is_tile_occupied(hex_coord: Vector2i, all_sprites: Array[Sprite]) -> bool:
	for sprite in all_sprites:
		if not sprite or not sprite.is_alive:
			continue
		if sprite.hex_position == hex_coord:
			return true
	return false

func _resolve_hex_coord(target: Variant) -> Variant:
	if target is Vector2i:
		return target
	if target is Sprite:
		return target.hex_position
	return null

func _terrain_type_from_string(type_name: String) -> TerrainTile.TerrainType:
	var lowered = type_name.to_lower()
	match lowered:
		"water":
			return TerrainTile.TerrainType.WATER
		"rock", "bedrock":
			return TerrainTile.TerrainType.BEDROCK
		"forest":
			return TerrainTile.TerrainType.FOREST
		"scorched":
			return TerrainTile.TerrainType.SCORCHED
		_:
			return TerrainTile.TerrainType.NORMAL

func _terrain_type_to_text(terrain_type: TerrainTile.TerrainType) -> String:
	match terrain_type:
		TerrainTile.TerrainType.WATER:
			return "水流"
		TerrainTile.TerrainType.BEDROCK:
			return "基岩"
		TerrainTile.TerrainType.FOREST:
			return "森林"
		TerrainTile.TerrainType.SCORCHED:
			return "焦土"
		_:
			return "普通"

func _terrain_matches_string(terrain: TerrainTile, type_name: String) -> bool:
	if terrain == null:
		return false
	return terrain.terrain_type == _terrain_type_from_string(type_name)

# 获取卡牌可攻击的目标精灵列表
func get_attackable_targets(card: Card, source_sprite: Sprite, all_sprites: Array[Sprite], game_map: GameMap) -> Array[Sprite]:
	var targets: Array[Sprite] = []
	
	# 根据range_requirement和卡牌效果描述计算可攻击范围
	var attackable_positions: Array[Vector2i] = []
	var attack_range: int = 0
	
	# 首先检查卡牌效果描述中是否有特殊范围描述
	var special_range = _parse_special_range_from_effect(card.effect_description)
	if card.range_override > 0:
		attack_range = card.range_override
		var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
		attackable_positions = range_hexes
		print("攻击范围计算（自定义覆盖）: 精灵位置=", source_sprite.hex_position, " 范围=", attack_range, " 可攻击位置数=", range_hexes.size())
	elif special_range > 0:
		# 卡牌有特殊范围描述，优先使用
		attack_range = special_range
		var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
		attackable_positions = range_hexes
		print("攻击范围计算（卡牌特殊范围）: 精灵位置=", source_sprite.hex_position, " 范围=", attack_range, " 可攻击位置数=", range_hexes.size())
	else:
		# 没有特殊范围描述，根据range_requirement判断
		match card.range_requirement:
			"within_attack_range", "follow_caster":
				attack_range = source_sprite.cast_range
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
				print("攻击范围计算（精灵施法范围）: 精灵位置=", source_sprite.hex_position, " 施法范围=", attack_range, " 可攻击位置数=", range_hexes.size())
			"line_2_tiles":
				attack_range = 2
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
				print("攻击范围计算: 直线2格，可攻击位置数=", range_hexes.size())
			"range_3":
				attack_range = 3
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
			"range_4":
				attack_range = 4
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
			"self":
				attack_range = 0
				attackable_positions = [source_sprite.hex_position]
			_:
				attack_range = source_sprite.cast_range
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
				print("攻击范围计算（默认精灵施法范围）: 范围=", attack_range, " 可攻击位置数=", range_hexes.size())
	
	# 查找范围内的敌方精灵
	print("查找敌方精灵: 总精灵数=", all_sprites.size(), " 己方玩家ID=", source_sprite.owner_player_id)
	for sprite in all_sprites:
		if not sprite.is_alive:
			continue
		# 必须是敌方精灵
		if sprite.owner_player_id == source_sprite.owner_player_id:
			continue
		# 必须在攻击范围内
		var distance = HexGrid.hex_distance(source_sprite.hex_position, sprite.hex_position)
		print("检查精灵: ", sprite.sprite_name, " 位置=", sprite.hex_position, " 距离=", distance, " 攻击范围=", attack_range)
		if sprite.hex_position in attackable_positions:
			targets.append(sprite)
			print("找到可攻击目标: ", sprite.sprite_name)
	
	print("最终找到 ", targets.size(), " 个可攻击目标")
	return targets

# 获取卡牌可放置地形的位置列表
func get_terrain_placement_positions(card: Card, source_sprite: Sprite, game_map: GameMap) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	
	# 首先检查卡牌效果描述中是否有特殊范围描述（如"相邻1格"）
	var special_range = _parse_special_range_from_effect(card.effect_description)
	var is_adjacent_only = _check_adjacent_in_effect(card.effect_description)
	
	if is_adjacent_only:
		# 卡牌描述明确说"相邻"，使用相邻1格
		var neighbors = HexGrid.get_neighbors(source_sprite.hex_position)
		for neighbor in neighbors:
			if game_map.is_valid_hex_with_terrain(neighbor):
				positions.append(neighbor)
		print("地形放置范围（卡牌特殊描述：相邻）: 相邻1格")
	elif card.range_override > 0:
		var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, card.range_override)
		for hex in range_hexes:
			if game_map.is_valid_hex_with_terrain(hex):
				positions.append(hex)
		print("地形放置范围（自定义覆盖）: ", card.range_override, "格")
	elif special_range > 0:
		# 卡牌有特殊范围描述，使用该范围
		var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, special_range)
		for hex in range_hexes:
			if game_map.is_valid_hex_with_terrain(hex):
				positions.append(hex)
		print("地形放置范围（卡牌特殊范围）: ", special_range, "格")
	else:
		# 没有特殊描述，根据range_requirement判断
		match card.range_requirement:
			"adjacent":
				# 相邻1格
				var neighbors = HexGrid.get_neighbors(source_sprite.hex_position)
				for neighbor in neighbors:
					if game_map.is_valid_hex_with_terrain(neighbor):
						positions.append(neighbor)
			"adjacent_2_tiles":
				# 2格范围内（需与自身精灵相邻）
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, 2)
				for hex in range_hexes:
					# 必须在2格范围内，且与自身精灵相邻
					if HexGrid.is_adjacent(hex, source_sprite.hex_position):
						if game_map.is_valid_hex_with_terrain(hex):
							positions.append(hex)
			"adjacent_3_tiles":
				# 3格范围内（需与自身精灵相邻）
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, 3)
				for hex in range_hexes:
					# 必须在3格范围内，且与自身精灵相邻
					if HexGrid.is_adjacent(hex, source_sprite.hex_position):
						if game_map.is_valid_hex_with_terrain(hex):
							positions.append(hex)
			"within_attack_range", "follow_caster":
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, source_sprite.cast_range)
				for hex in range_hexes:
					if game_map.is_valid_hex_with_terrain(hex):
						positions.append(hex)
			"range_3":
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, 3)
				for hex in range_hexes:
					if game_map.is_valid_hex_with_terrain(hex):
						positions.append(hex)
			"range_4":
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, 4)
				for hex in range_hexes:
					if game_map.is_valid_hex_with_terrain(hex):
						positions.append(hex)
			"self":
				if game_map.is_valid_hex_with_terrain(source_sprite.hex_position):
					positions.append(source_sprite.hex_position)
			_:
				# 默认使用精灵施法范围
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, source_sprite.cast_range)
				for hex in range_hexes:
					if game_map.is_valid_hex_with_terrain(hex):
						positions.append(hex)
				print("地形放置范围（默认精灵施法范围）: ", source_sprite.cast_range, "格")
	
	return positions

# 从卡牌效果描述中解析特殊范围（如"直线2格内"、"3格范围内"等）
func _parse_special_range_from_effect(effect_description: String) -> int:
	if effect_description.is_empty():
		return 0
	
	# 如果明确提到"相邻"，返回0（表示使用相邻逻辑，不是范围）
	if "相邻" in effect_description or "adjacent" in effect_description.to_lower():
		return 0
	
	# 匹配模式：X格内、X格范围内、直线X格内、周围X格等
	# 优先匹配范围描述（如"2格内"、"3格范围内"、"周围1格"）
	var regex = RegEx.new()
	# 匹配：X格内、X格范围内、周围X格、直线X格内等
	regex.compile("(?:直线|周围|范围内|范围)?(\\d+)\\s*格")
	var result = regex.search(effect_description)
	if result:
		var range_str = result.get_string(1)
		var range_value = int(range_str)
		# 如果范围是1格且描述中有"相邻"，返回0（使用相邻逻辑）
		if range_value == 1 and ("相邻" in effect_description or "adjacent" in effect_description.to_lower()):
			return 0
		return range_value
	
	return 0

# 检查效果描述中是否明确提到"相邻"
func _check_adjacent_in_effect(effect_description: String) -> bool:
	if effect_description.is_empty():
		return false
	
	# 检查是否包含"相邻"关键词
	return "相邻" in effect_description or "adjacent" in effect_description.to_lower()
