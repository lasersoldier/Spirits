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
		
		"terrain":
			# 地形效果
			if target is Vector2i:
				var terrain_type = _get_terrain_type_from_card(card)
				var success = game_map.modify_terrain(target, terrain_type, -1, 3)
				if success:
					terrain_manager.request_terrain_change(source_sprite.owner_player_id, target, terrain_type, -1, 3)
					result.success = true
					result.effect_applied = true
					result.message = "创建了" + TerrainTile.TerrainType.keys()[terrain_type] + "地形"
		
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
		"C03", "C08":  # 水流召唤、风水流
			return TerrainTile.TerrainType.WATER
		"C10":  # 水岩壁
			return TerrainTile.TerrainType.ROCK
		_:
			return TerrainTile.TerrainType.NORMAL

# 获取卡牌可攻击的目标精灵列表
func get_attackable_targets(card: Card, source_sprite: Sprite, all_sprites: Array[Sprite], game_map: GameMap) -> Array[Sprite]:
	var targets: Array[Sprite] = []
	
	# 根据range_requirement计算可攻击范围
	var attackable_positions: Array[Vector2i] = []
	var attack_range: int = 0
	
	match card.range_requirement:
		"within_attack_range":
			# 使用精灵的攻击范围
			attack_range = source_sprite.attack_range
			var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
			attackable_positions = range_hexes
			print("攻击范围计算: 精灵位置=", source_sprite.hex_position, " 攻击范围=", attack_range, " 可攻击位置数=", range_hexes.size())
		"line_2_tiles":
			# 直线2格内（需要特殊处理，这里简化）
			attack_range = 2
			var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
			attackable_positions = range_hexes
			print("攻击范围计算: 直线2格，可攻击位置数=", range_hexes.size())
		_:
			# 默认使用精灵攻击范围
			attack_range = source_sprite.attack_range
			var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
			attackable_positions = range_hexes
			print("攻击范围计算: 默认范围=", attack_range, " 可攻击位置数=", range_hexes.size())
	
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
	
	match card.range_requirement:
		"adjacent":
			# 相邻1格
			var neighbors = HexGrid.get_neighbors(source_sprite.hex_position)
			for neighbor in neighbors:
				if game_map.is_valid_hex_with_terrain(neighbor):
					positions.append(neighbor)
		"adjacent_3_tiles":
			# 3格范围内（需与自身精灵相邻）
			var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, 3)
			for hex in range_hexes:
				# 必须在3格范围内，且与自身精灵相邻
				if HexGrid.is_adjacent(hex, source_sprite.hex_position):
					if game_map.is_valid_hex_with_terrain(hex):
						positions.append(hex)
		_:
			# 默认相邻1格
			var neighbors = HexGrid.get_neighbors(source_sprite.hex_position)
			for neighbor in neighbors:
				if game_map.is_valid_hex_with_terrain(neighbor):
					positions.append(neighbor)
	
	return positions

