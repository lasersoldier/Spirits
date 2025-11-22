class_name Card
extends RefCounted

# 卡牌ID
var card_id: String = ""

# 卡牌名称
var card_name: String = ""

# 属性组合
var attributes: Array[String] = []

# 稀有度
var rarity: String = "common"  # common, rare

# 消耗能量
var energy_cost: int = 0

# 卡牌类型
var card_type: String = ""  # attack, terrain, support

# 效果描述
var effect_description: String = ""

# 结构化效果
var effects: Array[Dictionary] = []

# 目标类型
var target_type: String = ""  # enemy_sprite, adjacent_tile, self

# 范围要求
var range_requirement: String = ""

# 自定义范围覆盖（>0 时使用固定范围）
var range_override: int = -1

# 结算时机（immediate, start_of_next_turn 等）
var timing: String = "immediate"

# 双属性卡牌：需要另一个属性精灵的距离要求（默认1格，即相邻）
var dual_attribute_range: int = 1

# 当前持有者玩家ID
var owner_player_id: int = -1

# 是否可使用
var is_usable: bool = true

# 使用后冷却回合（如果有）
var cooldown_rounds: int = 0
var current_cooldown: int = 0

func _init(data: Dictionary = {}):
	if not data.is_empty():
		_load_from_data(data)

func _load_from_data(data: Dictionary):
	card_id = data.get("id", "")
	card_name = data.get("name", "")
	# 转换 attributes 为 Array[String]
	var attrs_raw = data.get("attributes", [])
	attributes = []
	for attr in attrs_raw:
		attributes.append(attr as String)
	rarity = data.get("rarity", "common")
	energy_cost = data.get("energy_cost", 0)
	card_type = data.get("type", "")
	effect_description = data.get("effect", "")
	target_type = data.get("target_type", "")
	range_requirement = data.get("range_requirement", "")
	range_override = data.get("range_override", -1)
	timing = data.get("timing", data.get("resolve_timing", "start_of_next_turn"))
	dual_attribute_range = data.get("dual_attribute_range", 1)  # 默认1格
	
	# 解析结构化效果（深复制以避免共享引用）
	effects.clear()
	var raw_effects = data.get("effects", [])
	for effect_entry in raw_effects:
		if typeof(effect_entry) == TYPE_DICTIONARY:
			effects.append(effect_entry.duplicate(true))

# 检查是否是单属性卡牌
func is_single_attribute() -> bool:
	return attributes.size() == 1

# 检查是否是双属性卡牌
func is_dual_attribute() -> bool:
	return attributes.size() == 2

# 检查是否是异种双属性（两个不同属性）
func is_mixed_dual_attribute() -> bool:
	if not is_dual_attribute():
		return false
	return attributes[0] != attributes[1]

# 使用卡牌
func use():
	current_cooldown = cooldown_rounds

# 更新冷却
func update_cooldown():
	if current_cooldown > 0:
		current_cooldown -= 1

# 检查是否冷却完成
func is_cooldown_ready() -> bool:
	return current_cooldown <= 0

# 获取简称描述
func get_short_description() -> String:
	if effects.is_empty():
		return effect_description
	
	var short_desc = CardEffectShortener.get_short_description(effects)
	if short_desc.is_empty():
		return effect_description
	return short_desc

# 复制卡牌（用于创建卡牌实例）
func duplicate_card() -> Card:
	var new_card = Card.new()
	new_card.card_id = card_id
	new_card.card_name = card_name
	new_card.attributes = attributes.duplicate()
	new_card.rarity = rarity
	new_card.energy_cost = energy_cost
	new_card.card_type = card_type
	new_card.effect_description = effect_description
	# 深拷贝效果数组
	new_card.effects.clear()
	for effect_entry in effects:
		if typeof(effect_entry) == TYPE_DICTIONARY:
			new_card.effects.append(effect_entry.duplicate(true))
	new_card.target_type = target_type
	new_card.range_requirement = range_requirement
	new_card.range_override = range_override
	new_card.timing = timing
	new_card.dual_attribute_range = dual_attribute_range
	new_card.owner_player_id = owner_player_id
	new_card.is_usable = is_usable
	new_card.cooldown_rounds = cooldown_rounds
	new_card.current_cooldown = current_cooldown
	return new_card
