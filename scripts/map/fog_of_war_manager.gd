class_name FogOfWarManager
extends RefCounted

# 战争迷雾管理器：追踪每个玩家的可见区域

# 每个玩家的可见区域（key: player_id, value: Set of hex_coords）
var visible_areas: Dictionary = {}  # Dictionary[int, Array[Vector2i]]

# 信号：视野更新时发出
signal vision_updated(player_id: int)

func _init():
	pass

# 更新玩家视野（根据该玩家的所有存活精灵）
func update_player_vision(player_id: int, sprites: Array[Sprite], game_map: GameMap = null):
	var visible_coords: Array[Vector2i] = []
	
	# 遍历该玩家的所有存活精灵
	for sprite in sprites:
		if not sprite.is_alive:
			continue
		
		# 检查精灵位置是否有效
		if sprite.hex_position == Vector2i(-1, -1):
			continue
		
		# 获取该精灵的视野范围
		var vision_range = sprite.vision_range
		if vision_range <= 0:
			continue
		
		# 计算该精灵视野范围内的所有六边形坐标
		var sprite_visible = HexGrid.get_hexes_in_range(sprite.hex_position, vision_range)
		
		# 如果提供了game_map，应用地形遮挡规则
		if game_map:
			for coord in sprite_visible:
				# 尝试获取地形信息（如果坐标无效或没有地形，返回null）
				var terrain = game_map.get_terrain(coord)
				
				# 如果坐标有地形，检查地形遮挡
				if terrain:
					# 检查森林地形的遮挡效果
					var can_see_forest = _can_see_through_forest(sprite.hex_position, coord, game_map)
					if not can_see_forest:
						continue
					
					# 检查地形高度的遮挡效果
					var can_see_height = _can_see_through_height(sprite, sprite.hex_position, coord, game_map)
					if not can_see_height:
						continue
				
				# 坐标可见（没有地形，或者有地形但未被遮挡）
				visible_coords.append(coord)
		else:
			visible_coords.append_array(sprite_visible)
	
	# 去除重复坐标（使用字典去重）
	var unique_visible: Dictionary = {}
	for coord in visible_coords:
		var key = _coord_to_key(coord)
		unique_visible[key] = coord
	
	# 转换为数组
	var final_visible: Array[Vector2i] = []
	for coord in unique_visible.values():
		final_visible.append(coord)
	
	# 更新可见区域
	visible_areas[player_id] = final_visible
	
	# 发出信号
	vision_updated.emit(player_id)

# 检查是否能看到森林地形（考虑森林遮挡规则）
# 规则：森林外的观察者，只有距离森林1格内才能看到森林内的情况
func _can_see_through_forest(observer_pos: Vector2i, target_pos: Vector2i, game_map: GameMap) -> bool:
	# 获取目标位置的地形
	var target_terrain = game_map.get_terrain(target_pos)
	if not target_terrain:
		return true  # 没有地形，默认可见
	
	# 检查目标是否是森林地形（且未被焚毁）
	var is_forest = target_terrain.terrain_type == TerrainTile.TerrainType.FOREST and not target_terrain.is_burned
	
	if not is_forest:
		# 目标不是森林地形，正常可见
		return true
	
	# 目标 is 森林地形，检查观察者位置
	var observer_terrain = game_map.get_terrain(observer_pos)
	var observer_in_forest = false
	if observer_terrain:
		observer_in_forest = observer_terrain.terrain_type == TerrainTile.TerrainType.FOREST and not observer_terrain.is_burned
	
	# 计算观察者到目标的距离
	var distance = HexGrid.hex_distance(observer_pos, target_pos)
	
	if observer_in_forest:
		# 观察者在森林内：拥有正常视野，可以看到外面和森林内
		return true
	else:
		# 观察者在森林外：只有距离森林1格内才能看到森林内的情况
		# 距离 <= 1：可以看见森林内
		# 距离 > 1：看不见森林内（被森林遮挡）
		return distance <= 1

