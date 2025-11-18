class_name HandCardUI
extends HBoxContainer

# 游戏管理器引用
var game_manager: GameManager = null

# 已连接手牌信号的玩家ID集合
var connected_hand_players: Array[int] = []

# 信号：卡牌拖动相关（转发给MainUI处理）
signal card_drag_started(card_ui: CardUI, card: Card)
signal card_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)
signal card_right_drag_started(card_ui: CardUI, card: Card)
signal card_right_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)

func _ready():
	# 设置手牌区域的对齐方式为居中
	alignment = BoxContainer.ALIGNMENT_CENTER

# 设置游戏管理器引用
func set_game_manager(gm: GameManager):
	game_manager = gm
	_connect_hand_signals()
	# 更新所有卡牌的拖动状态
	_update_all_cards_drag_state()

# 连接手牌更新信号
func _connect_hand_signals():
	if not game_manager:
		print("HandCardUI: _connect_hand_signals - 游戏管理器不存在")
		return
	
	print("HandCardUI: _connect_hand_signals - 开始连接信号，当前hand_managers数量: ", game_manager.hand_managers.size())
	
	# 连接所有玩家的手牌更新信号
	for player_id in game_manager.hand_managers.keys():
		# 避免重复连接
		if player_id in connected_hand_players:
			print("HandCardUI: 玩家 ", player_id, " 的信号已连接，跳过")
			continue
		
		var hand_manager = game_manager.hand_managers[player_id]
		if hand_manager:
			# 连接信号（信号已经包含player_id作为第一个参数，不需要绑定）
			print("HandCardUI: 连接玩家 ", player_id, " 的手牌更新信号")
			hand_manager.hand_updated.connect(_on_hand_updated)
			connected_hand_players.append(player_id)
			print("HandCardUI: 成功连接玩家 ", player_id, " 的信号")
		else:
			print("HandCardUI: 警告：玩家 ", player_id, " 的手牌管理器不存在")

# 更新手牌栏
func update_hand_cards(cards: Array[Card]):
	print("HandCardUI: update_hand_cards 被调用，卡牌数量: ", cards.size())
	print("HandCardUI: 更新前子节点数量: ", get_children().size())
	
	# 清空现有手牌显示
	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	# 等待一帧确保节点被完全移除（使用call_deferred）
	call_deferred("_create_card_uis", cards)

# 延迟创建卡牌UI（在节点清空后）
func _create_card_uis(cards: Array[Card]):
	# 设置手牌区域的对齐方式为居中
	alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 创建卡牌UI
	for card in cards:
		var card_ui = _create_card_ui(card)
		add_child(card_ui)
	
	print("HandCardUI: 已创建 ", get_children().size(), " 个卡牌UI")
	
	# 更新所有卡牌的拖动状态
	_update_all_cards_drag_state()

