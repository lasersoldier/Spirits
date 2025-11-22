class_name CardFace
extends Control

signal card_clicked(card_id: String)

const ATTRIBUTE_COLORS := {
	"fire": Color(1.0, 0.4, 0.1),
	"water": Color(0.3, 0.6, 1.0),
	"wind": Color(0.4, 0.9, 0.9),
	"rock": Color(0.75, 0.75, 0.75),
	"default": Color(0.95, 0.95, 0.95)
}

const RARITY_STYLES := {
	"common": {
		"border": Color(0.5, 0.5, 0.55, 1.0),
		"label": "普通"
	},
	"rare": {
		"border": Color(0.98, 0.84, 0.3, 1.0),
		"label": "稀有"
	},
	"epic": {
		"border": Color(0.8, 0.4, 1.0, 1.0),
		"label": "史诗"
	},
	"legendary": {
		"border": Color(1.0, 0.6, 0.1, 1.0),
		"label": "传说"
	}
}

var card: Card
var card_id: String = ""
var owned_count: int = 0
var disabled: bool = false

@onready var card_panel: Panel = $CardPanel
@onready var name_label: Label = $CardPanel/Content/VBox/TopRow/NameLabel
@onready var owned_label: Label = $CardPanel/Content/VBox/TopRow/OwnedLabel
@onready var attr_container: HBoxContainer = $CardPanel/Content/VBox/AttrRow
@onready var card_image: TextureRect = $CardPanel/Content/VBox/CardImage
@onready var desc_label: RichTextLabel = $CardPanel/Content/VBox/Description
@onready var range_label: Label = $CardPanel/Content/VBox/RangeLabel
@onready var rarity_label: Label = $CardPanel/Content/VBox/BottomRow/RarityLabel
@onready var cost_label: Label = $CardPanel/Content/VBox/BottomRow/CostLabel
@onready var selection_highlight: ColorRect = $SelectionHighlight

# 预览相关
var preview_timer: Timer = null
var card_preview_scene = preload("res://scenes/ui/card_preview.tscn")
var current_preview: Control = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("CardFace _ready: 设置 mouse_filter=STOP, card_id=", card_id)
	if owned_label:
		owned_label.visible = false
	if selection_highlight:
		selection_highlight.visible = false
	if range_label:
		range_label.visible = false
	_configure_description_label()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	print("CardFace _ready: 已连接 gui_input 信号")

func set_card(card_obj: Card):
	card = card_obj
	card_id = card.card_id
	_refresh()

func set_card_data(data: Dictionary):
	card = Card.new(data)
	card_id = card.card_id
	_refresh()

func set_owned_count(count: int):
	owned_count = count
	if owned_label:
		owned_label.visible = count > 0
		owned_label.text = "x" + str(count)

func set_selected(selected: bool):
	if selection_highlight:
		selection_highlight.visible = selected

func set_disabled(is_disabled: bool):
	disabled = is_disabled
	modulate = Color(0.65, 0.65, 0.65, 0.85) if disabled else Color.WHITE

func _configure_description_label():
	if not desc_label:
		return
	desc_label.fit_content = false
	desc_label.bbcode_enabled = false
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _refresh():
	if not card:
		return
	if not is_inside_tree():
		return
	_update_panel_style()
	_update_basic_info()
	_update_attributes()
	_update_card_image()
	_update_range_display()
	set_owned_count(owned_count)

func _update_basic_info():
	if name_label:
		name_label.text = card.card_name
	if desc_label:
		# 使用简称描述
		var text := card.get_short_description()
		if text.is_empty():
			text = card.card_id
		desc_label.text = text
	if cost_label:
		cost_label.text = "能量: " + str(card.energy_cost)
	if rarity_label:
		var rarity: String = card.rarity if card.rarity != "" else "common"
		var rarity_info: Dictionary = RARITY_STYLES.get(rarity, {})
		rarity_label.text = rarity_info.get("label", rarity.capitalize())

