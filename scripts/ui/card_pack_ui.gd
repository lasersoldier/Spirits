class_name CardPackUI
extends Control

# UI节点引用
@onready var particle_bg: ParticleBackground = $ParticleBackground
@onready var pack_stage: Control = $PackStage
@onready var pack_icon: Control = $PackStage/PackIcon
@onready var rune_container: Control = $PackStage/RuneContainer
@onready var opening_animation: Control = $PackStage/OpeningAnimation
@onready var flash_rect: ColorRect = $PackStage/OpeningAnimation/FlashRect
@onready var card_display_area: Control = $CardDisplayArea
@onready var open_another_button: Control = $OpenAnotherButton
@onready var back_button: Button = $TopBar/BackButton
@onready var status_label: Label = $TopBar/StatusLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var shards_label: Label = $TopBar/ShardsLabel

# 系统引用
var player_data_manager: PlayerDataManager
var player_collection: PlayerCollection
var card_library: CardLibrary
var pack_opener: CardPackOpener

# 状态
var is_opening: bool = false
var opened_cards: Array[Dictionary] = []
var card_ui_nodes: Array[Control] = []

# 卡牌场景
const CARD_CARD_SCENE = preload("res://scenes/ui/card_face.tscn")

# 符文节点
var rune_nodes: Array[Control] = []

func _ready():
	# 初始化系统
	player_data_manager = PlayerDataManager.new()
	player_collection = PlayerCollection.new(player_data_manager)
	card_library = CardLibrary.new()
	pack_opener = CardPackOpener.new(card_library, player_collection, player_data_manager)
	
	# 连接信号
	if pack_icon:
		pack_icon.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保可以接收鼠标事件
		pack_icon.gui_input.connect(_on_pack_icon_input)
		pack_icon.mouse_entered.connect(_on_pack_icon_mouse_entered)
		pack_icon.mouse_exited.connect(_on_pack_icon_mouse_exited)
		print("CardPackUI: PackIcon信号已连接")
	if open_another_button:
		open_another_button.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保可以接收鼠标事件
		open_another_button.gui_input.connect(_on_open_another_input)
		open_another_button.mouse_entered.connect(_on_open_another_mouse_entered)
		open_another_button.mouse_exited.connect(_on_open_another_mouse_exited)
		print("CardPackUI: OpenAnotherButton信号已连接")
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# 启用ESC键处理
	set_process_unhandled_input(true)
	
	# 初始化UI状态
	_update_gold_display()
	_show_pack_stage()
	_setup_runes()
	card_display_area.visible = false
	open_another_button.visible = false

# 设置符文环绕
func _setup_runes():
	if not rune_container:
		return
	
	# 创建8个符文，围绕卡包旋转
	var rune_count = 8
	var radius = 120.0
	
	for i in range(rune_count):
		var rune = ColorRect.new()
		rune.custom_minimum_size = Vector2(24, 24)
		rune.color = Color(1.0, 0.65, 0.0, 0.6)
		
		# 计算位置（圆形分布）
		var angle = (i * 2.0 * PI) / rune_count
		var pos = Vector2(cos(angle), sin(angle)) * radius
		rune.position = pos - Vector2(12, 12)
		
		rune_container.add_child(rune)
		rune_nodes.append(rune)
		
		# 创建旋转动画
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(rune, "rotation_degrees", 360, 3.0 + i * 0.2)
		tween.tween_property(rune, "modulate:a", 0.3, 1.0)
		tween.tween_property(rune, "modulate:a", 0.8, 1.0)

# 显示卡包阶段
func _show_pack_stage():
	pack_stage.visible = true
	opening_animation.visible = false
	card_display_area.visible = false
	open_another_button.visible = false
	
	# 重置卡包图标状态
	if pack_icon:
		pack_icon.scale = Vector2(1.0, 1.0)
		pack_icon.modulate = Color.WHITE

# 卡包图标鼠标进入
func _on_pack_icon_mouse_entered():
	print("CardPackUI: 鼠标进入PackIcon")
	if pack_icon and not is_opening:
		var tween = create_tween()
		tween.tween_property(pack_icon, "scale", Vector2(1.1, 1.1), 0.2)
		# 添加发光效果
		pack_icon.modulate = Color(1.2, 1.1, 1.0, 1.0)

# 卡包图标鼠标离开
func _on_pack_icon_mouse_exited():
	if pack_icon and not is_opening:
		var tween = create_tween()
		tween.tween_property(pack_icon, "scale", Vector2(1.0, 1.0), 0.2)
		pack_icon.modulate = Color.WHITE

