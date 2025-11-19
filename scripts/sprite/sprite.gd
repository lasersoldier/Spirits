class_name Sprite
extends SpriteAttribute

# 实时状态
var current_hp: int = 0
var max_hp: int = 0
var hex_position: Vector2i = Vector2i(-1, -1)  # 当前位置（六边形坐标）

# 持有状态
var has_bounty: bool = false  # 是否持有赏金

# 存活状态
var is_alive: bool = true

# 当前所处地形效果
var current_terrain_effects: Dictionary = {}

# 所属玩家ID
var owner_player_id: int = -1

# 当前回合剩余移动力
var remaining_movement: int = 0

# 可执行行动列表
var available_actions: Array[String] = ["move", "attack"]

signal sprite_died(sprite: Sprite)
signal sprite_moved(sprite: Sprite, from: Vector2i, to: Vector2i)
signal sprite_attacked(sprite: Sprite, target: Sprite, damage: int)
signal bounty_acquired(sprite: Sprite)
signal bounty_lost(sprite: Sprite)

func _init(data: Dictionary = {}):
	super._init(data)
	if not data.is_empty():
		max_hp = base_hp
		current_hp = max_hp
		remaining_movement = base_movement

# 初始化回合（每回合开始时调用）
func start_turn():
	var status_mgr = StatusEffectManager.get_instance()
	if status_mgr:
		var bonus = status_mgr.get_movement_bonus(self)
		remaining_movement = max(0, base_movement + bonus)
	else:
		remaining_movement = base_movement

# 移动到新位置
func move_to(new_position: Vector2i):
	var old_position = hex_position
	hex_position = new_position
	sprite_moved.emit(self, old_position, new_position)

# 消耗移动力
func consume_movement(cost: int):
	remaining_movement = max(0, remaining_movement - cost)

# 受到伤害
func take_damage(damage: int):
	var final_damage = max(0, damage)
	var status_mgr = StatusEffectManager.get_instance()
	if status_mgr:
		final_damage = status_mgr.modify_incoming_damage(self, final_damage)
	final_damage = max(0, final_damage)
	if final_damage == 0:
		return
	current_hp = max(0, current_hp - final_damage)
	if current_hp <= 0:
		die()

# 恢复血量
func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)

# 死亡
func die():
	if not is_alive:
		return
	
	is_alive = false
	var status_mgr = StatusEffectManager.get_instance()
	if status_mgr:
		status_mgr.clear_statuses(self)
	if has_bounty:
		lose_bounty()
	sprite_died.emit(self)

# 获得赏金
func acquire_bounty():
	if has_bounty:
		return
	
	has_bounty = true
	max_hp += 2  # 防御加成：血量上限+2
	current_hp += 2  # 同时恢复血量
	bounty_acquired.emit(self)

# 失去赏金
func lose_bounty():
	if not has_bounty:
		return
	
	has_bounty = false
	max_hp = max(base_hp, max_hp - 2)  # 移除防御加成
	current_hp = min(current_hp, max_hp)  # 确保当前血量不超过上限
	bounty_lost.emit(self)

# 攻击目标精灵
func attack_target(target: Sprite, damage: int = 1):
	if not is_alive or not target.is_alive:
		return false
	
	target.take_damage(damage)
	sprite_attacked.emit(self, target, damage)
	return true

# 检查是否在攻击范围内
func is_in_attack_range(target_position: Vector2i, game_map: GameMap = null, terrain_manager: TerrainManager = null) -> bool:
	# 水精灵特殊能力：在相连水流中无视距离攻击
	if attribute == "water" and game_map and terrain_manager:
		var current_terrain = game_map.get_terrain(hex_position)
		var target_terrain = game_map.get_terrain(target_position)
		if current_terrain and current_terrain.terrain_type == TerrainTile.TerrainType.WATER and \
		   target_terrain and target_terrain.terrain_type == TerrainTile.TerrainType.WATER:
			# 检查是否在相连水流中
			var connected_water = terrain_manager.get_connected_water_tiles(hex_position)
			if target_position in connected_water:
				return true  # 无视距离和高度
	
	var distance = HexGrid.hex_distance(hex_position, target_position)
	return distance <= attack_range

# 检查是否在视野范围内
func is_in_vision_range(target_position: Vector2i) -> bool:
	var distance = HexGrid.hex_distance(hex_position, target_position)
	return distance <= vision_range

# 获取可移动到的位置列表（考虑路径高度限制）
func get_movable_positions(game_map: GameMap, terrain_manager: TerrainManager) -> Array[Vector2i]:
	var movable: Array[Vector2i] = []
	
	# 水精灵特殊能力：在相连水流中无视距离和高度移动
	if attribute == "water":
		var current_terrain = game_map.get_terrain(hex_position)
		if current_terrain and current_terrain.terrain_type == TerrainTile.TerrainType.WATER:
			var connected_water = terrain_manager.get_connected_water_tiles(hex_position)
			for water_pos in connected_water:
				if game_map.is_valid_hex_with_terrain(water_pos):
					movable.append(water_pos)
			# 水精灵仍然可以正常移动到非水流位置（在移动范围内）
			var range_hexes = HexGrid.get_hexes_in_range(hex_position, base_movement)
			for hex_pos in range_hexes:
				if hex_pos in connected_water:
					continue  # 已经添加过了
				if not game_map.is_valid_hex_with_terrain(hex_pos):
					continue
				if terrain_manager.can_move_to(self, hex_pos):
					movable.append(hex_pos)
			return movable
	
	# 普通精灵：考虑移动范围惩罚（水流地形）
	var effective_movement = base_movement
	var current_terrain = game_map.get_terrain(hex_position)
	if current_terrain:
		var terrain_effects = terrain_manager.apply_terrain_effects(self, hex_position)
		if terrain_effects.has("movement_range_penalty"):
			effective_movement = max(1, base_movement - terrain_effects.movement_range_penalty)
	
	# 获取移动范围内的所有位置
	var range_hexes = HexGrid.get_hexes_in_range(hex_position, effective_movement)
	
	for hex_pos in range_hexes:
		# 使用坐标白名单检查（必须有实际地形板块）
		if not game_map.is_valid_hex_with_terrain(hex_pos):
			continue
		
		# can_move_to 已经包含了路径高度检查
		if terrain_manager.can_move_to(self, hex_pos):
			movable.append(hex_pos)
	
	return movable

# 获取可攻击的目标位置列表
func get_attackable_positions(game_map: GameMap) -> Array[Vector2i]:
	var attackable: Array[Vector2i] = []
	var range_hexes = HexGrid.get_hexes_in_range(hex_position, attack_range)
	
	for hex in range_hexes:
		# 使用坐标白名单检查（必须有实际地形板块）
		if game_map.is_valid_hex_with_terrain(hex):
			attackable.append(hex)
	
	return attackable

# 更新地形效果
func update_terrain_effects(effects: Dictionary):
	current_terrain_effects = effects
