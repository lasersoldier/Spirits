class_name DevTools
extends Control

# UI节点引用
@onready var gold_input: LineEdit = $MainContainer/VBoxContainer/GoldContainer/GoldInput
@onready var gold_set_button: Button = $MainContainer/VBoxContainer/GoldContainer/GoldSetButton
@onready var shards_input: LineEdit = $MainContainer/VBoxContainer/ShardsContainer/ShardsInput
@onready var shards_set_button: Button = $MainContainer/VBoxContainer/ShardsContainer/ShardsSetButton
@onready var init_all_cards_button: Button = $MainContainer/VBoxContainer/InitCardsContainer/InitAllCardsButton
@onready var clear_collection_button: Button = $MainContainer/VBoxContainer/InitCardsContainer/ClearCollectionButton
@onready var status_label: Label = $MainContainer/VBoxContainer/StatusLabel
@onready var current_data_label: Label = $MainContainer/VBoxContainer/CurrentDataLabel
@onready var back_button: Button = $TopBar/BackButton

# 系统引用
var player_data_manager: PlayerDataManager
var player_collection: PlayerCollection
var card_library: CardLibrary

func _ready():
	# 初始化系统
	player_data_manager = PlayerDataManager.new()
	player_collection = PlayerCollection.new(player_data_manager)
	card_library = CardLibrary.new()
	
	# 连接信号
	if gold_set_button:
		gold_set_button.pressed.connect(_on_gold_set_pressed)
	if shards_set_button:
		shards_set_button.pressed.connect(_on_shards_set_pressed)
	if init_all_cards_button:
		init_all_cards_button.pressed.connect(_on_init_all_cards_pressed)
	if clear_collection_button:
		clear_collection_button.pressed.connect(_on_clear_collection_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# 启用ESC键处理
	set_process_unhandled_input(true)
	
	# 更新显示
	_update_display()

# 更新显示
func _update_display():
	_update_current_data()
	if gold_input:
		gold_input.text = str(player_data_manager.get_gold())
	if shards_input:
		shards_input.text = str(player_data_manager.get_shards())

# 更新当前数据显示
func _update_current_data():
	if current_data_label:
		var gold = player_data_manager.get_gold()
		var shards = player_data_manager.get_shards()
		var card_count = player_collection.get_total_count()
		current_data_label.text = "当前数据 - 金币: %d | 碎片: %d | 卡牌总数: %d" % [gold, shards, card_count]

# 设置金币
func _on_gold_set_pressed():
	if not gold_input:
		return
	
	var gold_text = gold_input.text.strip_edges()
	if gold_text.is_empty():
		_show_status("请输入金币数量", false)
		return
	
	var gold = gold_text.to_int()
	if gold < 0:
		_show_status("金币数量不能为负数", false)
		return
	
	player_data_manager.set_gold(gold)
	player_data_manager.save_data()
	_update_display()
	_show_status("金币已设置为: " + str(gold), true)

# 设置碎片
func _on_shards_set_pressed():
	if not shards_input:
		return
	
	var shards_text = shards_input.text.strip_edges()
	if shards_text.is_empty():
		_show_status("请输入碎片数量", false)
		return
	
	var shards = shards_text.to_int()
	if shards < 0:
		_show_status("碎片数量不能为负数", false)
		return
	
	player_data_manager.set_shards(shards)
	player_data_manager.save_data()
	_update_display()
	_show_status("碎片已设置为: " + str(shards), true)

# 初始化所有卡牌（各4张）
func _on_init_all_cards_pressed():
	var all_card_ids = card_library.get_all_card_ids()
	var count = 0
	
	for card_id in all_card_ids:
		player_collection.set_card_count(card_id, 4)
		count += 1
	
	player_data_manager.save_data()
	_update_display()
	_show_status("已初始化 " + str(count) + " 种卡牌，每种4张", true)

# 清空收藏
func _on_clear_collection_pressed():
	player_data_manager.set_collection({})
	player_data_manager.save_data()
	_update_display()
	_show_status("已清空所有卡牌收藏", true)

# 显示状态消息
func _show_status(message: String, is_success: bool = true):
	if status_label:
		status_label.text = message
		if is_success:
			status_label.modulate = Color.GREEN
		else:
			status_label.modulate = Color.RED
		
		# 3秒后清除消息
		await get_tree().create_timer(3.0).timeout
		if status_label:
			status_label.text = ""
			status_label.modulate = Color.WHITE

# 返回主菜单
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ESC键处理
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not event.echo:
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

