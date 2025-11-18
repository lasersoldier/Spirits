class_name ActionResolver
extends RefCounted

# 行动类型枚举
enum ActionType {
	EFFECT,      # 效果结算（辅助类卡牌效果）
	TERRAIN,     # 地形变化
	ATTACK,      # 攻击效果
	MOVE,        # 移动操作
	OTHER        # 其他辅助效果
}

# 行动类
class Action:
	var player_id: int
	var action_type: ActionType
	var sprite: Sprite
	var target: Variant  # 可以是Sprite、Vector2i等
	var card: Card  # 如果是卡牌行动
	var data: Dictionary  # 额外数据
	
	func _init(p_id: int, type: ActionType, spr: Sprite, tgt: Variant, c: Card = null, d: Dictionary = {}):
		player_id = p_id
		action_type = type
		sprite = spr
		target = tgt
		card = c
		data = d

# 本回合的所有行动
var actions: Array[Action] = []

# 系统引用
var game_map: GameMap
var terrain_manager: TerrainManager
var card_interface: CardSpriteInterface
var energy_manager: EnergyManager

signal action_resolved(action: Action, result: Dictionary)

func _init(map: GameMap, terrain_mgr: TerrainManager, card_intf: CardSpriteInterface, energy_mgr: EnergyManager):
	game_map = map
	terrain_manager = terrain_mgr
	card_interface = card_intf
	energy_manager = energy_mgr

# 添加行动
func add_action(player_id: int, action_type: ActionType, sprite: Sprite, target: Variant, card: Card = null, data: Dictionary = {}):
	var action = Action.new(player_id, action_type, sprite, target, card, data)
	actions.append(action)

# 清空行动列表
func clear_actions():
	actions.clear()

# 移除指定索引的行动
func remove_action(index: int) -> Action:
	if index < 0 or index >= actions.size():
		return null
	var action = actions[index]
	actions.remove_at(index)
	return action

# 通过行动对象引用移除行动
func remove_action_by_reference(action: Action) -> Action:
	var index = actions.find(action)
	if index >= 0:
		return remove_action(index)
	return null

# 结算所有行动（按优先级）
func resolve_all_actions():
	# 按优先级分组行动
	var effect_actions: Array[Action] = []
	var terrain_actions: Array[Action] = []
	var attack_actions: Array[Action] = []
	var move_actions: Array[Action] = []
	var other_actions: Array[Action] = []
	
	for action in actions:
		match action.action_type:
			ActionType.EFFECT:
				effect_actions.append(action)
			ActionType.TERRAIN:
				terrain_actions.append(action)
			ActionType.ATTACK:
				attack_actions.append(action)
			ActionType.MOVE:
				move_actions.append(action)
			ActionType.OTHER:
				other_actions.append(action)
	
	# 按优先级顺序结算
	_resolve_actions(effect_actions)
	_resolve_actions(terrain_actions)
	# 地形变化执行后，立即应用到地图（这样后续的移动可以正确检查路径高度）
	terrain_manager.resolve_terrain_changes()
	_resolve_actions(attack_actions)
	_resolve_actions(move_actions)
	_resolve_actions(other_actions)
	
	# 清空行动列表
	clear_actions()

# 结算一组行动
func _resolve_actions(action_group: Array[Action]):
	for action in action_group:
		var result = _resolve_single_action(action)
		action_resolved.emit(action, result)

# 结算单个行动
func _resolve_single_action(action: Action) -> Dictionary:
	var result = {
		"success": false,
		"message": ""
	}
	
	match action.action_type:
		ActionType.EFFECT:
			result = _resolve_effect_action(action)
		ActionType.TERRAIN:
			result = _resolve_terrain_action(action)
		ActionType.ATTACK:
			result = _resolve_attack_action(action)
		ActionType.MOVE:
			result = _resolve_move_action(action)
		ActionType.OTHER:
			result = _resolve_other_action(action)
	
	return result

