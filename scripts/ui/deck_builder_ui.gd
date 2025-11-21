class_name DeckBuilderUI
extends Control

# UI节点引用
@onready var top_bar: Control = $TopBar
@onready var title_label: Label = $TopBar/TitleLabel
@onready var deck_count_label: Label = $TopBar/DeckCountLabel
@onready var save_button: Button = $TopBar/SaveButton
@onready var back_button: Button = $TopBar/BackButton

@onready var filter_container: HBoxContainer = $MainContainer/LeftPanel/FilterContainer
@onready var collection_grid: GridContainer = $MainContainer/LeftPanel/CollectionScroll/CollectionGrid
@onready var deck_list: ItemList = $MainContainer/RightPanel/DeckList
@onready var deck_title_label: Label = $MainContainer/RightPanel/TitleLabel
@onready var remove_card_button: Button = $MainContainer/RightPanel/DeckButtonBar/RemoveCardButton
@onready var clear_deck_button: Button = $MainContainer/RightPanel/DeckButtonBar/ClearDeckButton

# 系统引用
var player_data_manager: PlayerDataManager
var player_collection: PlayerCollection
var player_deck: PlayerDeck
var card_library: CardLibrary

# 当前过滤器和选中的卡牌
var current_filter: String = "ALL"
var selected_deck_card: String = ""

# 卡牌卡片场景
const CARD_CARD_SCENE = preload("res://scenes/ui/card_face.tscn")

# 属性映射
var attribute_names: Dictionary = {
	"ALL": "全部",
	"fire": "火",
	"water": "水",
	"wind": "风",
	"rock": "岩"
}

func _ready():
	# 初始化系统
	player_data_manager = PlayerDataManager.new()
	player_collection = PlayerCollection.new(player_data_manager)
	player_deck = PlayerDeck.new(player_data_manager, player_collection)
	card_library = CardLibrary.new()
	
	# 连接信号
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if deck_list:
		deck_list.item_selected.connect(_on_deck_item_selected)
		deck_list.item_activated.connect(_on_deck_item_activated)
	if remove_card_button:
		remove_card_button.pressed.connect(_on_remove_card_pressed)
	if clear_deck_button:
		clear_deck_button.pressed.connect(_on_clear_deck_pressed)
	
	# 创建过滤器按钮
	_create_filter_buttons()
	
	# 刷新UI
	_refresh_collection_grid()
	_refresh_deck_list()
	_update_deck_count()
	_update_deck_action_buttons()

# 创建过滤器按钮
func _create_filter_buttons():
	if not filter_container:
		return
	
	# 清空现有按钮
	for child in filter_container.get_children():
		child.queue_free()
	
	# 创建过滤器按钮
	var filters = ["ALL", "fire", "water", "wind", "rock"]
	for filter_attr in filters:
		var button = Button.new()
		button.text = attribute_names.get(filter_attr, filter_attr)
		button.custom_minimum_size = Vector2(80, 32)
		button.pressed.connect(func(): _on_filter_selected(filter_attr))
		filter_container.add_child(button)
	
	# 更新按钮样式
	_update_filter_buttons()

# 更新过滤器按钮样式
func _update_filter_buttons():
	if not filter_container:
		return
	
	for i in range(filter_container.get_child_count()):
		var button = filter_container.get_child(i) as Button
		if not button:
			continue
		
		var filter_attr = ["ALL", "fire", "water", "wind", "rock"][i]
		var is_selected = (filter_attr == current_filter)
		
		var style = StyleBoxFlat.new()
		if is_selected:
			style.bg_color = Color(0.3, 0.3, 0.35, 1.0)
			style.border_color = Color(1.0, 0.75, 0.25, 1.0)
		else:
			style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
			style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		
		button.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.25, 0.25, 0.3, 0.8)
		button.add_theme_stylebox_override("hover", hover_style)

# 过滤器选择
func _on_filter_selected(filter_attr: String):
	current_filter = filter_attr
	_update_filter_buttons()
	_refresh_collection_grid()

