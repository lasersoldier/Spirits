class_name HexGrid
extends RefCounted

# 六边形网格坐标系统（使用轴向坐标系统 q, r）
# 第三个坐标 s = -q - r（用于距离计算）

# 六边形方向向量（6个邻居方向）
const HEX_DIRECTIONS = [
	Vector2i(1, 0),   # 右
	Vector2i(1, -1), # 右上
	Vector2i(0, -1), # 左上
	Vector2i(-1, 0), # 左
	Vector2i(-1, 1), # 左下
	Vector2i(0, 1)    # 右下
]

# 六边形大小（从中心到顶点的距离）
var hex_size: float = 1.0

func _init(size: float = 1.0):
	hex_size = size

# 将六边形坐标转换为3D世界坐标
# 使用标准轴向坐标系统：第一个坐标（q）对应左右方向，第二个坐标（r）对应前后方向
# 移除反转逻辑，让坐标直接对应地图位置
# 地图中心会被映射到原点(0, 0)
static func hex_to_world(hex_coord: Vector2i, size: float = 1.0, map_height: int = 20, map_width: int = -1) -> Vector3:
	# 第一个坐标（hex_coord.x）作为 q，对应左右方向
	# 第二个坐标（hex_coord.y）作为 r，对应前后方向
	var q = hex_coord.x
	var r = hex_coord.y
	
	# 计算地图中心
	# 如果 map_width 未提供，使用 map_height（假设是正方形地图）
	var map_w = map_width if map_width > 0 else map_height
	var map_center_q = map_w / 2.0
	var map_center_r = map_height / 2.0
	
	# 将坐标相对于地图中心偏移，使地图中心在原点
	q = q - map_center_q
	r = r - map_center_r
	
	# 标准轴向坐标转换（不使用反转）
	var x = size * (sqrt(3) * q + sqrt(3) / 2 * r)
	var z = size * (3.0 / 2.0 * r)
	return Vector3(x, 0, z)

# 将3D世界坐标转换为六边形坐标
# 使用标准轴向坐标系统，返回的坐标直接对应地图位置
# 地图中心在原点，需要反向偏移
static func world_to_hex(world_pos: Vector3, size: float = 1.0, map_height: int = 20, map_width: int = -1) -> Vector2i:
	# 反向转换：从世界坐标计算 q 和 r
	var q = (sqrt(3) / 3 * world_pos.x - 1.0 / 3 * world_pos.z) / size
	var r = (2.0 / 3 * world_pos.z) / size
	
	# 计算地图中心
	# 如果 map_width 未提供，使用 map_height（假设是正方形地图）
	var map_w = map_width if map_width > 0 else map_height
	var map_center_q = map_w / 2.0
	var map_center_r = map_height / 2.0
	
	# 将坐标偏移回原始地图坐标
	q = q + map_center_q
	r = r + map_center_r
	
	# 返回 (q, r)：第一个坐标是 q（左右），第二个坐标是 r（前后）
	return hex_round(Vector2(q, r))

# 将浮点坐标四舍五入到最近的六边形坐标
static func hex_round(hex: Vector2) -> Vector2i:
	var q = round(hex.x)
	var r = round(hex.y)
	var s = round(-hex.x - hex.y)
	
	var q_diff = abs(q - hex.x)
	var r_diff = abs(r - hex.y)
	var s_diff = abs(s - (-hex.x - hex.y))
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	else:
		s = -q - r
	
	return Vector2i(int(q), int(r))

# 计算两个六边形之间的距离
static func hex_distance(hex_a: Vector2i, hex_b: Vector2i) -> int:
	return (abs(hex_a.x - hex_b.x) + abs(hex_a.x + hex_a.y - hex_b.x - hex_b.y) + abs(hex_a.y - hex_b.y)) / 2

# 获取六边形的所有邻居
static func get_neighbors(hex_coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in HEX_DIRECTIONS:
		neighbors.append(hex_coord + dir)
	return neighbors

# 获取指定范围内的所有六边形坐标
static func get_hexes_in_range(center: Vector2i, max_range: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for q in range(-max_range, max_range + 1):
		var r1 = max(-max_range, -q - max_range)
		var r2 = min(max_range, -q + max_range)
		for r in range(r1, r2 + 1):
			var hex = Vector2i(q, r) + center
			if hex_distance(center, hex) <= max_range:
				results.append(hex)
	return results

static func get_hexes_in_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return []
	var results: Array[Vector2i] = []
	var range_hexes = get_hexes_in_range(center, radius)
	for hex in range_hexes:
		if hex_distance(center, hex) == radius:
			results.append(hex)
	return results

static func get_hexes_in_range_with_bounds(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	if max_range < 0 or max_range < min_range:
		return []
	var clamped_min = max(0, min_range)
	var clamped_max = max(clamped_min, max_range)
	var results: Array[Vector2i] = []
	var range_hexes = get_hexes_in_range(center, clamped_max)
	for hex in range_hexes:
		var distance = hex_distance(center, hex)
		if distance >= clamped_min and distance <= clamped_max:
			results.append(hex)
	return results

static func sum_distance_to_points(origin: Vector2i, points: Array[Vector2i]) -> int:
	if points.is_empty():
		return 0
	var total := 0
	for point in points:
		total += hex_distance(origin, point)
	return total

# 获取两点之间的直线路径（六边形网格中的直线）
static func get_line(hex_a: Vector2i, hex_b: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var distance = hex_distance(hex_a, hex_b)
	
	if distance == 0:
		return [hex_a]
	
	for i in range(distance + 1):
		var t = float(i) / float(distance)
		var q = lerp(hex_a.x, hex_b.x, t)
		var r = lerp(hex_a.y, hex_b.y, t)
		results.append(hex_round(Vector2(q, r)))
	
	return results

# 检查两个六边形是否相邻
static func is_adjacent(hex_a: Vector2i, hex_b: Vector2i) -> bool:
	return hex_distance(hex_a, hex_b) == 1

