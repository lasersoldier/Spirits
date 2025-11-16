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
		if target_sprite.attribute == required_attr:
			result.can_use = true
		else:
			result.reason = "目标精灵属性不匹配，需要" + required_attr + "属性"
	
	elif card.is_dual_attribute():
		# 双属性卡牌：目标精灵属性必须是双属性之一
		var attr1 = card.attributes[0]
		var attr2 = card.attributes[1]
		
		if target_sprite.attribute != attr1 and target_sprite.attribute != attr2:
			result.reason = "目标精灵属性不匹配，需要" + attr1 + "或" + attr2 + "属性"
			return result
		
		# 确定目标精灵的属性，以及需要寻找的另一个属性
		var target_attr = target_sprite.attribute
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
			result.reason = "目标精灵" + str(card.dual_attribute_range) + "格范围内没有" + required_partner_attr + "属性的己方精灵"
	
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
	
	match card.card_type:
		"attack":
			# 攻击效果
			if target is Sprite:
				var damage = _calculate_damage(card, source_sprite, target, game_map)
				target.take_damage(damage)
				result.success = true
				result.effect_applied = true
				result.message = "对" + target.sprite_name + "造成" + str(damage) + "点伤害"
				
				# 检查攻击卡牌是否附带地形修改效果（如 C07、C09）
				var target_terrain_coord = target.hex_position
				var height_delta = _parse_height_modification(card.effect_description, target_terrain_coord, game_map)
				if height_delta != 0:
					# 修改目标精灵所在地形的高度
					var terrain_type = TerrainTile.TerrainType.NORMAL  # 保持原地形类型
					terrain_manager.request_terrain_change(source_sprite.owner_player_id, target_terrain_coord, terrain_type, -1, -1, height_delta)
					
					# 更新消息
					if height_delta > 0:
						result.message += "，抬高了目标所在地形" + str(height_delta) + "级"
					elif height_delta < 0:
						result.message += "，降低了目标所在地形" + str(abs(height_delta)) + "级"
		
		"terrain":
			# 地形效果
			if target is Vector2i:
				var terrain_type = _get_terrain_type_from_card(card)
				var height_delta = _parse_height_modification(card.effect_description, target, game_map)
				var duration = _parse_duration(card.effect_description)
				
				# 特殊效果处理
				# C23: 延长已有地形持续时间（如果已存在）
				if card.card_id == "C23":
					var existing_terrain = game_map.get_terrain(target)
					if existing_terrain and existing_terrain.terrain_type == TerrainTile.TerrainType.WATER:
						# 延长持续时间
						if existing_terrain.effect_duration > 0:
							existing_terrain.effect_duration += 2
						result.success = true
						result.effect_applied = true
						result.message = "延长了水流地形持续时间2回合"
						return result
				
				# 对于纯高度变化类卡牌（只改变高度，不创建特殊地形类型），如果没有明确标注持续时间，应该是永久效果
				# 判断标准：地形类型为NORMAL且高度有变化，且效果描述中没有持续时间信息
				if terrain_type == TerrainTile.TerrainType.NORMAL and height_delta != 0:
					# 检查效果描述中是否有持续时间信息
					var has_duration_info = "持续" in card.effect_description or "永久" in card.effect_description
					if not has_duration_info:
						# 没有持续时间信息，设置为永久效果
						duration = -1
				
				# 提交地形变化请求（包含高度修改）
				terrain_manager.request_terrain_change(source_sprite.owner_player_id, target, terrain_type, -1, duration, height_delta)
				result.success = true
				result.effect_applied = true
				
				# 生成消息
				var message_parts: Array[String] = []
				if height_delta > 0:
					message_parts.append("抬高了" + str(height_delta) + "级")
				elif height_delta < 0:
					message_parts.append("降低了" + str(abs(height_delta)) + "级")
				
				if terrain_type != TerrainTile.TerrainType.NORMAL:
					message_parts.append("创建了" + TerrainTile.TerrainType.keys()[terrain_type] + "地形")
				else:
					message_parts.append("修改了地形")
				
				if duration == -1:
					message_parts.append("（永久）")
				elif duration > 0:
					message_parts.append("持续" + str(duration) + "回合")
				
				result.message = "、".join(message_parts)
		
		"support":
			# 辅助效果
			if target is Sprite:
				var heal_amount = _calculate_heal(card, source_sprite, target)
				target.heal(heal_amount)
				result.success = true
				result.effect_applied = true
				result.message = target.sprite_name + "恢复了" + str(heal_amount) + "点血量"
	
	return result