# 刷新收藏网格
func _refresh_collection_grid():
	if not collection_grid:
		return
	
	# 清空现有卡牌
	for child in collection_grid.get_children():
		child.queue_free()
	
	# 获取所有卡牌ID
	var all_card_ids = card_library.get_all_card_ids()
	
	# 过滤卡牌
	var filtered_cards: Array[String] = []
	for card_id in all_card_ids:
		var card_data = card_library.get_card_data(card_id)
		if card_data.is_empty():
			continue
		
		# 检查是否拥有
		var owned_count = player_collection.get_card_count(card_id)
		if owned_count == 0:
			continue
		
		# 应用过滤器
		if current_filter != "ALL":
			var attributes = card_data.get("attributes", [])
			if current_filter not in attributes:
				continue
		
		filtered_cards.append(card_id)
	
	# 创建卡牌卡片
	for card_id in filtered_cards:
		var card_data = card_library.get_card_data(card_id)
		var owned_count = player_collection.get_card_count(card_id)
		
		var card_card: CardFace = CARD_CARD_SCENE.instantiate()
		collection_grid.add_child(card_card)
		card_card.set_card_data(card_data)
		# 确保 CardFace 本身能接收鼠标事件
		card_card.mouse_filter = Control.MOUSE_FILTER_STOP
		# 将所有子节点的 mouse_filter 设置为 IGNORE，让事件传递到 CardFace
		_set_all_children_mouse_filter_ignore(card_card)
		print("DeckBuilder: 创建卡牌UI card_id=", card_id, " mouse_filter=", card_card.mouse_filter)
		card_card.card_clicked.connect(func(clicked_id: String):
			print("DeckBuilder: 收到 card_clicked 信号，clicked_id=", clicked_id)
			_on_collection_card_clicked(clicked_id)
		)
		print("DeckBuilder: 已连接 card_clicked 信号到回调")
		
		# 显示拥有数量
		if card_card.has_method("set_owned_count"):
			card_card.set_owned_count(owned_count)

# 收藏卡牌点击
func _on_collection_card_clicked(card_id: String):
	print("DeckBuilder: _on_collection_card_clicked 被调用，card_id=", card_id)
	var result = player_deck.add_card(card_id, 1)
	if result.get("success", false):
		print("DeckBuilder: 添加卡牌到套牌成功: ", card_id)
		_refresh_deck_list()
		_update_deck_count()
		_update_deck_action_buttons()
	else:
		print("DeckBuilder: 添加失败: ", result.get("message", ""))

# 刷新套牌列表
func _refresh_deck_list():
	if not deck_list:
		return
	
	deck_list.clear()
	
	var deck_data = player_deck.get_deck_data()
	
	for entry in deck_data:
		var card_id = entry.get("card_id", "")
		var count = entry.get("count", 0)
		var card_data = card_library.get_card_data(card_id)
		
		if card_data.is_empty():
			continue
		
		var card_name = card_data.get("name", card_id)
		var cost = card_data.get("energy_cost", 0)
		var display_text = "[" + str(cost) + "] " + card_name + " x" + str(count)
		deck_list.add_item(display_text)
		deck_list.set_item_metadata(deck_list.get_item_count() - 1, card_id)
	
	# 更新套牌数量显示
	_update_deck_count()
	_update_deck_action_buttons()

# 更新套牌数量显示
func _update_deck_count():
	if deck_count_label:
		var total = player_deck.get_total_count()
		var is_valid = total == 36
		deck_count_label.text = str(total) + "/36"
		if is_valid:
			deck_count_label.modulate = Color.GREEN
		else:
			deck_count_label.modulate = Color(1.0, 0.65, 0.0)  # 琥珀色

# 套牌列表项选中
func _on_deck_item_selected(index: int):
	if deck_list:
		selected_deck_card = deck_list.get_item_metadata(index) as String
	_update_deck_action_buttons()

func _on_deck_item_activated(index: int):
	if deck_list:
		selected_deck_card = deck_list.get_item_metadata(index) as String
	_on_remove_card()

# 移除卡牌
func _on_remove_card():
	if selected_deck_card.is_empty():
		return
	
	var result = player_deck.remove_card(selected_deck_card, 1)
	if result.get("success", false):
		_refresh_deck_list()
		_update_deck_count()
		_update_deck_action_buttons()
		selected_deck_card = ""
	else:
		print("移除失败: ", result.get("message", ""))

func _on_remove_card_pressed():
	_on_remove_card()

func _on_clear_deck_pressed():
	player_deck.clear_deck()
	selected_deck_card = ""
	_refresh_deck_list()
	_update_deck_count()
	_update_deck_action_buttons()

func _update_deck_action_buttons():
	if remove_card_button:
		remove_card_button.disabled = selected_deck_card.is_empty()
	if clear_deck_button:
		var has_cards = player_deck and player_deck.get_total_count() > 0
		clear_deck_button.disabled = not has_cards

# 保存套牌
func _on_save_button_pressed():
	var validation = player_deck.validate_deck()
	if validation.get("valid", false):
		player_deck._save_to_data_manager()
		print("套牌已保存")
		# 可以显示保存成功提示
	else:
		print("套牌不合法，无法保存: ", validation.get("message", ""))

# 返回主菜单
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# 递归设置所有子节点的 mouse_filter 为 IGNORE
func _set_all_children_mouse_filter_ignore(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_all_children_mouse_filter_ignore(child)
