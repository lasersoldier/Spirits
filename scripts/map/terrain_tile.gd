class_name TerrainTile
extends RefCounted

enum TerrainType {
	NORMAL,    # 普通地形
	FOREST,    # 森林地形
	WATER,     # 水流地形
	BEDROCK,   # 基岩地形（不可修改）
	SCORCHED   # 焦土地形
}

# 地形类型
var terrain_type: TerrainType = TerrainType.NORMAL

# 地形层级（1-3级）
var height_level: int = 1

# 地形位置（六边形坐标）
var hex_coord: Vector2i

# 地形效果持续时间（回合数，-1表示永久）
var effect_duration: int = -1

# 地形是否被焚毁（仅森林地形）
var is_burned: bool = false

# 是否是水源（通过卡牌创建的水流地形，即使高度降到1也保持为水源）
var is_water_source: bool = false

func _init(coord: Vector2i, type: TerrainType = TerrainType.NORMAL, level: int = 1):
	hex_coord = coord
	terrain_type = type
	height_level = level
	
	# 基岩地形默认3级
	if type == TerrainType.BEDROCK:
		height_level = 3

# 获取地形是否具有隐藏效果（森林）
func has_hide_effect() -> bool:
	return terrain_type == TerrainType.FOREST and not is_burned

# 获取地形是否具有引导效果（水流）
func has_guide_effect() -> bool:
	return terrain_type == TerrainType.WATER

# 检查地形是否可以被焚毁
func can_be_burned() -> bool:
	return terrain_type == TerrainType.FOREST and not is_burned

# 焚毁地形
func burn():
	if can_be_burned():
		is_burned = true
		terrain_type = TerrainType.SCORCHED

# 修改地形高度（仅岩属性可调用）
func modify_height(new_level: int):
	if new_level >= 1 and new_level <= 3:
		height_level = new_level

# 检查地形效果是否过期
func is_effect_expired() -> bool:
	if effect_duration == -1:
		return false
	return effect_duration <= 0

# 减少效果持续时间
func decrease_duration():
	if effect_duration > 0:
		effect_duration -= 1

# 获取地形名称
func get_terrain_name() -> String:
	match terrain_type:
		TerrainType.NORMAL:
			return "普通"
		TerrainType.FOREST:
			return "森林"
		TerrainType.WATER:
			return "水流"
		TerrainType.BEDROCK:
			return "基岩"
		TerrainType.SCORCHED:
			return "焦土"
		_:
			return "未知"

# 检查地形是否可以被修改（基岩不可修改）
func can_be_modified() -> bool:
	return terrain_type != TerrainType.BEDROCK