# 结算效果行动（辅助类卡牌）
func _resolve_effect_action(action: Action) -> Dictionary:
	if not action.card:
		return {"success": false, "message": "无效的行动"}
	
	var result = card_interface.apply_card_effect(action.card, action.sprite, action.target, game_map, terrain_manager)
	
	# 消耗能量
	if result.success:
		energy_manager.use_card(action.player_id, action.card.energy_cost)
		action.card.use()
	
	return result

# 结算地形行动
func _resolve_terrain_action(action: Action) -> Dictionary:
	if not action.card or not action.target is Vector2i:
		return {"success": false, "message": "无效的地形行动"}
	
	# 使用 apply_card_effect 统一处理地形效果（包括高度修改）
	var result = card_interface.apply_card_effect(action.card, action.sprite, action.target, game_map, terrain_manager)
	
	# 消耗能量
	if result.success:
		energy_manager.use_card(action.player_id, action.card.energy_cost)
		action.card.use()
	
	return result

# 结算攻击行动
func _resolve_attack_action(action: Action) -> Dictionary:
	if not action.target is Sprite:
		return {"success": false, "message": "无效的攻击目标"}
	
	var target = action.target as Sprite
	var is_basic_action = action.data.get("is_basic_action", false)
	var player_id = action.player_id
	
	# 如果是基本行动（弃牌攻击），使用 execute_attack
	if is_basic_action:
		return execute_attack(action.sprite, target, is_basic_action, player_id, action.card)
	
	# 如果是卡牌攻击，使用 apply_card_effect 处理（包括附带的地形修改效果）
	if action.card:
		# 检查攻击范围
		if not action.sprite.is_in_attack_range(target.hex_position):
			return {"success": false, "message": "目标不在攻击范围内"}
		
		# 检查高度限制
		var attacker_terrain = game_map.get_terrain(action.sprite.hex_position)
		var target_terrain = game_map.get_terrain(target.hex_position)
		var attacker_level = attacker_terrain.height_level if attacker_terrain else 1
		var target_level = target_terrain.height_level if target_terrain else 1
		
		if not terrain_manager.can_attack_height(attacker_level, target_level, action.sprite.attack_height_limit):
			return {"success": false, "message": "高度限制：无法攻击该目标"}
		
		# 使用 apply_card_effect 处理卡牌效果（包括攻击和附带的地形修改）
		var result = card_interface.apply_card_effect(action.card, action.sprite, target, game_map, terrain_manager)
		
		# 消耗能量
		if result.success:
			energy_manager.use_card(player_id, action.card.energy_cost)
			action.card.use()
		
		return result
	
	# 默认使用 execute_attack
	return execute_attack(action.sprite, target, is_basic_action, player_id, action.card)

# 执行攻击（公共方法，可直接调用）
func execute_attack(sprite: Sprite, target: Sprite, is_basic_action: bool = false, player_id: int = -1, card: Card = null) -> Dictionary:
	# 检查攻击范围
	if not sprite.is_in_attack_range(target.hex_position):
		return {"success": false, "message": "目标不在攻击范围内"}
	
	# 检查高度限制
	var attacker_terrain = game_map.get_terrain(sprite.hex_position)
	var target_terrain = game_map.get_terrain(target.hex_position)
	var attacker_level = attacker_terrain.height_level if attacker_terrain else 1
	var target_level = target_terrain.height_level if target_terrain else 1
	
	if not terrain_manager.can_attack_height(attacker_level, target_level, sprite.attack_height_limit):
		return {"success": false, "message": "高度限制：无法攻击该目标"}
	
	# 计算伤害（基本攻击固定1点）
	var damage = 1
	# 基本行动：固定1点伤害，不消耗能量
	
	# 执行攻击
	sprite.attack_target(target, damage)
	
	return {"success": true, "message": "造成" + str(damage) + "点伤害"}

# 结算移动行动
func _resolve_move_action(action: Action) -> Dictionary:
	if not action.target is Vector2i:
		return {"success": false, "message": "无效的移动目标"}
	
	var target_pos = action.target as Vector2i
	var is_basic_action = action.data.get("is_basic_action", false)
	var player_id = action.player_id
	
	return execute_move(action.sprite, target_pos, is_basic_action, player_id, action.card)

