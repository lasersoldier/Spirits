class_name PublicCardPool
extends RefCounted

# 公共卡池（所有玩家投入的卡组，共100张）
var card_pool: Array[Card] = []

# 卡牌来源记录（用于能量奖励）
var card_owners: Dictionary = {}  # key: 卡牌实例ID, value: 玩家ID

# 当前卡池索引（用于抽卡）
var current_index: int = 0

signal card_drawn(card: Card, player_id: int)
signal pool_empty()

func _init():
	pass

# 初始化公共卡池（从所有玩家的卡组中收集）
func initialize_pool(all_player_decks: Dictionary):
	# all_player_decks格式: {player_id: [Card, ...], ...}
	card_pool.clear()
	card_owners.clear()
	current_index = 0
	
	for player_id in all_player_decks.keys():
		var deck = all_player_decks[player_id]
		# 只取后25张（起手5张除外）
		var pool_cards = deck.slice(5)
		
		for card in pool_cards:
			card.owner_player_id = player_id
			card_pool.append(card)
			# 记录卡牌来源（使用卡牌ID+索引作为唯一标识）
			var card_key = _get_card_key(card)
			card_owners[card_key] = player_id
	
	# 洗牌
	shuffle_pool()

# 洗牌
func shuffle_pool():
	card_pool.shuffle()
	current_index = 0

# 抽卡（每回合所有玩家抽1张）
func draw_card(player_id: int) -> Card:
	if is_empty():
		pool_empty.emit()
		return null
	
	if current_index >= card_pool.size():
		pool_empty.emit()
		return null
	
	var card = card_pool[current_index]
	current_index += 1
	
	card_drawn.emit(card, player_id)
	return card

# 检查卡池是否为空
func is_empty() -> bool:
	return current_index >= card_pool.size()

# 获取卡牌的原持有者（用于能量奖励）
func get_card_owner(card: Card) -> int:
	var card_key = _get_card_key(card)
	return card_owners.get(card_key, -1)

# 生成卡牌唯一标识
func _get_card_key(card: Card) -> String:
	# 使用卡牌ID和其在池中的位置作为标识
	return card.card_id + "_" + str(card_pool.find(card))

# 获取剩余卡牌数量
func get_remaining_count() -> int:
	return max(0, card_pool.size() - current_index)