# 卡包图标输入
func _on_pack_icon_input(event: InputEvent):
	print("CardPackUI: 收到PackIcon输入事件: ", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("CardPackUI: 左键点击PackIcon")
		if not is_opening and opened_cards.is_empty():
			print("CardPackUI: 开始开包")
			_open_pack()
		else:
			print("CardPackUI: 无法开包 - is_opening: ", is_opening, ", opened_cards.size(): ", opened_cards.size())

# 更新金币显示
func _update_gold_display():
	if gold_label:
		var gold = player_data_manager.get_gold()
		gold_label.text = "金币: " + str(gold)
	if shards_label:
		var shards = player_data_manager.get_shards()
		shards_label.text = "碎片: " + str(shards)

# 开启卡包
func _open_pack():
	if is_opening:
		return
	
	# 检查金币是否足够
	if player_data_manager.get_gold() < 200:
		if status_label:
			status_label.text = "金币不足！需要 200 金币"
		# ToastMessage.show(self, "金币不足！需要 200 金币", 2.0)  # 暂时使用status_label
		return
	
	is_opening = true
	
	# 先执行开包逻辑获取数据（在动画之前）
	var result = pack_opener.open_pack("standard")
	_update_gold_display()
	
	# 检查开包结果
	if not result.get("success", false):
		if status_label:
			status_label.text = result.get("message", "开包失败")
		is_opening = false
		return
	
	# 获取开出的卡牌和碎片
	opened_cards = result.get("cards", [])
	var shards_gained = result.get("shards_gained", 0)
	
	print("CardPackUI: 开包成功，获得 ", opened_cards.size(), " 张卡牌")
	for i in range(opened_cards.size()):
		var card_id = opened_cards[i].get("id", opened_cards[i].get("card_id", "unknown"))
		print("CardPackUI: 卡牌 ", i, ": ", card_id)
	
	# 第一步：卡包震动
	await _shake_pack()
	
	# 第二步：白光闪过
	await _flash_screen()
	
	# 第三步：卡包消失，卡牌飞出（此时opened_cards已经有数据了）
	pack_stage.visible = false
	await _spawn_cards()
	
	# 显示状态信息
	await _reveal_cards(shards_gained)
	
	is_opening = false

# 卡包震动动画
func _shake_pack() -> void:
	if not pack_icon:
		await get_tree().create_timer(0.5).timeout
		return
	
	var original_pos = pack_icon.position
	var shake_intensity = 15.0
	var shake_duration = 0.5
	
	for i in range(10):
		var offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		pack_icon.position = original_pos + offset
		await get_tree().create_timer(shake_duration / 10.0).timeout
	
	pack_icon.position = original_pos

# 白光闪过
func _flash_screen() -> void:
	if not flash_rect:
		await get_tree().create_timer(0.3).timeout
		return
	
	opening_animation.visible = true
	flash_rect.modulate.a = 0.0
	
	# 快速闪白
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 1.0, 0.1)
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	opening_animation.visible = false

