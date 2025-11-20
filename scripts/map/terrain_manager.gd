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
	var is_card_created: bool  # 是否通过卡牌创建（用于标记水源）
	
	func _init(p_id: int, coord: Vector2i, type: TerrainTile.TerrainType, level: int, dur: int, delta: int = 0, is_card: bool = true):
		player_id = p_id
		hex_coord = coord
		new_type = type
		new_level = level
		height_delta = delta
		duration = dur
		is_card_created = is_card

# 本回合的地形变化请求列表
var terrain_change_requests: Array[TerrainChangeRequest] = []

# 地图引用
var game_map: GameMap

func _init(map: GameMap):
	game_map = map

# 添加地形变化请求
# is_card_created: 是否通过卡牌创建（默认为true，因为通常通过此方法调用的都是卡牌效果）
func request_terrain_change(player_id: int, hex_coord: Vector2i, new_type: TerrainTile.TerrainType, new_level: int = -1, duration: int = -1, height_delta: int = 0, is_card_created: bool = true):
	print("TerrainManager: request_terrain_change 被调用 - 坐标: ", hex_coord, " 高度变化: ", height_delta, " 设置高度: ", new_level, " 当前请求数量: ", terrain_change_requests.size())
	# 检查基岩保护
	var current_terrain = game_map.get_terrain(hex_coord)
	if current_terrain and not current_terrain.can_be_modified():
		push_warning("TerrainManager: 基岩地形不可修改: " + str(hex_coord))
		print("TerrainManager: 请求被拒绝 - 基岩保护")
		return
	
	# 检查是否试图创建基岩地形（基岩只能通过地图配置创建）
	if new_type == TerrainTile.TerrainType.BEDROCK and not current_terrain:
		push_warning("TerrainManager: 不能通过卡牌创建基岩地形: " + str(hex_coord))
		print("TerrainManager: 请求被拒绝 - 不能创建基岩")
		return
	
	var request = TerrainChangeRequest.new(player_id, hex_coord, new_type, new_level, duration, height_delta, is_card_created)
	terrain_change_requests.append(request)
	print("TerrainManager: 地形变化请求已添加 - 坐标: ", hex_coord, " 新请求数量: ", terrain_change_requests.size())

# 处理本回合的所有地形变化（结算阶段调用）
func resolve_terrain_changes():
	if terrain_change_requests.is_empty():
		return
	
	print("TerrainManager: 开始处理 ", terrain_change_requests.size(), " 个地形变化请求")
	
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
	print("TerrainManager: 地形变化请求处理完成")

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
		
		print("TerrainManager: 应用地形变化 - 坐标: ", coord, " 从高度 ", current_height, " 改为高度 ", final_height)
		game_map.modify_terrain(coord, final_type, final_height, final_duration, 0, request.is_card_created)
		# 验证地形已更新
		var updated_terrain = game_map.get_terrain(coord)
		if updated_terrain:
			print("TerrainManager: 验证地形已更新 - 坐标: ", coord, " 当前高度: ", updated_terrain.height_level)
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
	
	# 应用最终结果（多个请求时，如果任何一个是通过卡牌创建的，就标记为卡牌创建）
	var is_card_created = false
	for req in requests:
		if req.is_card_created:
			is_card_created = true
			break
	game_map.modify_terrain(coord, final_type, final_height, final_duration, 0, is_card_created)

# 应用地形效果（移动加成、隐藏效果等）
func apply_terrain_effects(sprite: Sprite, hex_coord: Vector2i) -> Dictionary:
	var effects = {
		"movement_bonus": 0,
		"movement_cost_multiplier": 1.0,
		"movement_range_penalty": 0,  # 移动范围惩罚（用于水流）
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
			# 非水属性精灵在水流上移动范围-1（最小为1）
			effects.movement_range_penalty = 1
	
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
				# 这不是卡牌创建，所以 is_card_created=false
				game_map.modify_terrain(coord, TerrainTile.TerrainType.NORMAL, current_height, -1, 0, false)

# 获取相连的水流地形（通过水流可以到达的所有位置）
# 使用广度优先搜索
func get_connected_water_tiles(start_coord: Vector2i) -> Array[Vector2i]:
	var connected: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_coord]
	
	# 检查起点是否是水流
	var start_terrain = game_map.get_terrain(start_coord)
	if not start_terrain or start_terrain.terrain_type != TerrainTile.TerrainType.WATER:
		return connected
	
	visited[_coord_to_key(start_coord)] = true
	
	while queue.size() > 0:
		var current_coord = queue.pop_front()
		connected.append(current_coord)
		
		# 获取相邻地形
		var neighbors = HexGrid.get_neighbors(current_coord)
		for neighbor_coord in neighbors:
			var key = _coord_to_key(neighbor_coord)
			if visited.has(key):
				continue
			
			# 检查坐标是否有效
			if not game_map.is_valid_hex_with_terrain(neighbor_coord):
				continue
			
			var neighbor_terrain = game_map.get_terrain(neighbor_coord)
			if neighbor_terrain and neighbor_terrain.terrain_type == TerrainTile.TerrainType.WATER:
				visited[key] = true
				queue.append(neighbor_coord)
	
	return connected

