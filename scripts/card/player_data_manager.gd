class_name PlayerDataManager
extends RefCounted

# 数据文件路径
const DATA_FILE_PATH: String = "user://player_data.cfg"

# 玩家拥有的卡牌集合 {card_id: count}，每张卡最多4张
var player_collection: Dictionary = {}

# 玩家套牌 Array[Dictionary] 格式 [{card_id: String, count: int}]，最多36张
var player_deck: Array[Dictionary] = []

# ConfigFile实例
var config_file: ConfigFile

func _init():
	_load_data()

# 加载数据
func _load_data():
	config_file = ConfigFile.new()
	var error = config_file.load(DATA_FILE_PATH)
	
	if error != OK:
		# 文件不存在，使用默认值
		player_collection = {}
		player_deck = []
		return
	
	# 加载玩家收藏
	player_collection = {}
	var collection_keys = config_file.get_section_keys("collection")
	for key in collection_keys:
		var count = config_file.get_value("collection", key, 0)
		player_collection[key] = count
	
	# 加载玩家套牌
	player_deck = []
	var deck_size = config_file.get_value("deck", "size", 0)
	for i in range(deck_size):
		var card_id = config_file.get_value("deck", "card_" + str(i) + "_id", "")
		var count = config_file.get_value("deck", "card_" + str(i) + "_count", 0)
		if card_id != "" and count > 0:
			player_deck.append({"card_id": card_id, "count": count})

# 保存数据
func save_data():
	if not config_file:
		config_file = ConfigFile.new()
	
	# 保存玩家收藏
	config_file.erase_section("collection")
	for card_id in player_collection.keys():
		config_file.set_value("collection", card_id, player_collection[card_id])
	
	# 保存玩家套牌
	config_file.erase_section("deck")
	config_file.set_value("deck", "size", player_deck.size())
	for i in range(player_deck.size()):
		var entry = player_deck[i]
		config_file.set_value("deck", "card_" + str(i) + "_id", entry.get("card_id", ""))
		config_file.set_value("deck", "card_" + str(i) + "_count", entry.get("count", 0))
	
	# 保存到文件
	var error = config_file.save(DATA_FILE_PATH)
	if error != OK:
		push_error("保存玩家数据失败: " + str(error))
		return false
	return true

# 获取玩家收藏
func get_collection() -> Dictionary:
	return player_collection.duplicate()

# 设置玩家收藏
func set_collection(collection: Dictionary):
	player_collection = collection.duplicate()

# 获取玩家套牌
func get_deck() -> Array[Dictionary]:
	return player_deck.duplicate()

# 设置玩家套牌
func set_deck(deck: Array[Dictionary]):
	player_deck = deck.duplicate()