# 执行移动（公共方法，可直接调用）
func execute_move(sprite: Sprite, target_pos: Vector2i, is_basic_action: bool = false, player_id: int = -1, card: Card = null) -> Dictionary:
	# 检查路径高度有效性
	var path_check = terrain_manager.check_path_height_validity(sprite, sprite.hex_position, target_pos)
	
	# 确定实际移动目标（如果路径被阻挡，使用最后一个有效位置）
	var actual_target_pos = path_check.final_position
	
	# 如果最终位置与起点相同，检查是否是路径阻挡导致的
	if actual_target_pos == sprite.hex_position:
		if path_check.valid:
			# 路径有效但位置相同，说明是原地停留，返回失败
			return {"success": false, "message": "无法移动到该位置"}
		else:
			# 路径被阻挡且停在起点，允许移动但移动距离为0
			# 这样后续移动可以从正确位置开始计算
			var old_pos = sprite.hex_position
			sprite.move_to(actual_target_pos)  # 虽然位置没变，但确保状态更新
			
			if is_basic_action:
				print("执行移动（基本行动，不消耗移动力）: ", sprite.sprite_name, " 尝试移动到 ", target_pos, " 但路径被高度阻挡，停在起点 ", actual_target_pos)
			else:
				# 卡牌行动：即使停在起点，也消耗1点移动力（尝试移动的代价）
				var movement_cost = 1
				if sprite.remaining_movement < movement_cost:
					# 如果移动力不足，恢复位置并返回失败
					sprite.move_to(old_pos)
					return {"success": false, "message": "移动力不足（尝试移动需要 1，剩余 " + str(sprite.remaining_movement) + "）"}
				sprite.consume_movement(movement_cost)
				print("执行移动: ", sprite.sprite_name, " 尝试移动到 ", target_pos, " 但路径被高度阻挡，停在起点 ", actual_target_pos, " 消耗移动力: ", movement_cost, " 剩余移动力: ", sprite.remaining_movement)
			
			# 更新地形效果（使用起点位置）
			var terrain_effects = terrain_manager.apply_terrain_effects(sprite, actual_target_pos)
			sprite.update_terrain_effects(terrain_effects)
			
			return {"success": true, "message": "路径被高度阻挡，停在起点"}
	
	# 检查实际目标位置是否有地形
	if not terrain_manager.can_move_to(sprite, actual_target_pos):
		return {"success": false, "message": "无法移动到该位置"}
	
	# 检查移动距离（使用实际目标位置）
	var distance = HexGrid.hex_distance(sprite.hex_position, actual_target_pos)
	var movement_cost = distance
	
	# 应用地形效果（使用实际目标位置）
	var terrain_effects = terrain_manager.apply_terrain_effects(sprite, actual_target_pos)
	if terrain_effects.movement_bonus > 0:
		movement_cost = max(1, movement_cost - terrain_effects.movement_bonus)
	if terrain_effects.movement_cost_multiplier > 1.0:
		movement_cost = int(ceil(movement_cost * terrain_effects.movement_cost_multiplier))
	
	# 检查移动力
	# 基本行动（弃牌行动）：不消耗移动力，允许在同一回合内多次移动
	# 卡牌行动：正常消耗移动力
	if is_basic_action:
		# 基本行动：不消耗移动力，但需要检查距离是否合理（限制在基础移动力范围内）
		# 允许超出当前剩余移动力，因为基本行动不消耗移动力
		if movement_cost > sprite.base_movement:
			return {"success": false, "message": "移动距离超出基础移动力范围（距离: " + str(movement_cost) + "，基础移动力: " + str(sprite.base_movement) + "）"}
	else:
		# 卡牌行动：正常检查并消耗移动力
		if sprite.remaining_movement < movement_cost:
			return {"success": false, "message": "移动力不足（需要 " + str(movement_cost) + "，剩余 " + str(sprite.remaining_movement) + "）"}
	
	# 执行移动（使用实际目标位置）
	var old_pos = sprite.hex_position
	sprite.move_to(actual_target_pos)
	
	# 如果路径被阻挡，在消息中说明
	if not path_check.valid:
		print("路径被高度阻挡，精灵移动到最后一个有效位置: ", actual_target_pos, " (原目标: ", target_pos, ", 阻挡位置: ", path_check.blocked_at, ")")
		print("  调试：起点位置 ", old_pos, " -> 实际到达位置 ", actual_target_pos, " (后续移动将从该位置开始)")
	
	# 只有非基本行动才消耗移动力
	if not is_basic_action:
		sprite.consume_movement(movement_cost)
	
	sprite.update_terrain_effects(terrain_effects)
	
	if is_basic_action:
		print("执行移动（基本行动，不消耗移动力）: ", sprite.sprite_name, " 从 ", old_pos, " 移动到 ", sprite.hex_position, " 移动距离: ", movement_cost, " 移动力保持: ", sprite.remaining_movement, "/", sprite.base_movement)
		if not path_check.valid:
			print("  注意：原目标位置 ", target_pos, " 因高度阻挡无法到达，已移动到 ", sprite.hex_position)
			print("  调试：精灵当前位置已更新为 ", sprite.hex_position, "，后续移动将从该位置开始计算")
	else:
		print("执行移动: ", sprite.sprite_name, " 从 ", old_pos, " 移动到 ", sprite.hex_position, " 消耗移动力: ", movement_cost, " 剩余移动力: ", sprite.remaining_movement)
		if not path_check.valid:
			print("  注意：原目标位置 ", target_pos, " 因高度阻挡无法到达，已移动到 ", sprite.hex_position)
			print("  调试：精灵当前位置已更新为 ", sprite.hex_position, "，后续移动将从该位置开始计算")
	
	# 如果是卡牌行动，消耗能量（基本行动不消耗）
	if card and not is_basic_action and player_id >= 0:
		energy_manager.use_card(player_id, card.energy_cost)
		card.use()
	
	return {"success": true, "message": "移动到" + str(target_pos)}

