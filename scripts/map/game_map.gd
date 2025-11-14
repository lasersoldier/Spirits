class_name GameMap
extends Node3D

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

# 赏金区域坐标
var bounty_zone_tiles: Array[Vector2i] = []

# 公共争夺点坐标
var contest_points: Array[Vector2i] = []

# 地图边界（用于判断坐标是否有效）
var map_bounds: Rect2i

# 坐标偏移量（用于将实际地形的最小坐标映射到(0,0)）
var coord_offset: Vector2i = Vector2i.ZERO

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
	var config_file = FileAccess.open("res://resources/data/map_config.json", FileAccess.READ)
	if not config_file:
		push_error("无法加载地图配置文件")
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("地图配置JSON解析失败")
		return
	
	var config = json.data
	map_width = config.get("map_size", {}).get("width", 15)
	map_height = config.get("map_size", {}).get("height", 15)
	hex_size = config.get("hex_size", 1.0)
	
	# 加载起始点
	var spawn_points_raw = config.get("spawn_points", [])
	spawn_points = []
	for point in spawn_points_raw:
		if point is Dictionary:
			spawn_points.append(point)
	
	# 加载赏金区域
	var bounty_config = config.get("bounty_zone", {})
	var bounty_tiles_config = bounty_config.get("tiles", [])
	for tile_config in bounty_tiles_config:
		bounty_zone_tiles.append(Vector2i(tile_config.q, tile_config.r))
	
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
	# 生成六边形地图（2人对战）
	# 计算地图中心
	var center_q = map_width / 2.0
	var center_r = map_height / 2.0
	var max_distance = min(map_width, map_height) / 2.0
	
	# 生成六边形地图
	for q in range(map_width):
		for r in range(map_height):
			var hex_coord = Vector2i(q, r)
			
			# 检查是否在六边形范围内
			if _is_in_hexagon_shape(hex_coord, center_q, center_r, max_distance):
				var terrain = TerrainTile.new(hex_coord, TerrainTile.TerrainType.NORMAL, 1)
				_set_terrain(hex_coord, terrain)
	
	# 在起始点周围设置一些初始地形（可选）
	# 这里可以添加初始地形变化逻辑

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
func modify_terrain(hex_coord: Vector2i, new_type: TerrainTile.TerrainType, new_level: int = -1, duration: int = -1) -> bool:
	if not _is_valid_hex(hex_coord):
		return false
	
	var terrain = get_terrain(hex_coord)
	if not terrain:
		terrain = TerrainTile.new(hex_coord, new_type, new_level if new_level > 0 else 1)
		_set_terrain(hex_coord, terrain)
	else:
		terrain.terrain_type = new_type
		if new_level > 0:
			terrain.height_level = new_level
		if duration >= 0:
			terrain.effect_duration = duration
	
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
	if player_id >= 0 and player_id < spawn_points.size():
		return spawn_points[player_id]
	return {}

# 获取玩家的部署位置（只返回有实际地形板块的坐标，坐标白名单）
func get_deploy_positions(player_id: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var candidate_positions: Array[Vector2i] = []
	
	# 玩家0可以从(0,10)到(5,10)部署精灵
	if player_id == 0:
		for q in range(0, 6):  # 0到5
			candidate_positions.append(Vector2i(q, 10))
	
	# 玩家1（AI）部署在r=0这一行，从(5,0)到(10,0)
	elif player_id == 1:
		for q in range(5, 11):  # 5到10
			candidate_positions.append(Vector2i(q, 0))
	
	# 其他玩家使用配置中的部署位置
	else:
		var spawn = get_spawn_point(player_id)
		if not spawn.is_empty():
			var deploy_configs = spawn.get("deploy_positions", [])
			for deploy_config in deploy_configs:
				candidate_positions.append(Vector2i(deploy_config.q, deploy_config.r))
	
	# 从候选位置中筛选出有实际地形板块的位置（坐标白名单）
	for pos in candidate_positions:
		if has_terrain_tile(pos):
			positions.append(pos)
	
	# 如果筛选后位置不足3个，也包含没有地形的位置（允许在部署区域部署，类似玩家0和AI的固定部署位置）
	if positions.size() < 3:
		for pos in candidate_positions:
			if pos not in positions:
				positions.append(pos)
	
	print("玩家", player_id, "部署位置（共", positions.size(), "个，有地形:", positions.size(), "个）: ", positions)
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
