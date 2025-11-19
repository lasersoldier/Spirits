class_name GameMap
extends Node3D

@export_file("*.json") var map_config_path: String = "res://resources/data/map_config.json"

# 地图配置
var map_width: int = 15
var map_height: int = 15
var hex_size: float = 1.0

# 六边形网格系统
var hex_grid: HexGrid

# 地形板块字典（key: "q_r" 格式的字符串）
var terrain_tiles: Dictionary = {}

# 玩家起始点
var spawn_points: Array[Dictionary] = []
var spawn_points_by_player: Dictionary = {}

# 赏金区域坐标
var bounty_zone_tiles: Array[Vector2i] = []

# 公共争夺点坐标
var contest_points: Array[Vector2i] = []

# 地图区域配置
var region_configs: Array = []
var path_configs: Array = []
var resource_points: Array = []
var training_enemy_configs: Array = []

# 地图边界（用于判断坐标是否有效）
var map_bounds: Rect2i

# 坐标偏移量（用于将实际地形的最小坐标映射到(0,0)）
var coord_offset: Vector2i = Vector2i.ZERO

# 原始配置数据（用于自定义模式，如训练场）
var map_config_data: Dictionary = {}

signal terrain_changed(hex_coord: Vector2i, terrain: TerrainTile)

func _ready():
	# 确保GameMap的变换是恒等的，避免地形和高亮节点随摄像机旋转而偏移
	transform = Transform3D.IDENTITY
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	
	hex_grid = HexGrid.new(hex_size)
	# 立即加载配置（不使用延迟，确保地形能及时生成）
	_load_map_config()

func _load_map_config():
	var path = map_config_path if map_config_path != "" else "res://resources/data/map_config.json"
	var config_file = FileAccess.open(path, FileAccess.READ)
	if not config_file:
		push_error("无法加载地图配置文件: " + path)
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("地图配置JSON解析失败: " + path)
		return
	
	var config = json.data
	if typeof(config) != TYPE_DICTIONARY:
		push_error("地图配置数据格式错误: " + path)
		return
	
	map_config_data = config
	map_width = config.get("map_size", {}).get("width", 15)
	map_height = config.get("map_size", {}).get("height", 15)
	hex_size = config.get("hex_size", 1.0)
	region_configs = config.get("regions", [])
	path_configs = config.get("paths", [])
	resource_points = config.get("resource_points", [])
	training_enemy_configs.clear()
	var raw_training = config.get("training_enemies", [])
	for entry in raw_training:
		if entry is Dictionary:
			training_enemy_configs.append(entry.duplicate(true))
	
	# 加载起始点
	var spawn_points_raw = config.get("spawn_points", [])
	spawn_points = []
	spawn_points_by_player.clear()
	for point in spawn_points_raw:
		if point is Dictionary:
			spawn_points.append(point)
			var pid = int(point.get("player_id", -1))
			if pid >= 0:
				spawn_points_by_player[pid] = point
	
	# 加载赏金区域
	var bounty_config = config.get("bounty_zone", {})
	var bounty_tiles_config = bounty_config.get("tiles", [])
	bounty_zone_tiles.clear()
	var fallback_center = Vector2i(int(map_width / 2), int(map_height / 2))
	var center_dict = bounty_config.get("center", {})
	var configured_center = Vector2i(center_dict.get("q", fallback_center.x), center_dict.get("r", fallback_center.y))
	var radius = bounty_config.get("radius", 0)
	if bounty_tiles_config.size() > 0:
		for tile_config in bounty_tiles_config:
			var tile = Vector2i(tile_config.q, tile_config.r)
			if _is_valid_hex(tile):
				bounty_zone_tiles.append(tile)
	elif radius > 0:
		var zone_candidates = HexGrid.get_hexes_in_range(configured_center, radius)
		for candidate in zone_candidates:
			if HexGrid.hex_distance(configured_center, candidate) == 0:
				continue
			if _is_valid_hex(candidate):
				bounty_zone_tiles.append(candidate)
	else:
		bounty_zone_tiles = _compute_default_bounty_zone(configured_center)
	
	if bounty_zone_tiles.is_empty():
		bounty_zone_tiles = _compute_default_bounty_zone(configured_center)
	
	# 加载争夺点
	var contest_configs = config.get("contest_points", [])
	for contest_config in contest_configs:
		var coord = contest_config.get("hex_coord", {})
		contest_points.append(Vector2i(coord.q, coord.r))
	
	# 生成地图边界
	map_bounds = Rect2i(0, 0, map_width, map_height)
	
	# 生成初始地形
	_generate_initial_terrain()
	# 调整坐标偏移，使实际地形从(0,0)开始
	_adjust_coordinate_offset()