# 计算伤害（简化版）
func _calculate_damage(card: Card, _source: Sprite, target: Sprite, game_map: GameMap) -> int:
	var base_damage = 2  # 默认伤害
	
	# 根据卡牌ID设置特定伤害
	match card.card_id:
		"C01":  # 火焰冲击
			base_damage = 3
			var terrain = game_map.get_terrain(target.hex_position)
			if terrain and terrain.terrain_type == TerrainTile.TerrainType.FOREST:
				base_damage += 1
		"C02":  # 风刃
			base_damage = 2
		"C04":  # 岩击
			base_damage = 2
			var terrain = game_map.get_terrain(target.hex_position)
			if terrain and terrain.terrain_type == TerrainTile.TerrainType.ROCK:
				base_damage += 1
		"C05", "C09":  # 风火斩、风岩斩
			base_damage = 2
		"C07":  # 火岩爆
			base_damage = 3
	
	return base_damage

# 计算治疗量（简化版）
func _calculate_heal(card: Card, _source: Sprite, _target: Sprite) -> int:
	match card.card_id:
		"C06":  # 水火共鸣
			return 2
		_:
			return 0

# 从卡牌获取地形类型
func _get_terrain_type_from_card(card: Card) -> TerrainTile.TerrainType:
	match card.card_id:
		"C03", "C08", "C15", "C16", "C17", "C18", "C22", "C23":  # 水流相关卡牌
			return TerrainTile.TerrainType.WATER
		"C10":  # 水岩壁
			return TerrainTile.TerrainType.ROCK
		_:
			return TerrainTile.TerrainType.NORMAL

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

# 从卡牌效果描述中解析高度修改量（如"降低1级"、"抬高2级"等）
func _parse_height_modification(effect_description: String, target_coord: Vector2i = Vector2i(-1, -1), game_map: GameMap = null) -> int:
	if effect_description.is_empty():
		return 0
	
	# 使用正则表达式匹配高度修改描述
	var regex = RegEx.new()
	
	# 匹配"降低至X级"、"降低到X级"（根据当前高度计算delta）
	regex.compile("(?:降低至|降低到|下降到|下降至)(\\d+)\\s*级")
	var result = regex.search(effect_description)
	if result:
		var target_level_str = result.get_string(1)
		var target_level = int(target_level_str)
		if target_coord != Vector2i(-1, -1) and game_map:
			var terrain = game_map.get_terrain(target_coord)
			var current_level = terrain.height_level if terrain else 1
			return target_level - current_level  # 返回需要的delta
		else:
			# 无法获取当前高度，返回假设降低（最坏情况）
			return -(3 - target_level)
	
	# 匹配"抬高至X级"、"抬高到X级"、"提升至X级"（根据当前高度计算delta）
	regex.compile("(?:抬高至|抬升至|抬高到|提升至|提升到)(\\d+)\\s*级")
	result = regex.search(effect_description)
	if result:
		var target_level_str = result.get_string(1)
		var target_level = int(target_level_str)
		if target_coord != Vector2i(-1, -1) and game_map:
			var terrain = game_map.get_terrain(target_coord)
			var current_level = terrain.height_level if terrain else 1
			return target_level - current_level  # 返回需要的delta
		else:
			# 无法获取当前高度，返回假设抬高（最坏情况）
			return target_level - 1
	
	# 匹配"调整为X级"、"调整至X级"（根据当前高度计算delta）
	regex.compile("(?:调整为|调整至|调整到)(\\d+)\\s*级")
	result = regex.search(effect_description)
	if result:
		var target_level_str = result.get_string(1)
		var target_level = int(target_level_str)
		if target_coord != Vector2i(-1, -1) and game_map:
			var terrain = game_map.get_terrain(target_coord)
			var current_level = terrain.height_level if terrain else 1
			return target_level - current_level  # 返回需要的delta
		else:
			# 无法获取当前高度，默认假设调整为1级
			return target_level - 1
	
	# 匹配"降低X级"、"下降X级"等（负数）
	regex.compile("(?:降低|下降|减少)(\\d+)\\s*级")
	result = regex.search(effect_description)
	if result:
		var level_str = result.get_string(1)
		var level_value = int(level_str)
		return -level_value  # 返回负数表示降低
	
	# 匹配"抬高X级"、"提升X级"、"上升X级"等（正数）
	regex.compile("(?:抬高|提升|上升|增加)(\\d+)\\s*级")
	result = regex.search(effect_description)
	if result:
		var level_str = result.get_string(1)
		var level_value = int(level_str)
		return level_value  # 返回正数表示抬高
	
	# 未找到高度修改描述
	return 0

# 从效果描述中解析持续时间
func _parse_duration(effect_description: String) -> int:
	if effect_description.is_empty():
		return 3  # 默认3回合
	
	# 匹配"永久"
	if "永久" in effect_description:
		return -1  # -1表示永久
	
	# 匹配"持续X回合"
	var regex = RegEx.new()
	regex.compile("持续(\\d+)\\s*回合")
	var result = regex.search(effect_description)
	if result:
		var duration_str = result.get_string(1)
		return int(duration_str)
	
	# 默认3回合
	return 3
