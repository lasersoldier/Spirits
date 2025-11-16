class_name TerrainManager
extends RefCounted

# 地形变化请求（用于冲突检测）
class TerrainChangeRequest:
	var player_id: int
	var hex_coord: Vector2i
	var new_type: TerrainTile.TerrainType
	var new_level: int  # 绝对高度值（-1表示不设置）
	var height_delta: int  # 相对高度修改值（+1表示抬高1级，-2表示降低2级，0表示不修改高度）
	var duration: int
	
	func _init(p_id: int, coord: Vector2i, type: TerrainTile.TerrainType, level: int, dur: int, delta: int = 0):
		player_id = p_id
		hex_coord = coord
		new_type = type
		new_level = level
		height_delta = delta
		duration = dur

# 本回合的地形变化请求列表
var terrain_change_requests: Array[TerrainChangeRequest] = []

# 地图引用
var game_map: GameMap

func _init(map: GameMap):
	game_map = map

# 添加地形变化请求
func request_terrain_change(player_id: int, hex_coord: Vector2i, new_type: TerrainTile.TerrainType, new_level: int = -1, duration: int = -1, height_delta: int = 0):
	var request = TerrainChangeRequest.new(player_id, hex_coord, new_type, new_level, duration, height_delta)
	terrain_change_requests.append(request)

# 处理本回合的所有地形变化（结算阶段调用）
func resolve_terrain_changes():
	if terrain_change_requests.is_empty():
		return
	
	# 按坐标分组请求
	var requests_by_coord: Dictionary = {}
	
	for request in terrain_change_requests:
		var key = _coord_to_key(request.hex_coord)
		if not requests_by_coord.has(key):
			requests_by_coord[key] = [] as Array[TerrainChangeRequest]
		requests_by_coord[key].append(request)
	
	# 处理每个坐标的请求
	for key in requests_by_coord.keys():
		var requests: Array[TerrainChangeRequest] = requests_by_coord[key]
		_handle_coord_requests(requests)
	
	# 清空请求列表
	terrain_change_requests.clear()

# 处理同一坐标的多个请求
func _handle_coord_requests(requests: Array[TerrainChangeRequest]):
	if requests.size() == 0:
		return
	
	# 获取当前地形
	var coord = requests[0].hex_coord
	var current_terrain = game_map.get_terrain(coord)
	var current_height = 1
	if current_terrain:
		current_height = current_terrain.height_level
	
	# 如果只有一个请求，直接应用
	if requests.size() == 1:
		var request = requests[0]
		var final_height = request.new_level
		var final_type = request.new_type
		var final_duration = request.duration
		
		# 处理相对高度修改
		if request.height_delta != 0:
			final_height = current_height + request.height_delta
			final_height = clamp(final_height, 1, 3)  # 限制在1-3级
		elif request.new_level > 0:
			final_height = request.new_level
		else:
			# 保持当前高度
			if current_terrain:
				final_height = current_terrain.height_level
			else:
				final_height = 1
		
		# 如果未指定类型，保持当前类型
		if final_type == TerrainTile.TerrainType.NORMAL and current_terrain:
			final_type = current_terrain.terrain_type
		
		game_map.modify_terrain(coord, final_type, final_height, final_duration)
		return
	
	# 多个请求：处理冲突
	# 分离高度修改请求和地形类型修改请求
	var height_deltas: Array[int] = []
	var absolute_heights: Array[int] = []
	var terrain_types: Array[TerrainTile.TerrainType] = []
	var durations: Array[int] = []
	
	for request in requests:
		if request.height_delta != 0:
			height_deltas.append(request.height_delta)
		elif request.new_level > 0:
			absolute_heights.append(request.new_level)
		
		if request.new_type != TerrainTile.TerrainType.NORMAL or not current_terrain:
			terrain_types.append(request.new_type)
		
		if request.duration >= 0:
			durations.append(request.duration)
	
	# 处理高度冲突
	var final_height = current_height
	if height_deltas.size() > 0:
		# 分离抬高和降低
		var raise_deltas: Array[int] = []
		var lower_deltas: Array[int] = []
		
		for delta in height_deltas:
			if delta > 0:
				raise_deltas.append(delta)
			elif delta < 0:
				lower_deltas.append(delta)
		
		# 冲突处理规则
		if raise_deltas.size() > 0 and lower_deltas.size() > 0:
			# 一正一负：完全抵消，无关数值（当前两人游戏规则）
			# 未来多人游戏：先抵消，然后保留绝对值小的
			# 这里先实现当前规则（完全抵消）
			var total_raise = 0
			var total_lower = 0
			for delta in raise_deltas:
				total_raise += delta
			for delta in lower_deltas:
				total_lower += abs(delta)
			
			# 当前规则：完全抵消
			var net_delta = 0
			
			# 未来扩展：如果有多人游戏，可以在这里实现：
			# if requests.size() > 2:  # 多人游戏
			#     net_delta = total_raise - total_lower
			#     if net_delta > 0:
			#         # 保留绝对值小的降低
			#         var min_lower = lower_deltas[0]
			#         for delta in lower_deltas:
			#             if abs(delta) < abs(min_lower):
			#                 min_lower = delta
			#         net_delta = -min_lower
			#     elif net_delta < 0:
			#         # 保留绝对值小的抬高
			#         var min_raise = raise_deltas[0]
			#         for delta in raise_deltas:
			#             if delta < min_raise:
			#                 min_raise = delta
			#         net_delta = min_raise
			
			final_height = current_height + net_delta
		elif raise_deltas.size() > 0:
			# 只有抬高：取最大值，限制在3级
			var max_raise = raise_deltas[0]
			for delta in raise_deltas:
				if delta > max_raise:
					max_raise = delta
			final_height = current_height + max_raise
		elif lower_deltas.size() > 0:
			# 只有降低：取最小值（绝对值最大），限制在1级
			var min_lower = lower_deltas[0]
			for delta in lower_deltas:
				if delta < min_lower:
					min_lower = delta
			final_height = current_height + min_lower
		
		# 应用边界限制
		final_height = clamp(final_height, 1, 3)
	elif absolute_heights.size() > 0:
		# 使用绝对高度值（如果有多个，取第一个）
		final_height = absolute_heights[0]
		final_height = clamp(final_height, 1, 3)
	
	# 处理地形类型冲突（使用第一个非NORMAL类型，如果没有则保持当前类型）
	var final_type = TerrainTile.TerrainType.NORMAL
	if terrain_types.size() > 0:
		final_type = terrain_types[0]
	elif current_terrain:
		final_type = current_terrain.terrain_type
	
	# 处理持续时间（使用第一个非-1的持续时间）
	var final_duration = -1
	if durations.size() > 0:
		final_duration = durations[0]
	
	# 应用最终结果
	game_map.modify_terrain(coord, final_type, final_height, final_duration)

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

