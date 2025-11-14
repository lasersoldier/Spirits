class_name AIDecisionMaker
extends RefCounted

# AI玩家引用
var ai_player: AIPlayer

# 系统引用
var game_map: GameMap
var sprites: Array[Sprite]
var hand_manager: HandCardManager
var energy_manager: EnergyManager
var contest_point_manager: ContestPointManager
var difficulty: AIPlayer.Difficulty

# 目标优先级
var target_priorities: Array[String] = ["bounty", "contest_point", "enemy"]

func _init(player: AIPlayer, map: GameMap, sprites_array: Array[Sprite], hand_mgr: HandCardManager, energy_mgr: EnergyManager, contest_mgr: ContestPointManager, diff: AIPlayer.Difficulty):
	ai_player = player
	game_map = map
	sprites = sprites_array
	hand_manager = hand_mgr
	energy_manager = energy_mgr
	contest_point_manager = contest_mgr
	difficulty = diff

# 更新状态
func update_state():
	# 更新目标优先级等
	pass

# 做出决策（生成行动列表）
func make_decisions() -> Array[ActionResolver.Action]:
	var actions: Array[ActionResolver.Action] = []
	
	# 简化版AI逻辑：优先移动至资源点/赏金区域，仅使用单属性卡牌
	
	# 1. 优先处理赏金
	if contest_point_manager.bounty_status == ContestPointManager.BountyStatus.GENERATED:
		actions.append_array(_try_acquire_bounty())
	
	# 2. 处理公共争夺点
	actions.append_array(_try_capture_contest_points())
	
	# 3. 使用单属性卡牌
	actions.append_array(_try_use_single_attribute_cards())
	
	# 4. 基础移动（向目标移动）
	actions.append_array(_try_move_towards_targets())
	
	return actions

# 尝试获取赏金
func _try_acquire_bounty() -> Array[ActionResolver.Action]:
	var actions: Array[ActionResolver.Action] = []
	
	if contest_point_manager.bounty_status != ContestPointManager.BountyStatus.GENERATED:
		return actions
	
	# 找到最近的精灵，移动到赏金区域
	var bounty_zone = game_map.bounty_zone_tiles
	if bounty_zone.is_empty():
		return actions
	
	var target_pos = bounty_zone[0]  # 使用第一个坐标作为目标
	
	for sprite in sprites:
		if not sprite.is_alive:
			continue
		
		# 如果已经在赏金区域内，不需要移动
		if game_map.is_in_bounty_zone(sprite.hex_position):
			continue
		
		# 尝试移动到赏金区域
		var path = _find_path(sprite.hex_position, target_pos)
		if path.size() > 1 and sprite.remaining_movement > 0:
			var next_pos = path[1]
			var action = ActionResolver.Action.new(ai_player.player_id, ActionResolver.ActionType.MOVE, sprite, next_pos)
			actions.append(action)
			break  # 只让一个精灵去
	
	return actions

# 尝试占领公共争夺点
func _try_capture_contest_points() -> Array[ActionResolver.Action]:
	var actions: Array[ActionResolver.Action] = []
	
	var contest_points = game_map.contest_points
	for point_pos in contest_points:
		# 检查是否已有精灵在该点
		var has_sprite_at_point = false
		for sprite in sprites:
			if sprite.hex_position == point_pos:
				has_sprite_at_point = true
				break
		
		if has_sprite_at_point:
			continue
		
		# 找到最近的精灵，移动到争夺点
		for sprite in sprites:
			if not sprite.is_alive or sprite.remaining_movement <= 0:
				continue
			
			var distance = HexGrid.hex_distance(sprite.hex_position, point_pos)
			if distance <= sprite.remaining_movement:
				var path = _find_path(sprite.hex_position, point_pos)
				if path.size() > 1:
					var next_pos = path[1]
					var action = ActionResolver.Action.new(ai_player.player_id, ActionResolver.ActionType.MOVE, sprite, next_pos)
					actions.append(action)
					break
	
	return actions

# 尝试使用单属性卡牌
func _try_use_single_attribute_cards() -> Array[ActionResolver.Action]:
	var actions: Array[ActionResolver.Action] = []
	
	var usable_cards = hand_manager.get_usable_cards(energy_manager.get_energy(ai_player.player_id), sprites)
	
	# 筛选单属性卡牌
	var single_attr_cards: Array[Card] = []
	for card in usable_cards:
		if card.is_single_attribute():
			single_attr_cards.append(card)
	
	# 简化版：使用第一张可用的单属性卡牌
	if single_attr_cards.size() > 0:
		var card = single_attr_cards[0]
		# 找到匹配的精灵
		var matched_sprite = _find_matching_sprite(card)
		if matched_sprite:
			# 简化版：对最近的敌方精灵使用（如果有）
			# 这里可以添加更复杂的逻辑
			pass
	
	return actions

# 尝试向目标移动
func _try_move_towards_targets() -> Array[ActionResolver.Action]:
	var actions: Array[ActionResolver.Action] = []
	
	# 为每个精灵找到移动目标
	for sprite in sprites:
		if not sprite.is_alive or sprite.remaining_movement <= 0:
			continue
		
		# 简化版：随机选择一个方向移动
		var neighbors = HexGrid.get_neighbors(sprite.hex_position)
		if neighbors.size() > 0:
			var target = neighbors[randi() % neighbors.size()]
			if game_map._is_valid_hex(target):
				var action = ActionResolver.Action.new(ai_player.player_id, ActionResolver.ActionType.MOVE, sprite, target)
				actions.append(action)
	
	return actions

# 查找路径（简化版A*算法）
func _find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	# 简化版：直线路径
	return HexGrid.get_line(start, end)

# 找到匹配卡牌属性的精灵
func _find_matching_sprite(card: Card) -> Sprite:
	if card.attributes.is_empty():
		return null
	
	var required_attr = card.attributes[0]
	for sprite in sprites:
		if sprite.is_alive and sprite.attribute == required_attr:
			return sprite
	return null