func _generate_initial_terrain():
	terrain_tiles.clear()
	
	if not region_configs.is_empty():
		for region in region_configs:
			_create_region(region)
		
		for path in path_configs:
			_create_path(path)
	else:
		_generate_default_hexagon_map()
	
	for resource in resource_points:
		if resource is Dictionary:
			var coord = _dict_to_coord(resource.get("hex_coord", {}))
			if coord:
				var terrain = TerrainTile.new(coord, TerrainTile.TerrainType.NORMAL, 1)
				_set_terrain(coord, terrain)

# 调整坐标偏移，使实际地形从(0,0)开始
func _adjust_coordinate_offset():
	if terrain_tiles.is_empty():
		return
	
	# 找到所有实际地形坐标的最小值
	var min_q = INF
	var min_r = INF
	
	for key in terrain_tiles.keys():
		var parts = key.split("_")
		if parts.size() == 2:
			var q = int(parts[0])
			var r = int(parts[1])
			min_q = min(min_q, q)
			min_r = min(min_r, r)
	
	if min_q == INF or min_r == INF:
		return
	
	# 计算偏移量
	coord_offset = Vector2i(int(min_q), int(min_r))
	
	if coord_offset == Vector2i.ZERO:
		# 已经是从(0,0)开始，不需要调整
		return
	
	print("检测到地形坐标偏移: ", coord_offset, "，开始重新映射坐标...")
	
	# 重新映射所有地形坐标
	var new_terrain_tiles: Dictionary = {}
	for key in terrain_tiles.keys():
		var parts = key.split("_")
		if parts.size() == 2:
			var old_q = int(parts[0])
			var old_r = int(parts[1])
			var old_coord = Vector2i(old_q, old_r)
			var new_coord = old_coord - coord_offset
			
			# 更新地形坐标
			var terrain = terrain_tiles[key]
			terrain.hex_coord = new_coord
			
			# 使用新坐标作为key
			var new_key = _coord_to_key(new_coord)
			new_terrain_tiles[new_key] = terrain
	
	terrain_tiles = new_terrain_tiles
	
	# 触发地形变化信号，通知渲染器更新
	for coord in get_all_terrain_coords():
		var terrain = get_terrain(coord)
		if terrain:
			terrain_changed.emit(coord, terrain)
	
	# 更新所有配置中的坐标
	# 更新起始点
	for i in range(spawn_points.size()):
		var spawn = spawn_points[i]
		var hex_coord = spawn.get("hex_coord", {})
		if hex_coord is Dictionary:
			var old_q = hex_coord.get("q", 0)
			var old_r = hex_coord.get("r", 0)
			hex_coord["q"] = old_q - coord_offset.x
			hex_coord["r"] = old_r - coord_offset.y
		
		# 更新部署位置
		var deploy_positions = spawn.get("deploy_positions", [])
		for deploy in deploy_positions:
			if deploy is Dictionary:
				deploy["q"] = deploy.get("q", 0) - coord_offset.x
				deploy["r"] = deploy.get("r", 0) - coord_offset.y
	
	# 更新赏金区域
	var new_bounty_zone: Array[Vector2i] = []
	for coord in bounty_zone_tiles:
		new_bounty_zone.append(coord - coord_offset)
	bounty_zone_tiles = new_bounty_zone
	
	# 更新争夺点
	var new_contest_points: Array[Vector2i] = []
	for coord in contest_points:
		new_contest_points.append(coord - coord_offset)
	contest_points = new_contest_points
	
	# 更新地图边界
	var all_coords = get_all_terrain_coords()
	if not all_coords.is_empty():
		var max_q = -INF
		var max_r = -INF
		for coord in all_coords:
			max_q = max(max_q, coord.x)
			max_r = max(max_r, coord.y)
		map_bounds = Rect2i(0, 0, int(max_q) + 1, int(max_r) + 1)
	
	_rebuild_spawn_point_lookup()
	_adjust_training_enemy_coords()
	
	print("坐标偏移调整完成，地形现在从(0,0)开始")

