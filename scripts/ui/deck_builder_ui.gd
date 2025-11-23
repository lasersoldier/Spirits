class_name DeckBuilderUI
extends Control

# UI节点引用
@onready var top_bar: Control = $ContentLayer/TopBar
@onready var title_label: Label = $ContentLayer/TopBar/TitleLabel
@onready var deck_count_label: Label = $ContentLayer/TopBar/DeckCountLabel
@onready var shards_label: Label = $ContentLayer/TopBar/ShardsLabel
@onready var save_button: Button = $ContentLayer/TopBar/SaveButton
@onready var back_button: Button = $ContentLayer/TopBar/BackButton

@onready var left_panel: PanelContainer = $ContentLayer/MainContainer/LeftPanel
@onready var filter_container: HBoxContainer = $ContentLayer/MainContainer/LeftPanel/LeftContent/FilterContainer
@onready var collection_grid: GridContainer = $ContentLayer/MainContainer/LeftPanel/LeftContent/CollectionScroll/CollectionGrid
@onready var right_panel: Panel = $ContentLayer/MainContainer/RightPanel
@onready var deck_list: VBoxContainer = $ContentLayer/MainContainer/RightPanel/RightContent/DeckScroll/DeckListWrapper/DeckList
@onready var mana_curve: ManaCurve = $ContentLayer/MainContainer/RightPanel/RightContent/ManaCurveWrapper/ManaCurve
@onready var remove_card_button: Button = $ContentLayer/MainContainer/RightPanel/RightContent/DeckButtonBar/RemoveCardButton
@onready var clear_deck_button: Button = $ContentLayer/MainContainer/RightPanel/RightContent/DeckButtonBar/ClearDeckButton

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
const DECK_CARD_STRIP_SCENE = preload("res://scenes/ui/deck_card_strip.tscn")
const GLASS_SHADER = preload("res://resources/shaders/glass.gdshader")
const GRAYSCALE_SHADER = preload("res://resources/shaders/grayscale.gdshader")

# 属性映射和颜色
var attribute_names: Dictionary = {
	"ALL": "全部",
	"fire": "火",
	"water": "水",
	"wind": "风",
	"rock": "岩"
}

var attribute_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.1),
	"water": Color(0.3, 0.6, 1.0),
	"wind": Color(0.4, 0.9, 0.9),
	"rock": Color(0.75, 0.75, 0.75)
}

# 套牌条目的映射
var deck_strip_map: Dictionary = {}  # card_id -> DeckCardStrip

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
	if remove_card_button:
		remove_card_button.pressed.connect(_on_remove_card_pressed)
	if clear_deck_button:
		clear_deck_button.pressed.connect(_on_clear_deck_pressed)
	
	# 启用ESC键处理
	set_process_unhandled_input(true)
	
	# 设置玻璃材质
	_setup_glass_panels()
	
	# 创建过滤器按钮（符文图标）
	_create_filter_buttons()
	
	# 刷新UI
	_refresh_collection_grid()
	_refresh_deck_list()
	_update_deck_count()
	_update_shards_display()
	_update_deck_action_buttons()

func _setup_glass_panels():
	# 左侧面板玻璃效果
	if left_panel:
		var material = ShaderMaterial.new()
		material.shader = GLASS_SHADER
		material.set_shader_parameter("blur_amount", 3.0)
		material.set_shader_parameter("tint_color", Color(0.1, 0.15, 0.2, 0.3))
		left_panel.material = material
	
	# 右侧面板玻璃效果（稍微亮一点）
	if right_panel:
		var material = ShaderMaterial.new()
		material.shader = GLASS_SHADER
		material.set_shader_parameter("blur_amount", 3.0)
		material.set_shader_parameter("tint_color", Color(0.15, 0.2, 0.25, 0.35))
		right_panel.material = material

