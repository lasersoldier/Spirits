class_name CardPackUI
extends Control

# UI节点引用
@onready var pack_card_container: Control = $CenterContainer/PackStage/PackCardContainer
@onready var pack_card: Panel = $CenterContainer/PackStage/PackCardContainer/PackCard
@onready var pack_card_label: Label = $CenterContainer/PackStage/PackCardContainer/PackCard/VBoxContainer/Label
@onready var pack_card_subtitle: Label = $CenterContainer/PackStage/PackCardContainer/PackCard/VBoxContainer/SubtitleLabel
@onready var opening_animation: Control = $CenterContainer/PackStage/OpeningAnimation
@onready var opening_glow: ColorRect = $CenterContainer/PackStage/OpeningAnimation/GlowRect
@onready var opening_icon: Control = $CenterContainer/PackStage/OpeningAnimation/IconContainer
@onready var card_display_container: GridContainer = $CenterContainer/CardDisplayContainer
@onready var open_another_button: Button = $CenterContainer/ButtonBar/OpenAnotherButton
@onready var back_button: Button = $TopBar/BackButton
@onready var status_label: Label = $TopBar/StatusLabel

# 系统引用
var player_data_manager: PlayerDataManager
var player_collection: PlayerCollection
var card_library: CardLibrary
var pack_opener: CardPackOpener

# 状态
var is_opening: bool = false
var opened_cards: Array[Dictionary] = []

# 卡牌卡片场景
const CARD_CARD_SCENE = preload("res://scenes/ui/card_face.tscn")

func _ready():
	# 初始化系统
	player_data_manager = PlayerDataManager.new()
	player_collection = PlayerCollection.new(player_data_manager)
	card_library = CardLibrary.new()
	pack_opener = CardPackOpener.new(card_library, player_collection)
	
	# 连接信号
	if pack_card:
		pack_card.gui_input.connect(_on_pack_card_input)
	if open_another_button:
		open_another_button.pressed.connect(_on_open_another_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# 初始化UI状态
	_show_pack_card()
	opening_animation.visible = false
	card_display_container.visible = false
	open_another_button.visible = false

# 显示卡包卡片
func _show_pack_card():
	pack_card_container.visible = true
	opening_animation.visible = false
	card_display_container.visible = false
	open_another_button.visible = false
	
	# 设置卡包卡片样式
	if pack_card:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
		style.border_color = Color(1.0, 0.65, 0.0, 0.3)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		pack_card.add_theme_stylebox_override("panel", style)
		
		# 添加悬停效果
		pack_card.mouse_entered.connect(_on_pack_card_mouse_entered)
		pack_card.mouse_exited.connect(_on_pack_card_mouse_exited)

# 卡包卡片鼠标进入
func _on_pack_card_mouse_entered():
	if pack_card:
		pack_card.scale = Vector2(1.05, 1.05)
		var style = pack_card.get_theme_stylebox("panel")
		if style:
			style.border_color = Color(1.0, 0.65, 0.0, 0.6)

# 卡包卡片鼠标离开
func _on_pack_card_mouse_exited():
	if pack_card:
		pack_card.scale = Vector2(1.0, 1.0)
		var style = pack_card.get_theme_stylebox("panel")
		if style:
			style.border_color = Color(1.0, 0.65, 0.0, 0.3)

# 卡包卡片输入
func _on_pack_card_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_opening and opened_cards.is_empty():
			_open_pack()

# 开启卡包
func _open_pack():
	if is_opening:
		return
	
	is_opening = true
	pack_card_container.visible = false
	
	# 显示开包动画
	_show_opening_animation()
	
	# 等待动画后开包
	await get_tree().create_timer(2.0).timeout
	
	# 执行开包
	opened_cards = pack_opener.open_pack("standard")
	
	# 隐藏动画，显示卡牌
	opening_animation.visible = false
	_display_opened_cards()
	
	is_opening = false

# 显示开包动画
func _show_opening_animation():
	opening_animation.visible = true
	
	# 白色闪烁效果
	if opening_glow:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(opening_glow, "modulate:a", 0.3, 0.3)
		tween.tween_property(opening_glow, "modulate:a", 0.8, 0.3)
	
	# 旋转图标
	if opening_icon:
		var rotate_tween = create_tween()
		rotate_tween.set_loops()
		rotate_tween.tween_property(opening_icon, "rotation_degrees", 360, 1.0)

# 显示开出的卡牌
func _display_opened_cards():
	if not card_display_container:
		return
	
	card_display_container.visible = true
	open_another_button.visible = true
	
	# 清空现有显示
	_clear_card_display()
	
	# 显示每张卡牌
	for i in range(opened_cards.size()):
		var card_data = opened_cards[i]
		var card_card = CARD_CARD_SCENE.instantiate()
		card_display_container.add_child(card_card)
		card_card.set_card_data(card_data)
		
		# 添加延迟动画效果
		card_card.modulate.a = 0.0
		card_card.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		if i > 0:
			tween.tween_interval(i * 0.1)
		tween.parallel().tween_property(card_card, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(card_card, "scale", Vector2(1.0, 1.0), 0.3)
	
	if status_label:
		status_label.text = "已开出 " + str(opened_cards.size()) + " 张卡牌！"

# 清空卡牌显示
func _clear_card_display():
	if card_display_container:
		for child in card_display_container.get_children():
			child.queue_free()

# 再开一包
func _on_open_another_pressed():
	opened_cards.clear()
	_clear_card_display()
	_show_pack_card()
	if status_label:
		status_label.text = ""

# 返回主菜单
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