# 检查坐标是否在六边形范围内
func _is_in_hexagon_shape(hex_coord: Vector2i, center_q: float, center_r: float, max_dist: float) -> bool:
	# 将六边形坐标转换为世界坐标来计算角度
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	var center_world = HexGrid.hex_to_world(Vector2i(int(center_q), int(center_r)), hex_size, map_height, map_width)
	
	var dx = world_pos.x - center_world.x
	var dz = world_pos.z - center_world.z
	
	# 计算到中心的距离（世界坐标）
	var distance = sqrt(dx * dx + dz * dz)
	
	# 计算角度
	var angle = atan2(dz, dx)
	# 标准化角度到 [0, 2π]
	angle = fmod(angle + 2 * PI, 2 * PI)
	
	# 六边形的6个主要方向（每60度一个）
	# 主要方向：0, 60, 120, 180, 240, 300度
	var main_angles = [0, PI/3, 2*PI/3, PI, 4*PI/3, 5*PI/3]
	
	# 找到当前角度所在或最近的主要方向扇区
	var sector = int(fmod(angle + PI/6, 2 * PI) / (PI/3)) % 6
	
	# 计算到扇区中心的角度差
	var sector_center_angle = main_angles[sector]
	var angle_diff = abs(angle - sector_center_angle)
	if angle_diff > PI:
		angle_diff = 2 * PI - angle_diff
	
	# 六边形边界计算：
	# 在主要方向（扇区中心）半径最大
	# 在扇区边缘（30度处）半径最小
	# 注意：max_dist是基于六边形坐标的，需要转换为世界坐标距离
	# 六边形坐标距离转换为世界坐标：需要乘以hex_size和sqrt(3)的某个因子
	# 为了保持相同的六边形数量，我们需要将半径乘以hex_size
	var max_radius = max_dist * 0.9 * hex_size  # 最大半径（主要方向，世界坐标）
	var min_radius = max_dist * 0.7 * hex_size  # 最小半径（扇区边缘，世界坐标）
	
	# 根据角度差计算半径（0度时最大，30度时最小）
	var normalized_angle_diff = angle_diff / (PI/3)  # 归一化到 [0, 1]
	var radius_factor = cos(normalized_angle_diff * PI)  # 使用cos函数，在0时为1，在1时为-1
	radius_factor = (radius_factor + 1.0) / 2.0  # 归一化到 [0, 1]
	
	# 在扇区中心（角度差为0）时使用最大半径，在边缘时使用最小半径
	var effective_radius = lerp(min_radius, max_radius, radius_factor)
	
	# 检查是否在范围内
	return distance <= effective_radius

# 检查六边形坐标是否有效（基础边界检查）
func _is_valid_hex(hex_coord: Vector2i) -> bool:
	# 如果坐标偏移已调整，使用实际地图边界
	if coord_offset != Vector2i.ZERO and map_bounds.size != Vector2i.ZERO:
		return map_bounds.has_point(hex_coord)
	# 否则使用原始地图大小
	return hex_coord.x >= 0 and hex_coord.x < map_width and \
		   hex_coord.y >= 0 and hex_coord.y < map_height

# 检查坐标是否有效（包含坐标白名单检查）
func is_valid_hex_with_terrain(hex_coord: Vector2i) -> bool:
	# 先检查基础边界
	if not _is_valid_hex(hex_coord):
		return false
	# 再检查是否有实际地形板块（坐标白名单）
	return has_terrain_tile(hex_coord)

# 检查坐标是否有实际地形板块（坐标白名单）
func has_terrain_tile(hex_coord: Vector2i) -> bool:
	# 检查是否有实际地形
	return get_terrain(hex_coord) != null

# 获取所有有效的地形坐标白名单
func get_valid_terrain_coords() -> Array[Vector2i]:
	# 返回所有有实际地形板块的坐标
	return get_all_terrain_coords()

# 获取地形板块
func get_terrain(hex_coord: Vector2i) -> TerrainTile:
	var key = _coord_to_key(hex_coord)
	return terrain_tiles.get(key, null)

# 设置地形板块
func _set_terrain(hex_coord: Vector2i, terrain: TerrainTile):
	var key = _coord_to_key(hex_coord)
	terrain_tiles[key] = terrain
	terrain_changed.emit(hex_coord, terrain)