# 检查是否能看到更高地形（考虑高度阻挡规则和路径阻挡）
# 规则：
# - 【鹰眼】属性精灵：无视高度阻挡，犹如平地
# - 普通精灵：
#   - 高度看低处：总是可见（目标高度 ≤ 观察者高度）
#   - 检查路径阻挡：路径上有更高的地形会阻挡视野
#   - 高度差 = 1：只有相邻才可见
#   - 高度差 ≥ 2：完全被阻挡
func _can_see_through_height(sprite: Sprite, observer_pos: Vector2i, target_pos: Vector2i, game_map: GameMap) -> bool:
	# 检查是否有【鹰眼】属性
	if sprite.can_ignore_height_blocking():
		return true  # 无视高度阻挡，犹如平地
	
	# 获取观察者和目标的地形
	var observer_terrain = game_map.get_terrain(observer_pos)
	var target_terrain = game_map.get_terrain(target_pos)
	
	if not observer_terrain or not target_terrain:
		# 如果没有地形信息，默认可见
		return true
	
	var observer_height = observer_terrain.height_level
	var target_height = target_terrain.height_level
	var height_diff = target_height - observer_height
	
	# 高度看低处总是可见（目标高度 ≤ 观察者高度）
	if target_height <= observer_height:
		# 即使目标高度较低，也需要检查路径上是否有阻挡
		# 检查路径阻挡（路径上有更高的地形会阻挡视野）
		return _check_path_blocking(observer_pos, target_pos, observer_height, game_map)
	
	# 计算高度差
	# 高度差 >= 2：完全被阻挡（目标本身太高）
	if height_diff >= 2:
		return false
	
	# 高度差 = 1：需要检查是否相邻，以及路径阻挡
	if height_diff == 1:
		var distance = HexGrid.hex_distance(observer_pos, target_pos)
		if distance != 1:
			# 非相邻，被阻挡
			return false
		
		# 相邻且高度差=1，可见，但仍需检查路径（虽然相邻时路径只有起点和终点）
		return _check_path_blocking(observer_pos, target_pos, observer_height, game_map)
	
	# 理论上不应该到达这里（所有情况都已处理）
	return true

# 检查路径阻挡（检查从观察者到目标路径上的所有地形）
func _check_path_blocking(observer_pos: Vector2i, target_pos: Vector2i, observer_height: int, game_map: GameMap) -> bool:
	# 获取路径上的所有六边形
	var path_hexes = HexGrid.get_line(observer_pos, target_pos)
	
	# 检查路径上的每个地形（不包括观察者本身）
	for i in range(1, path_hexes.size()):  # 从1开始，跳过观察者位置
		var path_hex = path_hexes[i]
		
		# 如果是目标位置，跳过（目标的高度已经在主函数中检查过了）
		if path_hex == target_pos:
			continue
		
		var path_terrain = game_map.get_terrain(path_hex)
		if not path_terrain:
			continue  # 没有地形信息，跳过
		
		var path_height = path_terrain.height_level
		
		# 如果路径上的地形高度 >= 观察者高度 + 2，完全阻挡
		if path_height >= observer_height + 2:
			return false
		
		# 如果路径上的地形高度 = 观察者高度 + 1，阻挡（除非是目标本身且相邻，但这里已经跳过了目标）
		if path_height == observer_height + 1:
			return false
	
	return true

# 检查某个格子对某个玩家是否可见
func is_visible_to_player(hex_coord: Vector2i, player_id: int) -> bool:
	if not visible_areas.has(player_id):
		return false
	
	var player_visible = visible_areas[player_id] as Array[Vector2i]
	if not player_visible:
		return false
	
	# 检查坐标是否在可见区域中
	var key = _coord_to_key(hex_coord)
	for visible_coord in player_visible:
		if _coord_to_key(visible_coord) == key:
			return true
	
	return false

# 获取玩家所有可见坐标
func get_visible_coords(player_id: int) -> Array[Vector2i]:
	if not visible_areas.has(player_id):
		return []
	
	return visible_areas[player_id] as Array[Vector2i]

# 清空玩家视野
func clear_player_vision(player_id: int):
	visible_areas.erase(player_id)
	vision_updated.emit(player_id)

# 坐标转字符串key（用于字典查找）
func _coord_to_key(coord: Vector2i) -> String:
	return str(coord.x) + "_" + str(coord.y)

# 获取所有玩家的可见区域（用于调试）
func get_all_visible_areas() -> Dictionary:
	return visible_areas.duplicate()

# 重置所有视野（用于重新开始游戏）
func reset_all_vision():
	visible_areas.clear()
