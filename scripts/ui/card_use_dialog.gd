class_name CardUseDialog
extends AcceptDialog

# 卡牌使用对话框
var selected_card: Card
var selected_sprite: Sprite
var selected_target: Variant

# 精灵选择列表
var sprite_list: ItemList
var target_list: ItemList

# 租用确认
var rent_confirmation: CheckBox

signal card_use_confirmed(card: Card, sprite: Sprite, target: Variant, rent: bool)

func _ready():
	_create_ui()

func _create_ui():
	# 创建对话框内容
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# 精灵选择
	var sprite_label = Label.new()
	sprite_label.text = "选择精灵:"
	vbox.add_child(sprite_label)
	
	sprite_list = ItemList.new()
	sprite_list.custom_minimum_size = Vector2(200, 100)
	vbox.add_child(sprite_list)
	
	# 目标选择
	var target_label = Label.new()
	target_label.text = "选择目标:"
	vbox.add_child(target_label)
	
	target_list = ItemList.new()
	target_list.custom_minimum_size = Vector2(200, 100)
	vbox.add_child(target_list)
	
	# 租用确认
	rent_confirmation = CheckBox.new()
	rent_confirmation.text = "租用其他玩家的精灵"
	vbox.add_child(rent_confirmation)

# 显示对话框
func show_dialog(card: Card, available_sprites: Array[Sprite], available_targets: Array):
	selected_card = card
	popup_centered()
	
	# 填充精灵列表
	sprite_list.clear()
	for sprite in available_sprites:
		sprite_list.add_item(sprite.sprite_name + " (" + sprite.attribute + ")")
	
	# 填充目标列表
	target_list.clear()
	for target in available_targets:
		if target is Sprite:
			target_list.add_item((target as Sprite).sprite_name)
		elif target is Vector2i:
			target_list.add_item("位置: " + str(target))

func _on_confirmed():
	var sprite_idx = sprite_list.get_selected_items()
	var target_idx = target_list.get_selected_items()
	
	if sprite_idx.is_empty() or target_idx.is_empty():
		return
	
	# 获取选中的精灵和目标（需要从外部传入完整列表）
	# 这里简化处理
	card_use_confirmed.emit(selected_card, selected_sprite, selected_target, rent_confirmation.button_pressed)

