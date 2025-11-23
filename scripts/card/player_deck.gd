class_name PlayerDeck
extends RefCounted

# 玩家套牌 Array[Dictionary] 格式 [{card_id: String, count: int}]
var deck: Array[Dictionary] = []

# 数据管理器引用
var data_manager: PlayerDataManager

# 玩家收藏引用（用于验证）
var collection: PlayerCollection

# 套牌最大总卡数
const MAX_DECK_SIZE: int = 36

# 每张卡在套牌中的最大数量
const MAX_CARD_COUNT_IN_DECK: int = 4

func _init(manager: PlayerDataManager, player_collection: PlayerCollection):
	data_manager = manager
	collection = player_collection
	_load_from_data_manager()

# 从数据管理器加载
func _load_from_data_manager():
	deck = data_manager.get_deck()

# 获取套牌中某张卡的数量
func get_card_count(card_id: String) -> int:
	for entry in deck:
		if entry.get("card_id", "") == card_id:
			return entry.get("count", 0)
	return 0

# 获取套牌总卡数
func get_total_count() -> int:
	var total = 0
	for entry in deck:
		total += entry.get("count", 0)
	return total

# 添加卡牌到套牌
func add_card(card_id: String, count: int = 1) -> Dictionary:
	# 检查是否拥有足够的卡牌
	var owned_count = collection.get_card_count(card_id)
	var current_deck_count = get_card_count(card_id)
	var new_deck_count = current_deck_count + count
	
	# 验证：不能超过拥有的数量
	if new_deck_count > owned_count:
		return {"success": false, "message": "拥有的卡牌数量不足"}
	
	# 验证：每张卡最多4张
	if new_deck_count > MAX_CARD_COUNT_IN_DECK:
		return {"success": false, "message": "每张卡在套牌中最多只能有" + str(MAX_CARD_COUNT_IN_DECK) + "张"}
	
	# 验证：总卡数不能超过36
	var total = get_total_count()
	if total + count > MAX_DECK_SIZE:
		return {"success": false, "message": "套牌总卡数不能超过" + str(MAX_DECK_SIZE) + "张"}
	
	# 查找是否已存在
	var found = false
	for entry in deck:
		if entry.get("card_id", "") == card_id:
			entry["count"] = new_deck_count
			found = true
			break
	
	# 如果不存在，添加新条目
	if not found:
		deck.append({"card_id": card_id, "count": new_deck_count})
	
	# 不再自动保存，由UI层控制
	# _save_to_data_manager()
	return {"success": true, "message": "添加成功"}

# 从套牌移除卡牌
func remove_card(card_id: String, count: int = 1) -> Dictionary:
	var current_count = get_card_count(card_id)
	if current_count == 0:
		return {"success": false, "message": "套牌中没有这张卡"}
	
	var new_count = max(0, current_count - count)
	
	# 更新或移除条目
	for i in range(deck.size() - 1, -1, -1):
		var entry = deck[i]
		if entry.get("card_id", "") == card_id:
			if new_count == 0:
				deck.remove_at(i)
			else:
				entry["count"] = new_count
			break
	
	# 不再自动保存，由UI层控制
	# _save_to_data_manager()
	return {"success": true, "message": "移除成功"}

# 设置套牌中某张卡的数量
func set_card_count(card_id: String, count: int) -> Dictionary:
	if count < 0:
		return {"success": false, "message": "数量不能为负数"}
	
	# 检查是否拥有足够的卡牌
	var owned_count = collection.get_card_count(card_id)
	if count > owned_count:
		return {"success": false, "message": "拥有的卡牌数量不足"}
	
	# 验证：每张卡最多4张
	if count > MAX_CARD_COUNT_IN_DECK:
		return {"success": false, "message": "每张卡在套牌中最多只能有" + str(MAX_CARD_COUNT_IN_DECK) + "张"}
	
	# 计算总卡数变化
	var current_count = get_card_count(card_id)
	var total = get_total_count()
	var new_total = total - current_count + count
	
	# 验证：总卡数不能超过36
	if new_total > MAX_DECK_SIZE:
		return {"success": false, "message": "套牌总卡数不能超过" + str(MAX_DECK_SIZE) + "张"}
	
	# 更新或移除条目
	if count == 0:
		# 移除
		for i in range(deck.size() - 1, -1, -1):
			if deck[i].get("card_id", "") == card_id:
				deck.remove_at(i)
				break
	else:
		# 更新或添加
		var found = false
		for entry in deck:
			if entry.get("card_id", "") == card_id:
				entry["count"] = count
				found = true
				break
		
		if not found:
			deck.append({"card_id": card_id, "count": count})
	
	# 不再自动保存，由UI层控制
	# _save_to_data_manager()
	return {"success": true, "message": "设置成功"}

# 验证套牌合法性
func validate_deck() -> Dictionary:
	var total = get_total_count()
	
	if total > MAX_DECK_SIZE:
		return {"valid": false, "message": "套牌总卡数超过" + str(MAX_DECK_SIZE) + "张"}
	
	if total == 0:
		return {"valid": false, "message": "套牌不能为空"}
	
	# 检查每张卡的数量
	for entry in deck:
		var card_id = entry.get("card_id", "")
		var count = entry.get("count", 0)
		
		if count > MAX_CARD_COUNT_IN_DECK:
			return {"valid": false, "message": "卡牌 " + card_id + " 数量超过限制"}
		
		# 检查是否拥有足够的卡牌
		var owned_count = collection.get_card_count(card_id)
		if count > owned_count:
			return {"valid": false, "message": "卡牌 " + card_id + " 拥有的数量不足"}
	
	return {"valid": true, "message": "套牌合法"}

# 清空套牌
func clear_deck():
	deck.clear()
	# 不再自动保存，由UI层控制
	# _save_to_data_manager()

# 获取套牌数据（用于构建实际卡组）
func get_deck_data() -> Array[Dictionary]:
	return deck.duplicate()

# 保存到数据管理器（公开方法，供UI层调用）
func save_to_data_manager():
	data_manager.set_deck(deck)
	data_manager.save_data()

# 私有方法（保留向后兼容）
func _save_to_data_manager():
	save_to_data_manager()

