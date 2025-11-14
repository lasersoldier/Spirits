class_name SpriteAttribute
extends RefCounted

# 属性类型枚举
enum AttributeType {
	FIRE,    # 火
	WIND,    # 风
	WATER,   # 水
	ROCK     # 岩
}

# 属性类型（字符串形式，用于匹配）
var attribute: String = ""

# 基础属性
var base_hp: int = 0
var base_movement: int = 0
var vision_range: int = 0
var attack_range: int = 0

# 攻击高度限制
var attack_height_limit: String = "none"  # none, same_or_high_to_low, same_or_low_to_high, same_only

# 特殊机制标签
var special_mechanisms: Array[String] = []

# 精灵ID和名称
var sprite_id: String = ""
var sprite_name: String = ""

# 模型路径
var model_path: String = ""

func _init(data: Dictionary = {}):
	if not data.is_empty():
		_load_from_data(data)

func _load_from_data(data: Dictionary):
	sprite_id = data.get("id", "")
	sprite_name = data.get("name", "")
	attribute = data.get("attribute", "")
	base_hp = data.get("base_hp", 0)
	base_movement = data.get("base_movement", 0)
	vision_range = data.get("vision_range", 0)
	attack_range = data.get("attack_range", 0)
	attack_height_limit = data.get("attack_height_limit", "none")
	# 确保 special_mechanisms 是 Array[String] 类型
	var mechanisms_raw = data.get("special_mechanisms", [])
	special_mechanisms = []
	for mechanism in mechanisms_raw:
		if mechanism is String:
			special_mechanisms.append(mechanism)
	model_path = data.get("model_path", "")

# 检查是否具有特殊机制
func has_mechanism(mechanism: String) -> bool:
	return mechanism in special_mechanisms

# 检查是否是岩属性（用于地形修改权限）
func is_rock_attribute() -> bool:
	return attribute == "rock"

# 岩属性专属接口：地形高度修改接口
func rock_terrain_modify_interface(game_map: GameMap, hex_coord: Vector2i, new_level: int) -> bool:
	if not is_rock_attribute():
		push_error("只有岩属性精灵可以调用地形修改接口")
		return false
	
	if not game_map:
		push_error("地图引用无效")
		return false
	
	var terrain = game_map.get_terrain(hex_coord)
	if not terrain:
		return false
	
	terrain.modify_height(new_level)
	return true
