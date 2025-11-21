class_name PlayerCollection
extends RefCounted

# 玩家拥有的卡牌集合 {card_id: count}，每张卡最多4张
var collection: Dictionary = {}

# 数据管理器引用
var data_manager: PlayerDataManager

# 每张卡的最大数量
const MAX_CARD_COUNT: int = 4

func _init(manager: PlayerDataManager):
	data_manager = manager
	_load_from_data_manager()

# 从数据管理器加载
func _load_from_data_manager():
	collection = data_manager.get_collection()

# 获取卡牌数量
func get_card_count(card_id: String) -> int:
	return collection.get(card_id, 0)

# 添加卡牌（最多4张）
func add_card(card_id: String, count: int = 1) -> bool:
	var current_count = get_card_count(card_id)
	var new_count = current_count + count
	
	if new_count > MAX_CARD_COUNT:
		new_count = MAX_CARD_COUNT
	
	if new_count == current_count:
		return false  # 已达到上限
	
	collection[card_id] = new_count
	_save_to_data_manager()
	return true

# 移除卡牌
func remove_card(card_id: String, count: int = 1) -> bool:
	var current_count = get_card_count(card_id)
	if current_count == 0:
		return false
	
	var new_count = max(0, current_count - count)
	
	if new_count == 0:
		collection.erase(card_id)
	else:
		collection[card_id] = new_count
	
	_save_to_data_manager()
	return true

# 设置卡牌数量
func set_card_count(card_id: String, count: int) -> bool:
	if count < 0 or count > MAX_CARD_COUNT:
		return false
	
	if count == 0:
		collection.erase(card_id)
	else:
		collection[card_id] = count
	
	_save_to_data_manager()
	return true

# 检查是否拥有某张卡
func has_card(card_id: String) -> bool:
	return get_card_count(card_id) > 0

# 获取所有拥有的卡牌ID列表
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in collection.keys():
		ids.append(card_id)
	return ids

# 获取总卡牌数量
func get_total_count() -> int:
	var total = 0
	for count in collection.values():
		total += count
	return total

# 保存到数据管理器
func _save_to_data_manager():
	data_manager.set_collection(collection)
	data_manager.save_data()

