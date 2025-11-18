class_name HandCardManager
extends RefCounted

# 手牌上限
const MAX_HAND_SIZE: int = 8

# 玩家ID
var player_id: int = -1

# 当前手牌
var hand_cards: Array[Card] = []

# 弃牌记录
var discarded_cards: Array[Dictionary] = []  # 格式: {card: Card, reason: String}

signal hand_updated(player_id: int, hand_size: int)
signal card_discarded(card: Card, reason: String)

func _init(p_id: int):
	player_id = p_id

# 添加卡牌到手牌
func add_card(card: Card) -> bool:
	print("HandCardManager: add_card 被调用，卡牌: ", card.card_name if card else "null")
	print("HandCardManager: 当前手牌数量: ", hand_cards.size(), " 上限: ", MAX_HAND_SIZE)
	if hand_cards.size() >= MAX_HAND_SIZE:
		# 手牌已满，需要弃牌
		print("HandCardManager: 手牌已满，无法添加卡牌")
		return false
	
	hand_cards.append(card)
	print("HandCardManager: 成功添加卡牌，当前手牌数量: ", hand_cards.size())
	print("HandCardManager: 手牌中的卡牌: ", hand_cards.map(func(c): return c.card_name))
	hand_updated.emit(player_id, hand_cards.size())
	return true

# 抽卡后处理（如果超过上限需要弃牌）
func draw_card_with_discard(card: Card) -> Card:
	if hand_cards.size() < MAX_HAND_SIZE:
		hand_cards.append(card)
		hand_updated.emit(player_id, hand_cards.size())
		return null
	else:
		# 手牌已满，返回需要弃置的卡牌（由调用者决定弃哪张）
		return card

# 移除卡牌（使用或弃置）
func remove_card(card: Card, reason: String = "used"):
	print("HandCardManager: remove_card 被调用，卡牌: ", card.card_name, " 原因: ", reason)
	print("HandCardManager: 当前手牌数量: ", hand_cards.size())
	
	# 尝试通过名称查找卡牌（因为对象引用可能不同）
	var index = -1
	for i in range(hand_cards.size()):
		if hand_cards[i].card_name == card.card_name:
			index = i
			break
	
	if index >= 0:
		var removed_card = hand_cards[index]  # 先获取卡牌
		hand_cards.remove_at(index)  # 然后移除（remove_at返回void）
		discarded_cards.append({"card": removed_card, "reason": reason})
		card_discarded.emit(removed_card, reason)
		hand_updated.emit(player_id, hand_cards.size())
		print("HandCardManager: 成功移除卡牌，剩余手牌数量: ", hand_cards.size())
	else:
		print("HandCardManager: 错误：未找到卡牌 ", card.card_name, " 在手牌中")
		print("HandCardManager: 当前手牌中的卡牌: ", hand_cards.map(func(c): return c.card_name))

# 弃置卡牌
func discard_card(card: Card):
	remove_card(card, "discarded")

# 检查卡牌是否可以使用（不需要能量，能量只用于租用精灵）
func can_use_card(card: Card, _energy: int, _sprites: Array[Sprite]) -> Dictionary:
	var result = {
		"can_use": false,
		"reason": ""
	}
	
	# 检查冷却
	if not card.is_cooldown_ready():
		result.reason = "卡牌冷却中"
		return result
	
	# 检查属性匹配（需要根据具体卡牌类型和精灵属性判断）
	# 这里简化处理，实际需要更复杂的逻辑
	result.can_use = true
	return result

# 获取可用的卡牌列表（根据精灵，不需要能量）
func get_usable_cards(_energy: int, sprites: Array[Sprite]) -> Array[Card]:
	var usable: Array[Card] = []
	
	for card in hand_cards:
		var check_result = can_use_card(card, 0, sprites)  # 能量参数不再使用
		if check_result.can_use:
			usable.append(card)
	
	return usable

# 获取手牌数量
func get_hand_size() -> int:
	return hand_cards.size()

# 检查手牌是否已满
func is_hand_full() -> bool:
	return hand_cards.size() >= MAX_HAND_SIZE

# 清空手牌
func clear_hand():
	hand_cards.clear()
	hand_updated.emit(player_id, 0)