# 修改地形（用于卡牌效果等）
# is_card_created: 是否通过卡牌创建（用于标记水源）
func modify_terrain(hex_coord: Vector2i, new_type: TerrainTile.TerrainType, new_level: int = -1, duration: int = -1, height_delta: int = 0, is_card_created: bool = false) -> bool:
	if not _is_valid_hex(hex_coord):
		push_warning("GameMap: 无效坐标: " + str(hex_coord))
		return false
	
	var terrain = get_terrain(hex_coord)
	
	# 检查基岩保护：如果现有地形是基岩，则拒绝修改
	if terrain and not terrain.can_be_modified():
		push_warning("GameMap: 基岩地形不可修改: " + str(hex_coord))
		return false
	
	# 检查是否试图创建基岩地形（基岩只能通过地图配置创建，不能通过卡牌创建）
	if new_type == TerrainTile.TerrainType.BEDROCK and not terrain:
		push_warning("GameMap: 不能通过卡牌创建基岩地形: " + str(hex_coord))
		return false
	var final_height = 1
	
	if not terrain:
		# 创建新地形
		if height_delta != 0:
			# 相对高度修改（新地形默认1级）
			final_height = clamp(1 + height_delta, 1, 3)
		elif new_level > 0:
			final_height = clamp(new_level, 1, 3)
		else:
			final_height = 1
		
		terrain = TerrainTile.new(hex_coord, new_type, final_height)
		# 如果是通过卡牌创建的水流地形，无论高度都标记为水源
		# 如果是通过扩散创建的水流地形，只有高度>1才标记为水源
		if new_type == TerrainTile.TerrainType.WATER:
			if is_card_created or final_height > 1:
				terrain.is_water_source = true
		_set_terrain(hex_coord, terrain)
	else:
		# 修改现有地形
		if height_delta != 0:
			# 相对高度修改
			final_height = clamp(terrain.height_level + height_delta, 1, 3)
		elif new_level > 0:
			# 绝对高度设置
			final_height = clamp(new_level, 1, 3)
		else:
			# 保持当前高度
			final_height = terrain.height_level
		
		# 如果改为水流地形，标记为水源的条件：
		# 1. 通过卡牌创建的，无论高度都标记为水源
		# 2. 高度>1的，标记为水源
		# 3. 如果已经是水源，保持水源标记（即使高度降到1）
		if new_type == TerrainTile.TerrainType.WATER:
			if is_card_created or final_height > 1:
				terrain.is_water_source = true
			# 如果已经是水源，即使高度降到1也保持水源标记
			# （is_water_source 一旦设置为 true 就不会被清除）
		
		terrain.terrain_type = new_type
		terrain.height_level = final_height
		if duration >= 0:
			terrain.effect_duration = duration
		
		# 触发地形变化信号，让渲染器更新
		_set_terrain(hex_coord, terrain)
	
	return true

# 检查坐标是否在赏金区域内
func is_in_bounty_zone(hex_coord: Vector2i) -> bool:
	return hex_coord in bounty_zone_tiles

# 检查坐标是否是公共争夺点
func is_contest_point(hex_coord: Vector2i) -> int:
	# 返回争夺点ID，如果不是则返回-1
	for i in range(contest_points.size()):
		if contest_points[i] == hex_coord:
			return i
	return -1

# 获取玩家起始点
func get_spawn_point(player_id: int) -> Dictionary:
	if spawn_points_by_player.has(player_id):
		return spawn_points_by_player[player_id]
	return {}