# 处理水流传播（水往低处流）
# 规则：每回合重新计算水流，只保留高度>1的水流作为水源，从水源重新扩散
func spread_water_flow():
	# 第一步：收集所有水源（高度>1的水流地形）的坐标和原始地形类型
	var water_sources: Array[Dictionary] = []  # [{coord: Vector2i, original_type: TerrainType, height: int}]
	var non_source_water_coords: Array[Vector2i] = []  # 需要清除的非水源水流
	
	# 遍历所有地形，分类水源和非水源水流
	for key in game_map.terrain_tiles.keys():
		var terrain = game_map.terrain_tiles[key]
		if terrain.terrain_type == TerrainTile.TerrainType.WATER:
			# 水源条件：高度>1 或 标记为水源（通过卡牌创建的，即使高度降到1也保持为水源）
			if terrain.height_level > 1 or terrain.is_water_source:
				# 水源：记录坐标和高度
				# 注意：水源本身保持为水流，不需要恢复
				water_sources.append({
					"coord": terrain.hex_coord,
					"height": terrain.height_level
				})
			else:
				# 非水源水流：需要清除，恢复为普通地形
				non_source_water_coords.append(terrain.hex_coord)
	
	# 第二步：清除所有非水源的水流地形（恢复为普通地形，保持高度）
	for coord in non_source_water_coords:
		var terrain = game_map.get_terrain(coord)
		if terrain and terrain.terrain_type == TerrainTile.TerrainType.WATER:
			# 恢复为普通地形，保持当前高度
			# 这不是卡牌创建，所以 is_card_created=false
			var current_height = terrain.height_level
			game_map.modify_terrain(coord, TerrainTile.TerrainType.NORMAL, current_height, -1, 0, false)
	
	# 第三步：从所有水源重新计算流向
	for source_info in water_sources:
		var source_coord = source_info.coord
		var source_height = source_info.height
		
		var water_terrain = game_map.get_terrain(source_coord)
		if not water_terrain or water_terrain.terrain_type != TerrainTile.TerrainType.WATER:
			continue
		
		# 使用广度优先搜索从水源扩散
		var visited: Dictionary = {}
		var queue: Array[Dictionary] = [{"coord": source_coord, "height": source_height}]
		visited[_coord_to_key(source_coord)] = true
		
		while queue.size() > 0:
			var current = queue.pop_front()
			var current_coord = current.coord
			var current_height = current.height
			
			# 获取相邻地形
			var neighbors = HexGrid.get_neighbors(current_coord)
			for neighbor_coord in neighbors:
				var key = _coord_to_key(neighbor_coord)
				if visited.has(key):
					continue
				
				# 检查坐标是否有效
				if not game_map.is_valid_hex_with_terrain(neighbor_coord):
					continue
				
				var neighbor_terrain = game_map.get_terrain(neighbor_coord)
				if not neighbor_terrain:
					continue
				
				var neighbor_height = neighbor_terrain.height_level
				
				# 检查是否可以扩散（相邻地形高度低于当前水流高度，且不是水源）
				if neighbor_height < current_height:
					# 如果相邻地形不是水流，则创建水流
					if neighbor_terrain.terrain_type != TerrainTile.TerrainType.WATER:
						# 创建新水流地形（保持相邻地形的高度）
						# 扩散创建的水流不标记为水源（is_card_created=false）
						game_map.modify_terrain(neighbor_coord, TerrainTile.TerrainType.WATER, neighbor_height, -1, 0, false)
						visited[key] = true
						# 继续从这个位置扩散（如果高度>1）
						if neighbor_height > 1:
							queue.append({"coord": neighbor_coord, "height": neighbor_height})
					else:
						# 相邻已经是水流（可能是其他水源），标记为已访问但不继续扩散
						visited[key] = true

func _coord_to_key(hex_coord: Vector2i) -> String:
	return str(hex_coord.x) + "_" + str(hex_coord.y)
