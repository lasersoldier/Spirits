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
	current_hp = max(0, current_hp - damage)
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
func is_in_attack_range(target_position: Vector2i) -> bool:
	var distance = HexGrid.hex_distance(hex_position, target_position)
	return distance <= attack_range

# 检查是否在视野范围内
func is_in_vision_range(target_position: Vector2i) -> bool:
	var distance = HexGrid.hex_distance(hex_position, target_position)
	return distance <= vision_range

# 获取可移动到的位置列表（简化版，实际需要路径规划）
func get_movable_positions(game_map: GameMap, terrain_manager: TerrainManager) -> Array[Vector2i]:
	var movable: Array[Vector2i] = []
	var neighbors = HexGrid.get_neighbors(hex_position)
	
	for neighbor in neighbors:
		# 使用坐标白名单检查（必须有实际地形板块）
		if not game_map.is_valid_hex_with_terrain(neighbor):
			continue
		
		if terrain_manager.can_move_to(self, neighbor):
			movable.append(neighbor)
	
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

