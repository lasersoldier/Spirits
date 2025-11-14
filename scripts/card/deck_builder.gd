class_name DeckBuilder
extends RefCounted

# 卡牌库引用
var card_library: CardLibrary

func _init(library: CardLibrary):
	card_library = library

# 人类玩家构建卡组：手动构建30张卡组（从10张基础卡中重复组合）
func build_human_deck(selected_cards: Dictionary) -> Array[Card]:
	# selected_cards格式: {card_id: count, ...}
	# 总数量应为30张
	var total_count = 0
	for count in selected_cards.values():
		total_count += count
	
	if total_count != 30:
		push_error("卡组必须包含30张卡牌")
		return []
	
	var deck: Array[Card] = []
	
	for card_id in selected_cards.keys():
		var count = selected_cards[card_id]
		var card_data = card_library.get_card_data(card_id)
		
		if card_data.is_empty():
			push_error("卡牌数据不存在: " + card_id)
			continue
		
		for i in range(count):
			var card = Card.new(card_data)
			deck.append(card)
	
	return deck

# AI玩家构建卡组：按难度自动生成
func build_ai_deck(difficulty: String, player_id: int) -> Array[Card]:
	var deck: Array[Card] = []
	
	match difficulty:
		"easy":
			# 简易难度：单属性卡牌为主（70%单属性，30%双属性）
			deck = _build_ai_deck_easy(player_id)
		"normal":
			# 标准难度：单/双属性均衡（50%单属性，50%双属性）
			deck = _build_ai_deck_normal(player_id)
		"hard":
			# 困难难度：双属性为主（30%单属性，70%双属性）
			deck = _build_ai_deck_hard(player_id)
		_:
			deck = _build_ai_deck_normal(player_id)
	
	return deck

func _build_ai_deck_easy(_player_id: int) -> Array[Card]:
	var deck: Array[Card] = []
	var single_cards = card_library.get_single_attribute_cards()
	var dual_cards = card_library.get_dual_attribute_cards()
	
	# 21张单属性卡（70%）
	var single_count = 21
	for i in range(single_count):
		var card_data = single_cards[randi() % single_cards.size()]
		deck.append(Card.new(card_data))
	
	# 9张双属性卡（30%）
	var dual_count = 9
	for i in range(dual_count):
		var card_data = dual_cards[randi() % dual_cards.size()]
		deck.append(Card.new(card_data))
	
	# 打乱顺序
	deck.shuffle()
	return deck

func _build_ai_deck_normal(_player_id: int) -> Array[Card]:
	var deck: Array[Card] = []
	var single_cards = card_library.get_single_attribute_cards()
	var dual_cards = card_library.get_dual_attribute_cards()
	
	# 15张单属性卡（50%）
	var single_count = 15
	for i in range(single_count):
		var card_data = single_cards[randi() % single_cards.size()]
		deck.append(Card.new(card_data))
	
	# 15张双属性卡（50%）
	var dual_count = 15
	for i in range(dual_count):
		var card_data = dual_cards[randi() % dual_cards.size()]
		deck.append(Card.new(card_data))
	
	# 打乱顺序
	deck.shuffle()
	return deck

func _build_ai_deck_hard(_player_id: int) -> Array[Card]:
	var deck: Array[Card] = []
	var single_cards = card_library.get_single_attribute_cards()
	var dual_cards = card_library.get_dual_attribute_cards()
	
	# 9张单属性卡（30%）
	var single_count = 9
	for i in range(single_count):
		var card_data = single_cards[randi() % single_cards.size()]
		deck.append(Card.new(card_data))
	
	# 21张双属性卡（70%）
	var dual_count = 21
	for i in range(dual_count):
		var card_data = dual_cards[randi() % dual_cards.size()]
		deck.append(Card.new(card_data))
	
	# 打乱顺序
	deck.shuffle()
	return deck

