class_name CardLibrary
extends RefCounted

# 卡牌数据字典（key: 卡牌ID）
var card_data: Dictionary = {}

func _init():
	_load_card_data()

func _load_card_data():
	var config_file = FileAccess.open("res://resources/data/card_data.json", FileAccess.READ)
	if not config_file:
		push_error("无法加载卡牌数据配置文件")
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("卡牌数据JSON解析失败")
		return
	
	var config = json.data
	var cards_config = config.get("cards", [])
	
	for card_config in cards_config:
		var card_id = card_config.get("id", "")
		if card_id != "":
			card_data[card_id] = card_config

# 根据ID获取卡牌数据
func get_card_data(card_id: String) -> Dictionary:
	return card_data.get(card_id, {})

# 获取所有卡牌ID列表
func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in card_data.keys():
		ids.append(key as String)
	return ids

# 根据属性获取卡牌列表
func get_cards_by_attributes(attributes: Array[String]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for card_id in card_data.keys():
		var data = card_data[card_id]
		var card_attrs = data.get("attributes", [])
		
		# 检查是否包含所有指定属性
		var matches = true
		for attr in attributes:
			if attr not in card_attrs:
				matches = false
				break
		
		if matches:
			results.append(data)
	return results

# 获取单属性卡牌
func get_single_attribute_cards() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for card_id in card_data.keys():
		var data = card_data[card_id]
		var attrs = data.get("attributes", [])
		if attrs.size() == 1:
			results.append(data)
	return results

# 获取双属性卡牌
func get_dual_attribute_cards() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for card_id in card_data.keys():
		var data = card_data[card_id]
		var attrs = data.get("attributes", [])
		if attrs.size() == 2:
			results.append(data)
	return results
