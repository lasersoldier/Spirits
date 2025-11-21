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
@onready var desc_label: RichTextLabel = $CardPanel/Content/VBox/Description
@onready var rarity_label: Label = $CardPanel/Content/VBox/BottomRow/RarityLabel
@onready var cost_label: Label = $CardPanel/Content/VBox/BottomRow/CostLabel
@onready var selection_highlight: ColorRect = $SelectionHighlight

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	print("CardFace _ready: 设置 mouse_filter=STOP, card_id=", card_id)
	if owned_label:
		owned_label.visible = false
	if selection_highlight:
		selection_highlight.visible = false
	_configure_description_label()
	gui_input.connect(_on_gui_input)
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
	set_owned_count(owned_count)

func _update_basic_info():
	if name_label:
		name_label.text = card.card_name
	if desc_label:
		var text := card.effect_description
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