# 获取玩家的部署位置（只返回有实际地形板块的坐标，坐标白名单）
func get_deploy_positions(player_id: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var spawn = get_spawn_point(player_id)
	
	if not spawn.is_empty():
		var deploy_configs = spawn.get("deploy_positions", [])
		for deploy in deploy_configs:
			if deploy is Dictionary:
				positions.append(Vector2i(deploy.get("q", 0), deploy.get("r", 0)))
		
		if positions.is_empty():
			var hex_coord = spawn.get("hex_coord", {})
			if hex_coord is Dictionary:
				positions.append(Vector2i(hex_coord.get("q", 0), hex_coord.get("r", 0)))
	

	return positions

# 坐标转字符串key
func _coord_to_key(hex_coord: Vector2i) -> String:
	return str(hex_coord.x) + "_" + str(hex_coord.y)

# 获取所有有效的地形坐标
func get_all_terrain_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for key in terrain_tiles.keys():
		var parts = key.split("_")
		if parts.size() == 2:
			coords.append(Vector2i(int(parts[0]), int(parts[1])))
	return coords

func _create_region(region: Dictionary) -> void:
	var center = _dict_to_coord(region.get("center", {}))
	if center == null:
		return
	var radius = region.get("radius", 3)
	var terrain_type = _terrain_type_from_string(region.get("terrain_type", "normal"))
	var height = region.get("height", 1)
	var is_water_source = region.get("is_water_source", false)
	_paint_hex_area(center, radius, terrain_type, height, is_water_source)

func _create_path(path_config: Dictionary) -> void:
	var from_coord = _dict_to_coord(path_config.get("from", {}))
	var to_coord = _dict_to_coord(path_config.get("to", {}))
	if from_coord == null or to_coord == null:
		return
	var width = max(0, path_config.get("width", 1))
	var terrain_type = _terrain_type_from_string(path_config.get("terrain_type", "normal"))
	var height = path_config.get("height", 1)
	var line = HexGrid.get_line(from_coord, to_coord)
	for coord in line:
		_paint_hex_area(coord, width, terrain_type, height)

func _compute_default_bounty_zone(center: Vector2i) -> Array[Vector2i]:
	var zone: Array[Vector2i] = []
	var candidates = HexGrid.get_hexes_in_range_with_bounds(center, 1, 2)
	for coord in candidates:
		if _is_valid_hex(coord):
			zone.append(coord)
	if zone.is_empty():
		var neighbors = HexGrid.get_neighbors(center)
		for neighbor in neighbors:
			if _is_valid_hex(neighbor):
				zone.append(neighbor)
	return zone

func _paint_hex_area(center: Vector2i, radius: int, terrain_type: TerrainTile.TerrainType, height: int, mark_water_source: bool = false) -> void:
	var tiles = HexGrid.get_hexes_in_range(center, radius)
	for coord in tiles:
		# 检查坐标是否在地图边界内
		if coord.x >= 0 and coord.x < map_width and coord.y >= 0 and coord.y < map_height:
			var terrain = TerrainTile.new(coord, terrain_type, height)
			if terrain_type == TerrainTile.TerrainType.WATER:
				if mark_water_source or height > 1:
					terrain.is_water_source = true
			_set_terrain(coord, terrain)

func _terrain_type_from_string(type_name: String) -> TerrainTile.TerrainType:
	match type_name.to_lower():
		"forest":
			return TerrainTile.TerrainType.FOREST
		"water":
			return TerrainTile.TerrainType.WATER
		"rock", "bedrock":
			return TerrainTile.TerrainType.BEDROCK
		"scorched":
			return TerrainTile.TerrainType.SCORCHED
		_:
			return TerrainTile.TerrainType.NORMAL

func _dict_to_coord(data: Dictionary) -> Variant:
	if data.is_empty():
		return null
	return Vector2i(data.get("q", 0), data.get("r", 0))

func _generate_default_hexagon_map() -> void:
	var center_q = map_width / 2.0
	var center_r = map_height / 2.0
	var max_distance = min(map_width, map_height) / 2.0
	for q in range(map_width):
		for r in range(map_height):
			var hex_coord = Vector2i(q, r)
			if _is_in_hexagon_shape(hex_coord, center_q, center_r, max_distance):
				var terrain = TerrainTile.new(hex_coord, TerrainTile.TerrainType.NORMAL, 1)
				_set_terrain(hex_coord, terrain)

func _rebuild_spawn_point_lookup() -> void:
	spawn_points_by_player.clear()
	for spawn in spawn_points:
		if spawn is Dictionary:
			var pid = int(spawn.get("player_id", -1))
			if pid >= 0:
				spawn_points_by_player[pid] = spawn

func _adjust_training_enemy_coords():
	if training_enemy_configs.is_empty():
		return
	for entry in training_enemy_configs:
		if not entry is Dictionary:
			continue
		var coord = entry.get("hex_coord", {})
		if coord is Dictionary:
			coord["q"] = coord.get("q", 0) - coord_offset.x
			coord["r"] = coord.get("r", 0) - coord_offset.y

func get_training_enemy_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	for entry in training_enemy_configs:
		if entry is Dictionary:
			configs.append(entry.duplicate(true))
	return configs