# --- 修复核心：筛选按钮 ---
func _create_filter_buttons():
	if not filter_container: return
	
	for child in filter_container.get_children(): child.queue_free()
	
	var filters = ["ALL", "fire", "water", "wind", "rock"]
	for filter_attr in filters:
		# 容器 (接收点击) - 使用 VBoxContainer 来正确布局
		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(60, 50)
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_theme_constant_override("separation", 4)
		
		# 文字标签 (在上方)
		var label = Label.new()
		label.name = "Label"
		label.text = attribute_names.get(filter_attr, filter_attr)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		label.custom_minimum_size = Vector2(0, 20)  # 固定文字区域高度
		container.add_child(label)
		
		# 背景色块/图标 (在下方) - 使用 Control 包装以便定位指示器
		var icon_container = Control.new()
		icon_container.name = "IconContainer"
		icon_container.custom_minimum_size = Vector2(40, 40)
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_container)
		
		# 彩色矩形块
		var rune_icon = ColorRect.new()
		rune_icon.name = "Icon"
		rune_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rune_icon.color = Color(0.2, 0.2, 0.2, 0.8) # 默认底色
		icon_container.add_child(rune_icon)
		
		# 选中指示器 (在彩色块底部)
		var indicator = ColorRect.new()
		indicator.name = "Indicator"
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		indicator.offset_top = -3
		indicator.color = Color(1.0, 0.8, 0.3, 0.0)
		icon_container.add_child(indicator)
		
		# 连接信号
		container.gui_input.connect(func(e): _on_filter_gui_input(e, filter_attr, container))
		container.mouse_entered.connect(func(): _on_filter_mouse_entered(container))
		container.mouse_exited.connect(func(): _on_filter_mouse_exited(container))
		
		filter_container.add_child(container)
	
	_update_filter_buttons()

func _update_filter_buttons():
	if not filter_container: return
	
	var filters = ["ALL", "fire", "water", "wind", "rock"]
	for i in range(filter_container.get_child_count()):
		var container = filter_container.get_child(i) as VBoxContainer
		var filter_attr = filters[i]
		var is_selected = (filter_attr == current_filter)
		
		var icon_container = container.get_node("IconContainer") as Control
		var icon = icon_container.get_node("Icon") as ColorRect
		var label = container.get_node("Label") as Label
		var indicator = icon_container.get_node("Indicator") as ColorRect
		
		# 颜色逻辑
		var target_color = Color(0.2, 0.2, 0.2, 0.8)
		if filter_attr != "ALL":
			target_color = attribute_colors.get(filter_attr, Color.WHITE)
			target_color.a = 1.0 if is_selected else 0.4
		else:
			target_color = Color(0.8, 0.8, 0.8, 1.0 if is_selected else 0.4)
			
		icon.color = target_color
		indicator.color = Color(1.0, 0.8, 0.3, 1.0) if is_selected else Color.TRANSPARENT
		
		# 选中时文字加粗/变亮
		if is_selected:
			label.modulate = Color(1.2, 1.2, 1.2, 1.0) # 发光
		else:
			label.modulate = Color(0.8, 0.8, 0.8, 1.0)

func _on_filter_gui_input(event: InputEvent, filter_attr: String, container: Control):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_filter_selected(filter_attr)
		# 简单的点击动画
		var tween = create_tween()
		tween.tween_property(container, "scale", Vector2(0.95, 0.95), 0.05)
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.05)

func _on_filter_mouse_entered(container: Control):
	container.modulate = Color(1.1, 1.1, 1.1, 1.0)

func _on_filter_mouse_exited(container: Control):
	container.modulate = Color.WHITE

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
		
		# 检查是否拥有（现在显示所有卡牌，包括未拥有的）
		var owned_count = player_collection.get_card_count(card_id)
		
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
		var available_count = _get_available_card_count(card_id)
		
		var card_card: CardFace = CARD_CARD_SCENE.instantiate()
		collection_grid.add_child(card_card)
		card_card.set_card_data(card_data)
		card_card.scale = Vector2(0.75, 0.75)  # 缩小以显示更多卡牌
		
		# 根据可用数量设置交互性
		if available_count > 0:
			card_card.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			card_card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 无法点击
		
		_set_all_children_mouse_filter_ignore(card_card)
		
		# 根据可用数量设置视觉效果
		if available_count == 0:
			# 没有可用卡牌：变暗
			card_card.modulate = Color(0.3, 0.3, 0.3, 0.5)
		elif owned_count == 0:
			# 未拥有卡牌：应用灰度效果
			card_card.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			card_card.modulate = Color.WHITE
		
		card_card.card_clicked.connect(func(clicked_id: String):
			_on_collection_card_clicked(clicked_id)
		)
		
		# 显示可用数量（拥有数量 - 套牌中数量）
		if card_card.has_method("set_owned_count"):
			card_card.set_owned_count(available_count)

# 获取可用卡牌数量（拥有数量 - 套牌中数量）
func _get_available_card_count(card_id: String) -> int:
	var owned_count = player_collection.get_card_count(card_id)
	var deck_count = player_deck.get_card_count(card_id)
	return max(0, owned_count - deck_count)

