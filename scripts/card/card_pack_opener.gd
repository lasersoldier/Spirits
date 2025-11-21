class_name CardPackOpener
extends RefCounted

# 卡牌库引用
var card_library: CardLibrary

# 玩家收藏引用
var player_collection: PlayerCollection

# 卡包配置
var pack_config: Dictionary = {}

func _init(library: CardLibrary, collection: PlayerCollection):
	card_library = library
	player_collection = collection
	_load_pack_config()

# 加载卡包配置
func _load_pack_config():
	var config_file = FileAccess.open("res://resources/data/pack_config.json", FileAccess.READ)
	if not config_file:
		push_error("无法加载卡包配置文件")
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("卡包配置JSON解析失败")
		return
	
	var config = json.data
	var pack_types = config.get("pack_types", [])
	if pack_types.size() > 0:
		pack_config = pack_types[0]  # 使用第一个卡包类型

# 开启卡包
func open_pack(pack_type_id: String = "standard") -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	# 获取卡包配置
	var config = pack_config
	if config.is_empty():
		push_error("卡包配置为空")
		return results
	
	var common_count = config.get("common_count", 4)
	var rare_count = config.get("rare_count", 1)
	var guaranteed_rare = config.get("guaranteed_rare", true)
	
	# 获取卡牌池
	var common_cards = card_library.get_single_attribute_cards()
	var rare_cards = card_library.get_dual_attribute_cards()
	
	# 抽取普通卡
	for i in range(common_count):
		if common_cards.size() == 0:
			break
		var random_index = randi() % common_cards.size()
		var card_data = common_cards[random_index]
		results.append(card_data)
	
	# 抽取稀有卡（保底）
	if guaranteed_rare and rare_cards.size() > 0:
		for i in range(rare_count):
			var random_index = randi() % rare_cards.size()
			var card_data = rare_cards[random_index]
			results.append(card_data)
	
	# 将开出的卡牌添加到玩家收藏
	for card_data in results:
		var card_id = card_data.get("id", "")
		if card_id != "":
			player_collection.add_card(card_id, 1)
	
	return results

# 获取卡包配置信息
func get_pack_info(pack_type_id: String = "standard") -> Dictionary:
	return pack_config.duplicate()