# 创建卡牌UI（使用全局缩放）
func _create_card_ui(card: Card) -> Control:
	var card_ui = CardUI.new()
	card_ui.set_card(card)
	# 设置游戏管理器引用（用于检查阶段）
	if game_manager:
		card_ui.set_game_manager(game_manager)
	# 固定卡牌尺寸（不使用缩放，直接使用像素值）
	var card_width = 120
	var card_height = 200  # 固定高度200，确保在屏幕内
	card_ui.custom_minimum_size = Vector2(card_width, card_height)
	card_ui.size = Vector2(card_width, card_height)
	# 不使用UIScaleManager缩放，直接设置固定大小
	# 允许描述文字换行显示，不裁剪超出内容
	card_ui.clip_contents = false
	
	# 连接拖动信号（转发给MainUI）
	card_ui.card_drag_started.connect(_on_card_drag_started)
	card_ui.card_drag_ended.connect(_on_card_drag_ended)
	
	# 连接右键拖拽信号（弃牌行动）
	card_ui.card_right_drag_started.connect(_on_card_right_drag_started)
	card_ui.card_right_drag_ended.connect(_on_card_right_drag_ended)
	
	# 使用固定像素值，不缩放
	# 卡牌名称（顶部居中）
	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.position = Vector2(3, 3)
	name_label.size = Vector2(card_width - 30, 22)  # 留出属性标识空间
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = true
	card_ui.add_child(name_label)
	
	# 属性标识（右上角小圆圈）
	var attr_container = HBoxContainer.new()
	attr_container.position = Vector2(card_width - 25, 5)
	for i in range(card.attributes.size()):
		var attr = card.attributes[i]
		var attr_circle = ColorRect.new()
		attr_circle.custom_minimum_size = Vector2(10, 10)
		attr_circle.color = _get_attribute_color(attr)
		attr_container.add_child(attr_circle)
	card_ui.add_child(attr_container)
	
	# 卡牌描述（中间区域，使用RichTextLabel）
	var desc_label = RichTextLabel.new()
	desc_label.text = card.effect_description
	desc_label.position = Vector2(4, 28)
	var desc_height = card_height - 28 - 20
	desc_label.size = Vector2(card_width - 8, desc_height)
	desc_label.custom_minimum_size = Vector2(card_width - 8, desc_height)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击继续传递给卡牌
	desc_label.add_theme_font_size_override("normal_font_size", 10)
	desc_label.add_theme_color_override("default_color", Color(0.88, 0.88, 0.88))
	desc_label.scroll_active = false  # 禁用滚动
	desc_label.fit_content = true  # 自动适应内容
	desc_label.bbcode_enabled = false  # 不启用富文本格式
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_contents = false
	card_ui.add_child(desc_label)
	
	# 能量消耗（底部，确保在卡牌内部，提高z-index确保在描述文字上方显示）
	var cost_label = Label.new()
	cost_label.text = "能量: " + str(card.energy_cost)
	cost_label.position = Vector2(4, card_height - 18)  # 确保在卡牌内部
	cost_label.z_index = 10  # 提高层级，确保在描述文字上方
	cost_label.size = Vector2(card_width - 8, 16)
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # 金色
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.clip_contents = true
	card_ui.add_child(cost_label)
	
	return card_ui

# 获取属性颜色
func _get_attribute_color(attr: String) -> Color:
	match attr:
		"fire":
			return Color.RED
		"wind":
			return Color.CYAN
		"water":
			return Color.BLUE
		"rock":
			return Color.GRAY
		_:
			return Color.WHITE

# 手牌更新处理
func _on_hand_updated(player_id: int, hand_size: int):
	# 只更新人类玩家的手牌显示
	if player_id == GameManager.HUMAN_PLAYER_ID:
		print("HandCardUI: 收到手牌更新信号，玩家ID: ", player_id, " 手牌数量: ", hand_size)
		var hand_manager = game_manager.hand_managers.get(player_id)
		if hand_manager:
			print("HandCardUI: 更新手牌显示，当前手牌数量: ", hand_manager.hand_cards.size())
			update_hand_cards(hand_manager.hand_cards)
		else:
			print("HandCardUI: 错误：无法获取手牌管理器")

# 刷新手牌显示
func refresh_hand_cards():
	print("HandCardUI: refresh_hand_cards 被调用")
	if not game_manager:
		print("HandCardUI: 游戏管理器不存在")
		return
	
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		print("HandCardUI: 更新手牌显示，手牌数量: ", hand_manager.hand_cards.size())
		update_hand_cards(hand_manager.hand_cards)
	else:
		print("HandCardUI: 手牌管理器不存在")

# 更新所有卡牌的拖动状态
func _update_all_cards_drag_state():
	if not game_manager:
		return
	
	for child in get_children():
		if child is CardUI:
			var card_ui = child as CardUI
			if not card_ui.game_manager:
				card_ui.set_game_manager(game_manager)
			card_ui._update_drag_state()

# 信号转发：卡牌拖动开始
func _on_card_drag_started(card_ui: CardUI, card: Card):
	card_drag_started.emit(card_ui, card)

# 信号转发：卡牌拖动结束
func _on_card_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2):
	card_drag_ended.emit(card_ui, card, drop_position)

# 信号转发：右键拖拽开始
func _on_card_right_drag_started(card_ui: CardUI, card: Card):
	card_right_drag_started.emit(card_ui, card)

# 信号转发：右键拖拽结束
func _on_card_right_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2):
	card_right_drag_ended.emit(card_ui, card, drop_position)