# 生成卡牌（扇形飞出）
func _spawn_cards() -> void:
	card_display_area.visible = true
	_clear_card_display()
	
	print("CardPackUI: _spawn_cards 开始，opened_cards.size()=", opened_cards.size())
	
	# 使用实际开出的卡牌数量
	var card_count = opened_cards.size()
	if card_count == 0:
		print("CardPackUI: 警告！没有卡牌数据，使用默认数量5")
		card_count = 5
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 2 + 80  # 向下移动，避免与碎片信息重叠
	var radius = 400.0  # 增加半径，让卡牌更分散
	var spread_angle = PI * 1.2  # 增加扇形角度，让卡牌更分散
	var card_width = 190.0
	var card_height = 300.0
	
	for i in range(card_count):
		# 创建卡牌背面（占位）
		var card_back = Control.new()
		card_back.custom_minimum_size = Vector2(card_width, card_height)
		card_back.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保可以接收鼠标事件
		
		# 计算扇形位置（从中心向两侧展开）
		var t = i / float(max(1, card_count - 1))  # 0.0 到 1.0，避免除零
		var angle = (t - 0.5) * spread_angle - PI / 2  # 从上方开始，向两侧展开
		var pos = Vector2(cos(angle), sin(angle)) * radius
		
		# 设置位置（以卡牌中心为基准）
		card_back.position = Vector2(center_x, center_y) + pos - Vector2(card_width / 2, card_height / 2)
		
		# 添加轻微旋转，让扇形更自然
		card_back.rotation = (t - 0.5) * 0.25  # 轻微旋转
		
		# 设置卡牌背面样式
		var panel = Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.15, 0.1, 1.0)
		style.border_color = Color(0.8, 0.6, 0.3, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		panel.add_theme_stylebox_override("panel", style)
		card_back.add_child(panel)
		
		# 添加"卡牌背面"标签
		var label = Label.new()
		label.text = "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
		label.add_theme_font_size_override("font_size", 80)
		label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
		card_back.add_child(label)
		
		card_display_area.add_child(card_back)
		card_ui_nodes.append(card_back)
		
		# 飞出动画
		card_back.modulate.a = 0.0
		card_back.scale = Vector2(0.3, 0.3)
		var tween = create_tween()
		tween.tween_interval(i * 0.05)
		tween.parallel().tween_property(card_back, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(card_back, "scale", Vector2(1.0, 1.0), 0.3)
		
		# 设置初始状态
		card_back.set("is_flipped", false)
		card_back.set("card_index", i)  # 保存索引
		
		# 连接点击事件（未翻转的卡牌背面只需要点击翻转，不需要悬停效果）
		card_back.gui_input.connect(_on_card_click.bind(card_back, i))
	
	await get_tree().create_timer(0.5).timeout

# 连接卡牌悬停事件（用于翻转后的卡牌）
func _connect_card_hover_events(card_face: Control):
	if not is_instance_valid(card_face):
		return
	
	# 确保 CardFace 能接收鼠标事件
	card_face.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 等待一帧，确保 CardFace 完全初始化
	await get_tree().process_frame
	
	# 确保 CardFace 的子节点不拦截鼠标事件（让事件传递到 CardFace）
	# 这样 CardFace 的 mouse_entered/mouse_exited 才能正常工作，从而显示预览
	_set_card_face_children_mouse_filter(card_face, Control.MOUSE_FILTER_IGNORE)
	
	print("CardPackUI: 已为翻转后的卡牌启用预览功能，mouse_filter=", card_face.mouse_filter)

# 递归设置 CardFace 子节点的 mouse_filter
func _set_card_face_children_mouse_filter(node: Node, filter_mode: int):
	if node is Control:
		# 检查是否是 CardFace 本身（通过脚本路径检查）
		if node.get_script():
			var script_path = node.get_script().resource_path
			if script_path and "card_face.gd" in script_path:
				# 这是 CardFace，保持 STOP，不处理子节点
				return
		
		# 子节点设置为 IGNORE，让事件传递到 CardFace
		node.mouse_filter = filter_mode
	
	for child in node.get_children():
		_set_card_face_children_mouse_filter(child, filter_mode)

# 卡牌点击（翻转）
func _on_card_click(event: InputEvent, card: Control, index: int):
	print("CardPackUI: 收到卡牌点击事件，index=", index, " event=", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var is_flipped = card.get("is_flipped")
		print("CardPackUI: is_flipped=", is_flipped, " opened_cards.size()=", opened_cards.size())
		if is_flipped == true:
			print("CardPackUI: 卡牌已翻转，忽略点击")
			return
		
		if index >= opened_cards.size():
			print("CardPackUI: 错误！索引超出范围: ", index, " >= ", opened_cards.size())
			return
		
		print("CardPackUI: 点击卡牌 ", index, " 准备翻转，卡牌数据: ", opened_cards[index])
		card.set("is_flipped", true)
		_flip_card(card, index)
	else:
		print("CardPackUI: 不是左键点击事件")

# 翻转卡牌
func _flip_card(card_back: Control, index: int):
	if index >= opened_cards.size():
		print("CardPackUI: 卡牌索引超出范围 ", index, " >= ", opened_cards.size())
		return
	
	var card_data = opened_cards[index]
	var card_id = card_data.get("id", card_data.get("card_id", "unknown"))
	print("CardPackUI: 翻转卡牌 ", index, " 数据ID: ", card_id, " 完整数据: ", card_data)
	
	# 保存位置和旋转
	var saved_position = card_back.position
	var saved_rotation = card_back.rotation
	var saved_z_index = card_back.z_index
	
	# 翻转动画（水平缩放）
	var tween = create_tween()
	tween.tween_property(card_back, "scale:x", 0.0, 0.2)
	await tween.finished
	
	# 替换为卡牌正面
	card_back.queue_free()
	card_ui_nodes[index] = null
	
	var card_face = CARD_CARD_SCENE.instantiate()
	
	# 先添加到场景树，确保节点已初始化
	card_display_area.add_child(card_face)
	
	# 设置卡牌尺寸和位置（与背面一致）
	card_face.custom_minimum_size = Vector2(190, 300)
	# 使用锚点模式，但设置固定偏移量来限制尺寸
	card_face.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_face.offset_left = 0
	card_face.offset_top = 0
	card_face.offset_right = 190
	card_face.offset_bottom = 300
	
	card_face.position = saved_position
	card_face.rotation = saved_rotation
	card_face.z_index = saved_z_index
	card_face.scale = Vector2(0.0, 1.0)
	card_face.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 等待一帧，确保所有@onready变量都已初始化
	await get_tree().process_frame
	
	# 现在设置卡牌数据（此时所有节点引用都已准备好）
	card_face.set_card_data(card_data)
	
	card_ui_nodes[index] = card_face
	
	print("CardPackUI: 卡牌正面已创建，位置: ", saved_position, " 尺寸: ", card_face.size, " 卡牌名称: ", card_data.get("name", "unknown"))
	
	# 为翻转后的卡牌连接悬停事件（延迟执行，确保 CardFace 已完全初始化）
	call_deferred("_connect_card_hover_events", card_face)
	
	# 展开动画
	tween = create_tween()
	tween.tween_property(card_face, "scale:x", 1.0, 0.2)
	await tween.finished
	# 动画完成后，确保 scale 完全恢复为 (1.0, 1.0)
	card_face.scale = Vector2(1.0, 1.0)
	# 设置缩放中心点
	card_face.pivot_offset = card_face.size / 2.0
	
	# 元素粒子爆发效果（根据卡牌属性）
	var attributes = card_data.get("attributes", [])
	if attributes.size() > 0:
		_create_element_burst(card_face, attributes)

# 元素粒子爆发
func _create_element_burst(card: Control, attributes: Array):
	if attributes.is_empty():
		return
	
	# 根据第一个属性确定颜色
	var color = Color(1.0, 0.5, 0.0)  # 默认火
	match attributes[0]:
		"water":
			color = Color(0.0, 0.5, 1.0)
		"wind":
			color = Color(0.5, 0.8, 1.0)
		"rock":
			color = Color(0.75, 0.75, 0.75)
	
	# 创建简单的粒子效果（可以用更复杂的粒子系统替代）
	for i in range(20):
		var particle = ColorRect.new()
		particle.custom_minimum_size = Vector2(4, 4)
		particle.color = color
		particle.position = card.position + Vector2(95, 150)
		card_display_area.add_child(particle)
		
		var angle = (i / 20.0) * PI * 2
		var distance = 100.0
		var target_pos = particle.position + Vector2(cos(angle), sin(angle)) * distance
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "position", target_pos, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

# 揭示卡牌（显示数据）
func _reveal_cards(shards_gained: int):
	# 卡牌已经在_spawn_cards中创建，这里只需要更新状态
	open_another_button.visible = true
	
	if status_label:
		var status_text = "已开出 " + str(opened_cards.size()) + " 张卡牌！"
		if shards_gained > 0:
			status_text += " 获得 " + str(shards_gained) + " 碎片！"
		status_label.text = status_text

# 清空卡牌显示
func _clear_card_display():
	if card_display_area:
		for child in card_display_area.get_children():
			child.queue_free()
	card_ui_nodes.clear()

# 再开一包按钮
func _on_open_another_input(event: InputEvent):
	print("CardPackUI: 收到OpenAnotherButton输入事件: ", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("CardPackUI: 点击再开一包按钮")
		_on_open_another_pressed()

func _on_open_another_mouse_entered():
	if open_another_button:
		var tween = create_tween()
		tween.tween_property(open_another_button, "scale", Vector2(1.1, 1.1), 0.2)

func _on_open_another_mouse_exited():
	if open_another_button:
		var tween = create_tween()
		tween.tween_property(open_another_button, "scale", Vector2(1.0, 1.0), 0.2)

func _on_open_another_pressed():
	opened_cards.clear()
	_clear_card_display()
	_update_gold_display()
	_show_pack_stage()
	if status_label:
		status_label.text = ""

# 返回主菜单
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ESC键处理
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not event.echo:
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()