# 收藏卡牌点击
func _on_collection_card_clicked(card_id: String):
	var available_count = _get_available_card_count(card_id)
	if available_count == 0:
		# 没有可用卡牌，播放摇晃动画
		var card_node = _find_card_in_grid(card_id)
		if card_node:
			var tween = create_tween()
			tween.set_loops(3)
			var orig_x = card_node.position.x
			tween.tween_property(card_node, "position:x", orig_x - 5, 0.05)
			tween.tween_property(card_node, "position:x", orig_x + 5, 0.05)
			tween.tween_property(card_node, "position:x", orig_x, 0.05)
		return
	
	var result = player_deck.add_card(card_id, 1)
	if result.get("success", false):
		_refresh_deck_list()
		_refresh_collection_grid()  # 刷新收藏网格以更新数量显示
		_update_deck_count()
		_update_deck_action_buttons()
		_update_mana_curve()
	else:
		print("DeckBuilder: 添加失败: ", result.get("message", ""))

func _find_card_in_grid(card_id: String) -> CardFace:
	for child in collection_grid.get_children():
		if child is CardFace and child.card_id == card_id:
			return child
	return null

# 刷新套牌列表
func _refresh_deck_list():
	if not deck_list:
		return
	
	# 清空现有条目
	for child in deck_list.get_children():
		child.queue_free()
	deck_strip_map.clear()
	
	var deck_data = player_deck.get_deck_data()
	
	for entry in deck_data:
		var card_id = entry.get("card_id", "")
		var count = entry.get("count", 0)
		var card_data = card_library.get_card_data(card_id)
		
		if card_data.is_empty():
			continue
		
		# 创建 DeckCardStrip
		var strip: DeckCardStrip = DECK_CARD_STRIP_SCENE.instantiate()
		deck_list.add_child(strip)
		strip.set_card_data(card_id, card_data, count)
		strip.card_clicked.connect(func(id: String): _on_deck_strip_clicked(id))
		deck_strip_map[card_id] = strip
	
	# 更新套牌数量显示
	_update_deck_count()
	_update_deck_action_buttons()
	_update_mana_curve()

func _on_deck_strip_clicked(card_id: String):
	selected_deck_card = card_id
	_update_deck_action_buttons()
	# 高亮选中的条目
	for id in deck_strip_map:
		var strip = deck_strip_map[id]
		if strip:
			strip.set_selected(id == card_id)

# 更新套牌数量显示
func _update_deck_count():
	if deck_count_label:
		var total = player_deck.get_total_count()
		var is_valid = total == 36
		deck_count_label.text = str(total) + "/36"
		
		if is_valid:
			# 金色，带呼吸效果
			deck_count_label.modulate = Color(1.0, 0.84, 0.3, 1.0)
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(deck_count_label, "modulate", Color(1.0, 0.9, 0.5, 1.0), 1.0)
			tween.tween_property(deck_count_label, "modulate", Color(1.0, 0.84, 0.3, 1.0), 1.0)
		else:
			deck_count_label.modulate = Color(0.4, 0.7, 1.0, 1.0)  # 淡蓝色

func _update_mana_curve():
	if mana_curve:
		var deck_data = player_deck.get_deck_data()
		# 为每个条目添加 energy_cost
		for entry in deck_data:
			var card_id = entry.get("card_id", "")
			var card_data = card_library.get_card_data(card_id)
			if not card_data.is_empty():
				entry["energy_cost"] = card_data.get("energy_cost", 0)
		mana_curve.update_curve(deck_data)

# 更新碎片显示
func _update_shards_display():
	if shards_label:
		var shards = player_data_manager.get_shards()
		shards_label.text = "碎片: " + str(shards)

# 移除卡牌
func _on_remove_card():
	if selected_deck_card.is_empty():
		return
	
	var result = player_deck.remove_card(selected_deck_card, 1)
	if result.get("success", false):
		_refresh_deck_list()
		_refresh_collection_grid()  # 刷新收藏网格以更新数量显示
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
	_refresh_collection_grid()  # 刷新收藏网格以更新数量显示
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
		# 调用保存方法（现在会保存到数据管理器）
		player_deck.save_to_data_manager()
		print("套牌已保存")
		# 可以显示保存成功提示
	else:
		print("套牌不合法，无法保存: ", validation.get("message", ""))

# 返回主菜单
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ESC键处理
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not event.echo:
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

# 递归设置所有子节点的 mouse_filter 为 IGNORE
func _set_all_children_mouse_filter_ignore(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_all_children_mouse_filter_ignore(child)