func _update_attributes():
	if not attr_container:
		return
	for child in attr_container.get_children():
		child.queue_free()
	for attr in card.attributes:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(10, 10)
		icon.color = ATTRIBUTE_COLORS.get(attr, ATTRIBUTE_COLORS["default"])
		attr_container.add_child(icon)

func _update_card_image():
	if not card_image:
		return
	# 预留图片加载逻辑，暂时显示占位符
	# 未来可以从资源路径加载：res://art/cards/{card_id}.png
	card_image.texture = null  # 暂时为空，等待图片资源

func _update_range_display():
	if not range_label or not card:
		return
	
	var range_text = ""
	
	# 检查是否有固定范围
	if card.range_override > 0:
		range_text = str(card.range_override) + "格"
	elif card.range_requirement == "follow_caster":
		range_text = "⚡"  # 自适应符号
	elif card.range_requirement != "":
		# 解析范围要求
		if card.range_requirement.begins_with("range_"):
			var range_num = card.range_requirement.replace("range_", "")
			range_text = range_num + "格"
		elif card.range_requirement == "adjacent":
			range_text = "1格"
		else:
			range_text = card.range_requirement
	
	if range_text != "":
		range_label.text = range_text
		range_label.visible = true
	else:
		range_label.visible = false

func _update_panel_style():
	if not card_panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	var rarity: String = card.rarity if card.rarity != "" else "common"
	var rarity_info: Dictionary = RARITY_STYLES.get(rarity, {})
	style.border_color = rarity_info.get("border", Color(0.4, 0.4, 0.5))
	card_panel.add_theme_stylebox_override("panel", style)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("CardFace: 收到左键点击，card_id=", card_id, " mouse_filter=", mouse_filter)
		card_clicked.emit(card_id)
		print("CardFace: 已发射 card_clicked 信号")

func _on_mouse_entered():
	if not card:
		return
	# 启动预览定时器
	if preview_timer:
		preview_timer.queue_free()
	preview_timer = Timer.new()
	preview_timer.wait_time = 0.8
	preview_timer.one_shot = true
	preview_timer.timeout.connect(_show_preview)
	add_child(preview_timer)
	preview_timer.start()

func _on_mouse_exited():
	# 取消预览定时器
	if preview_timer:
		preview_timer.queue_free()
		preview_timer = null
	# 延迟关闭预览，给用户时间移动到预览窗口
	await get_tree().create_timer(0.15).timeout
	# 检查鼠标是否在预览窗口内
	if current_preview and is_instance_valid(current_preview):
		var mouse_pos = get_global_mouse_position()
		var preview_rect = current_preview.get_global_rect()
		if not preview_rect.has_point(mouse_pos):
			# 检查鼠标是否还在当前卡牌上
			var local_mouse = get_local_mouse_position()
			var card_rect = Rect2(Vector2.ZERO, size)
			if not card_rect.has_point(local_mouse):
				_close_preview()
	else:
		_close_preview()

func _show_preview():
	if not card or current_preview:
		return
	
	# 创建预览
	var preview = card_preview_scene.instantiate()
	if preview and preview.has_method("setup"):
		# 先添加到场景树，再设置，确保节点已初始化
		get_tree().root.add_child(preview)
		preview.setup(card)
		current_preview = preview
		
		# 定位预览（在鼠标附近）
		await get_tree().process_frame  # 等待一帧让预览计算大小
		var mouse_pos = get_global_mouse_position()
		var viewport_size = get_viewport().get_visible_rect().size
		var preview_size = preview.size if preview.size != Vector2.ZERO else Vector2(700, 500)
		
		# 确保预览不超出屏幕
		var pos_x = mouse_pos.x + 20
		var pos_y = mouse_pos.y - preview_size.y / 2
		
		if pos_x + preview_size.x > viewport_size.x:
			pos_x = mouse_pos.x - preview_size.x - 20
		if pos_y < 0:
			pos_y = 10
		if pos_y + preview_size.y > viewport_size.y:
			pos_y = viewport_size.y - preview_size.y - 10
		
		preview.position = Vector2(pos_x, pos_y)

func _close_preview():
	if current_preview:
		current_preview.queue_free()
		current_preview = null