# 结算其他行动
func _resolve_other_action(_action: Action) -> Dictionary:
	# 处理其他类型的行动
	return {"success": true, "message": "行动已执行"}

# 生成行动预览描述
func get_action_preview(action: Action) -> Dictionary:
	var preview = {
		"type": "",
		"sprite_name": "",
		"target_description": "",
		"description": "",
		"action": action
	}
	
	if not action.sprite:
		return preview
	
	preview.sprite_name = action.sprite.sprite_name
	
	match action.action_type:
		ActionType.EFFECT:
			preview.type = "特殊效果"
			if action.card:
				preview.description = action.card.card_name
			if action.target is Sprite:
				preview.target_description = "目标: " + (action.target as Sprite).sprite_name
			else:
				preview.target_description = "目标: " + str(action.target)
		
		ActionType.TERRAIN:
			preview.type = "地形变化"
			if action.card:
				preview.description = action.card.card_name
			if action.target is Vector2i:
				preview.target_description = "位置: " + str(action.target)
		
		ActionType.ATTACK:
			preview.type = "攻击"
			if action.target is Sprite:
				var target = action.target as Sprite
				preview.target_description = "目标: " + target.sprite_name
				if action.card:
					preview.description = action.card.card_name
				else:
					preview.description = "基本攻击"
		
		ActionType.MOVE:
			preview.type = "移动"
			if action.target is Vector2i:
				preview.target_description = "目标位置: " + str(action.target)
				if action.card:
					preview.description = action.card.card_name
				else:
					preview.description = "基本移动"
		
		ActionType.OTHER:
			preview.type = "其他"
			preview.description = "其他行动"
	
	return preview

# 获取所有行动的预览列表
func get_all_action_previews() -> Array[Dictionary]:
	var previews: Array[Dictionary] = []
	for action in actions:
		previews.append(get_action_preview(action))
	return previews

