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

# 传递卡牌效果至目标精灵/地形
func apply_card_effect(card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager) -> Dictionary:
	var result = {
		"success": false,
		"effect_applied": false,
		"message": ""
	}
	
	if card.effects.is_empty():
		result.message = "卡牌未配置结构化效果"
		return result
	
	var messages: Array[String] = []
	for effect in card.effects:
		var effect_result = _apply_effect_by_tag(effect, card, source_sprite, target, game_map, terrain_manager)
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

func _apply_effect_by_tag(effect: Dictionary, card: Card, source_sprite: Sprite, target: Variant, game_map: GameMap, terrain_manager: TerrainManager) -> Dictionary:
	var tag: String = effect.get("tag", "")
	match tag:
		"single_attack":
			return _effect_single_attack(effect, source_sprite, target, game_map, terrain_manager)
		"terrain_change":
			return _effect_terrain_change(effect, source_sprite, target, game_map, terrain_manager)
		"terrain_extend_duration":
			return _effect_terrain_extend_duration(effect, source_sprite, target, game_map)
		"heal":
			return _effect_heal(effect, source_sprite, target)
		_:
			return {
				"success": false,
				"error": "未知的卡牌效果标签: " + tag
			}

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

func _effect_heal(effect: Dictionary, source_sprite: Sprite, target: Variant) -> Dictionary:
	var heal_target: Sprite = null
	var target_scope: String = effect.get("target", "self")
	if target_scope == "self":
		heal_target = source_sprite
	elif target_scope == "target" and target is Sprite:
		heal_target = target
	
	if heal_target == null:
		return {"success": false, "error": "治疗效果缺少有效目标"}
	
	var amount: int = effect.get("amount", 0)
	if amount > 0:
		heal_target.heal(amount)
	
	return {
		"success": true,
		"message": heal_target.sprite_name + "恢复了" + str(amount) + "点生命"
	}

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
	if special_range > 0:
		# 卡牌有特殊范围描述，优先使用
		attack_range = special_range
		var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
		attackable_positions = range_hexes
		print("攻击范围计算（卡牌特殊范围）: 精灵位置=", source_sprite.hex_position, " 范围=", attack_range, " 可攻击位置数=", range_hexes.size())
	else:
		# 没有特殊范围描述，根据range_requirement判断
		match card.range_requirement:
			"within_attack_range":
				# 使用精灵的施法范围（默认）
				attack_range = source_sprite.cast_range
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
				print("攻击范围计算（精灵施法范围）: 精灵位置=", source_sprite.hex_position, " 施法范围=", attack_range, " 可攻击位置数=", range_hexes.size())
			"line_2_tiles":
				# 直线2格内（需要特殊处理，这里简化）
				attack_range = 2
				var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
				attackable_positions = range_hexes
				print("攻击范围计算: 直线2格，可攻击位置数=", range_hexes.size())
			_:
				# 默认使用精灵施法范围
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
