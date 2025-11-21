class_name CardVisual
extends Control

var card: Card
var panel: Panel
var name_label: Label
var attr_container: HBoxContainer
var desc_label: RichTextLabel
var cost_label: Label
var width: int = 120
var height: int = 200

func _ready():
panel = Panel.new()
panel.custom_minimum_size = Vector2(width, height)
panel.size = Vector2(width, height)
panel.clip_contents = true
_add_panel_style()
add_child(panel)
panel.set_anchors_preset(Control.PRESET_FULL_RECT)

name_label = Label.new()
name_label.position = Vector2(3, 3)
name_label.size = Vector2(width - 30, 22)
name_label.add_theme_font_size_override("font_size", 14)
name_label.add_theme_color_override("font_color", Color.WHITE)
name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
panel.add_child(name_label)

attr_container = HBoxContainer.new()
attr_container.position = Vector2(width - 25, 5)
panel.add_child(attr_container)

desc_label = RichTextLabel.new()
desc_label.position = Vector2(4, 28)
desc_label.size = Vector2(width - 8, height - 48)
desc_label.custom_minimum_size = desc_label.size
desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
desc_label.add_theme_font_size_override("normal_font_size", 10)
desc_label.add_theme_color_override("default_color", Color(0.88, 0.88, 0.88))
desc_label.scroll_active = false
desc_label.fit_content = true
desc_label.bbcode_enabled = false
panel.add_child(desc_label)

cost_label = Label.new()
cost_label.position = Vector2(4, height - 18)
cost_label.size = Vector2(width - 8, 16)
cost_label.add_theme_font_size_override("font_size", 12)
cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
panel.add_child(cost_label)

func set_card_data(data: Dictionary):
card = Card.new(data)
_update_display()

func set_card(card_obj: Card):
card = card_obj
_update_display()

func _update_display():
if not card:
return
name_label.text = card.card_name
desc_label.text = card.effect_description
cost_label.text = "ÄÜÁ¿: " + str(card.energy_cost)
_update_attribute_icons(card.attributes)
_update_panel_style(card.attributes)

func _update_attribute_icons(attributes: Array[String]):
for child in attr_container.get_children():
child.queue_free()
for attr in attributes:
var icon = ColorRect.new()
icon.custom_minimum_size = Vector2(10, 10)
icon.color = _get_attribute_color(attr)
attr_container.add_child(icon)

func _get_attribute_color(attr: String) -> Color:
match attr:
"fire":
return Color(1, 0.4, 0.1)
"water":
return Color(0.3, 0.5, 1)
"wind":
return Color(0.3, 0.9, 0.9)
"rock":
return Color(0.7, 0.7, 0.7)
_:
return Color.WHITE

func _add_panel_style():
var style = StyleBoxFlat.new()
style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
style.border_color = Color(0.5, 0.5, 0.7, 1)
style.border_width_left = 2
style.border_width_top = 2
style.border_width_right = 2
style.border_width_bottom = 2
style.corner_radius_bottom_left = 5
style.corner_radius_bottom_right = 5
style.corner_radius_top_left = 5
style.corner_radius_top_right = 5
panel.add_theme_stylebox_override("panel", style)

func _update_panel_style(attributes: Array[String]):
if not panel:
return
var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
if not style:
return
var color = _get_attribute_color(attributes.size() > 0 ? attributes[0] : "")
style.border_color = color
