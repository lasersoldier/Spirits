class_name DeckCardStrip
extends Control

signal card_clicked(card_id: String)
# signal card_removed(card_id: String) # 暂时没用到

var card_id: String = ""
var card_data: Dictionary = {}
var count: int = 0

@onready var background_panel: Panel = %BackgroundPanel
@onready var art_texture: TextureRect = %ArtTexture
@onready var cost_label: Label = %CostLabel
@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel

var highlight_tween: Tween = null

func _ready():
	custom_minimum_size = Vector2(280, 50)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 设置缩放中心点（延迟到布局完成后）
	call_deferred("_update_pivot_offset")
	# 初始刷新
	_refresh()

func _update_pivot_offset():
	# 在布局完成后设置缩放中心点
	pivot_offset = size / 2.0

func set_card_data(card_id_param: String, card_data_param: Dictionary, count_param: int):
	card_id = card_id_param
	card_data = card_data_param
	count = count_param
	_refresh()

func _refresh():
	if not is_inside_tree():
		return
	
	# 更新费用
	if cost_label:
		var energy_cost = card_data.get("energy_cost", 0)
		cost_label.text = str(int(energy_cost))
	
	# 更新名称
	if name_label:
		var card_name = card_data.get("name", card_id)
		name_label.text = card_name
	
	# 更新数量 - 按照你的要求：x1/x2 等
	if count_label:
		count_label.text = "x" + str(count)
	
	# 更新背景样式
	_update_background_style()
	
	# 更新插画
	_update_art_texture()

func _update_background_style():
	if not background_panel:
		return
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	var rarity = card_data.get("rarity", "common")
	match rarity:
		"rare":
			style.border_color = Color(0.98, 0.84, 0.3, 1.0) # 金色
		"epic":
			style.border_color = Color(0.8, 0.4, 1.0, 1.0) # 紫色
		"legendary":
			style.border_color = Color(1.0, 0.6, 0.1, 1.0) # 橙色
		_:
			style.border_color = Color(0.5, 0.5, 0.55, 1.0) # 灰色
	
	background_panel.add_theme_stylebox_override("panel", style)

func _update_art_texture():
	if not art_texture: return
	art_texture.modulate = Color(1, 1, 1, 0.15) 

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(card_id)

func _on_mouse_entered():
	# 更新缩放中心点（确保在布局变化后仍然正确）
	_update_pivot_offset()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.01, 1.01), 0.1)
	modulate = Color(1.1, 1.1, 1.1, 1.0)

func _on_mouse_exited():
	# 更新缩放中心点
	_update_pivot_offset()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	if not _is_selected:
		modulate = Color.WHITE
	else:
		modulate = Color(1.3, 1.3, 1.0, 1.0)

var _is_selected = false
func set_selected(selected: bool):
	_is_selected = selected
	if selected:
		modulate = Color(1.3, 1.3, 1.0, 1.0)
	else:
		modulate = Color.WHITE
