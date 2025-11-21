class_name CardPackOpener
extends RefCounted

# 卡牌库引用
var card_library: CardLibrary

# 玩家收藏引用
var player_collection: PlayerCollection

# 数据管理器引用（用于货币系统）
var data_manager: PlayerDataManager

# 卡包配置
var pack_config: Dictionary = {}

# 卡包价格
const PACK_COST: int = 200

# 碎片转换值（根据稀有度）
const SHARD_VALUES: Dictionary = {
	"common": 5,
	"rare": 25,
	"epic": 100,
	"legendary": 500
}

func _init(library: CardLibrary, collection: PlayerCollection, manager: PlayerDataManager = null):
	card_library = library
	player_collection = collection
	data_manager = manager
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
func open_pack(pack_type_id: String = "standard") -> Dictionary:
	# 检查金币是否足够
	if data_manager and not data_manager.spend_gold(PACK_COST):
		return {
			"success": false,
			"message": "金币不足，需要 " + str(PACK_COST) + " 金币",
			"cards": [],
			"shards_gained": 0
		}
	
	var results: Array[Dictionary] = []
	
	# 获取卡包配置
	var config = pack_config
	if config.is_empty():
		push_error("卡包配置为空")
		return {
			"success": false,
			"message": "卡包配置为空",
			"cards": [],
			"shards_gained": 0
		}
	
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
	
	# 处理开出的卡牌：添加到收藏或转换为碎片
	var shards_gained: int = 0
	var all_cards: Array[Dictionary] = []  # 所有卡牌，包括转换为碎片的
	
	for card_data in results:
		var card_id = card_data.get("id", "")
		if card_id == "":
			continue
		
		var current_count = player_collection.get_card_count(card_id)
		var rarity = card_data.get("rarity", "common")
		
		# 如果已有4张，直接转换为碎片
		if current_count >= 4:
			var shard_value = SHARD_VALUES.get(rarity, SHARD_VALUES["common"])
			shards_gained += shard_value
			if data_manager:
				data_manager.add_shards(shard_value)
			# 标记为转换为碎片
			var card_info = card_data.duplicate()
			card_info["converted_to_shards"] = true
			card_info["shard_value"] = shard_value
			all_cards.append(card_info)
		else:
			# 添加到收藏
			player_collection.add_card(card_id, 1)
			var card_info = card_data.duplicate()
			card_info["converted_to_shards"] = false
			all_cards.append(card_info)
	
	return {
		"success": true,
		"message": "开包成功",
		"cards": all_cards,  # 返回所有卡牌
		"shards_gained": shards_gained
	}

# 获取卡包配置信息
func get_pack_info(pack_type_id: String = "standard") -> Dictionary:
	return pack_config.duplicate()

