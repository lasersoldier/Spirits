class_name TerrainManager
extends RefCounted

# 地形变化请求（用于冲突检测）
class TerrainChangeRequest:
	var player_id: int
	var hex_coord: Vector2i
	var new_type: TerrainTile.TerrainType
	var new_level: int
	var duration: int
	
	func _init(p_id: int, coord: Vector2i, type: TerrainTile.TerrainType, level: int, dur: int):
		player_id = p_id
		hex_coord = coord
		new_type = type
		new_level = level
		duration = dur

# 本回合的地形变化请求列表
var terrain_change_requests: Array[TerrainChangeRequest] = []

# 地图引用
var game_map: GameMap

func _init(map: GameMap):
	game_map = map

# 添加地形变化请求
func request_terrain_change(player_id: int, hex_coord: Vector2i, new_type: TerrainTile.TerrainType, new_level: int = -1, duration: int = -1):
	var request = TerrainChangeRequest.new(player_id, hex_coord, new_type, new_level, duration)
	terrain_change_requests.append(request)

# 处理本回合的所有地形变化（结算阶段调用）
func resolve_terrain_changes():
	# 按坐标分组请求
	var requests_by_coord: Dictionary = {}
	
	for request in terrain_change_requests:
		var key = _coord_to_key(request.hex_coord)
		if not requests_by_coord.has(key):
			requests_by_coord[key] = []
		requests_by_coord[key].append(request)
	
	# 处理每个坐标的请求
	for key in requests_by_coord.keys():
		var requests = requests_by_coord[key]
		_handle_coord_requests(requests)
	
	# 清空请求列表
	terrain_change_requests.clear()

# 处理同一坐标的多个请求
func _handle_coord_requests(requests: Array[TerrainChangeRequest]):
	if requests.size() == 0:
		return
	
	# 如果只有一个请求，直接应用
	if requests.size() == 1:
		var request = requests[0]
		game_map.modify_terrain(request.hex_coord, request.new_type, request.new_level, request.duration)
		return
	
	# 多个请求：检查是否完全一致
	var first_request = requests[0]
	var all_same = true
	
	for request in requests:
		if request.new_type != first_request.new_type or \
		   request.new_level != first_request.new_level or \
		   request.duration != first_request.duration:
			all_same = false
			break
	
	# 如果所有请求完全一致，则应用
	if all_same:
		game_map.modify_terrain(first_request.hex_coord, first_request.new_type, first_request.new_level, first_request.duration)
	# 否则保持原状（冲突处理规则）
	else:
		pass  # 地形保持不变

# 应用地形效果（移动加成、隐藏效果等）
func apply_terrain_effects(sprite: Sprite, hex_coord: Vector2i) -> Dictionary:
	var effects = {
		"movement_bonus": 0,
		"movement_cost_multiplier": 1.0,
		"is_hidden": false,
		"can_attack": true
	}
	
	var terrain = game_map.get_terrain(hex_coord)
	if not terrain:
		return effects
	
	# 水流地形效果
	if terrain.has_guide_effect():
		if sprite.attribute == "water":
			effects.movement_bonus = 1  # 水属性精灵移动距离+1
		else:
			effects.movement_cost_multiplier = 2.0  # 非水属性移动成本+1（需消耗2点移动力）
	
	# 森林隐藏效果
	if terrain.has_hide_effect():
		effects.is_hidden = true
	
	# 高度限制检查（需要在攻击判定中单独处理）
	
	return effects

# 检查精灵是否可以移动到目标地形
func can_move_to(sprite: Sprite, target_hex: Vector2i) -> bool:
	var terrain = game_map.get_terrain(target_hex)
	if not terrain:
		return false
	
	# 飞行精灵可以无视地形
	if sprite.has_mechanism("flight"):
		return true
	
	# 其他精灵需要检查地形是否可通行
	# 这里可以添加更多地形通行规则
	
	return true

# 检查攻击高度限制
func can_attack_height(attacker_level: int, target_level: int, height_limit: String) -> bool:
	match height_limit:
		"none":
			return true
		"same_or_high_to_low":
			return attacker_level >= target_level
		"same_or_low_to_high":
			return attacker_level <= target_level
		"same_only":
			return attacker_level == target_level
		_:
			return true

# 更新地形效果持续时间
func update_terrain_durations():
	for key in game_map.terrain_tiles.keys():
		var terrain = game_map.terrain_tiles[key]
		if terrain.effect_duration > 0:
			terrain.decrease_duration()
			if terrain.is_effect_expired():
				# 效果过期，恢复为普通地形
				terrain.terrain_type = TerrainTile.TerrainType.NORMAL
				terrain.height_level = 1

func _coord_to_key(hex_coord: Vector2i) -> String:
	return str(hex_coord.x) + "_" + str(hex_coord.y)