# 检查路径高度有效性（检查从起点到终点的路径上相邻格子的高度差）
func check_path_height_validity(sprite: Sprite, start_pos: Vector2i, target_pos: Vector2i) -> Dictionary:
	# 飞行和钻地精灵可以无视高度限制
	if sprite.has_mechanism("flight") or sprite.has_mechanism("burrow"):
		return {"valid": true, "final_position": target_pos, "blocked_at": Vector2i(-1, -1)}
	
	# 获取路径上的所有坐标
	var path_hexes = HexGrid.get_line(start_pos, target_pos)
	if path_hexes.size() <= 1:
		# 起点和终点相同，或者路径为空
		return {"valid": true, "final_position": start_pos, "blocked_at": Vector2i(-1, -1)}
	
	# 获取起点地形高度
	var start_terrain = game_map.get_terrain(start_pos)
	var start_height = start_terrain.height_level if start_terrain else 1
	
	var last_valid_pos = start_pos
	
	# 检查路径上相邻格子之间的高度差
	for i in range(1, path_hexes.size()):
		var current_pos = path_hexes[i - 1]
		var next_pos = path_hexes[i]
		
		# 获取当前和下一个位置的地形高度
		var current_terrain = game_map.get_terrain(current_pos)
		var next_terrain = game_map.get_terrain(next_pos)
		
		if not current_terrain or not next_terrain:
			# 如果某个位置没有地形，跳过（这种情况不应该发生，但为了安全）
			continue
		
		var current_height = current_terrain.height_level
		var next_height = next_terrain.height_level
		var height_diff = abs(next_height - current_height)
		
		# 普通精灵：相邻格子高度差不能超过1
		if height_diff > 1:
			# 路径被阻挡，返回最后一个有效位置
			print("  调试路径检查：从 ", current_pos, " (高度", current_height, ") 到 ", next_pos, " (高度", next_height, ") 高度差为 ", height_diff, "，路径被阻挡")
			print("  调试路径检查：返回最后一个有效位置 ", last_valid_pos)
			return {"valid": false, "final_position": last_valid_pos, "blocked_at": next_pos}
		
		# 当前位置有效，更新最后一个有效位置
		last_valid_pos = next_pos
	
	# 整个路径都有效
	return {"valid": true, "final_position": target_pos, "blocked_at": Vector2i(-1, -1)}

# 检查精灵是否可以移动到目标地形
func can_move_to(sprite: Sprite, target_hex: Vector2i) -> bool:
	var terrain = game_map.get_terrain(target_hex)
	if not terrain:
		return false
	
	# 检查路径高度有效性
	var path_check = check_path_height_validity(sprite, sprite.hex_position, target_hex)
	if not path_check.valid:
		# 路径被阻挡，不能移动到目标位置
		return false
	
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
# 只处理有明确持续时间的地形效果（如"持续3回合"的水流地形）
# 对于纯高度变化（没有持续时间信息），应该是永久效果（-1），不会被处理
func update_terrain_durations():
	var expired_coords: Array[Vector2i] = []
	for key in game_map.terrain_tiles.keys():
		var terrain = game_map.terrain_tiles[key]
		if terrain.effect_duration > 0:
			terrain.decrease_duration()
			if terrain.is_effect_expired():
				# 效果过期，只恢复地形类型，不改变高度
				# 地形高度变化应该是永久的，不应该被重置
				var coord = terrain.hex_coord
				var current_height = terrain.height_level  # 保持当前高度
				expired_coords.append(coord)
				# 恢复为普通地形，但保持当前高度（使用 modify_terrain 确保信号被发出）
				game_map.modify_terrain(coord, TerrainTile.TerrainType.NORMAL, current_height, -1)

func _coord_to_key(hex_coord: Vector2i) -> String:
	return str(hex_coord.x) + "_" + str(hex_coord.y)
