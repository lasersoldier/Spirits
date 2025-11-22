class_name SpriteInfoCard
extends Control

# 资料卡UI：显示精灵的基本信息

# UI节点
var sprite_name_label: Label
var attribute_label: Label
var description_label: Label  # 描述标签
var hp_label: Label
var hp_bar: ProgressBar
var movement_label: Label
var attack_range_label: Label
var vision_range_label: Label
var position_label: Label
var player_label: Label
var close_button: Button

# 当前显示的精灵
var current_sprite: Sprite = null

# 跟踪的精灵（用于检测鼠标距离）
var tracked_sprite: Sprite = null

# 鼠标距离检测阈值（屏幕像素）
var mouse_distance_threshold: float = 200.0

# 游戏管理器引用（用于获取地图和精灵位置）
var game_manager: GameManager = null

# 资料卡面板
var info_panel: Panel

func _ready():
	# 设置Control为全屏（用于检测点击和居中）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 默认忽略，只在显示时处理
	
	# 创建资料卡面板（居中显示）
	info_panel = Panel.new()
	var card_size = Vector2(300, 480)  # 增加高度以容纳施法范围
	info_panel.custom_minimum_size = card_size
	info_panel.size = card_size
	
	# 设置面板居中（使用anchor）
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	info_panel.offset_left = -card_size.x / 2
	info_panel.offset_top = -card_size.y / 2
	info_panel.offset_right = card_size.x / 2
	info_panel.offset_bottom = card_size.y / 2
	
	# 设置背景
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	info_panel.add_theme_stylebox_override("panel", style_box)
	
	add_child(info_panel)
	
	# 创建标题
	var title_label = Label.new()
	title_label.text = "精灵信息"
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(280, 30)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_panel.add_child(title_label)
	
	# 创建关闭按钮
	close_button = Button.new()
	close_button.text = "×"
	close_button.position = Vector2(270, 5)
	close_button.size = Vector2(25, 25)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_on_close_button_pressed)
	info_panel.add_child(close_button)
	
	# 创建精灵名称标签
	sprite_name_label = Label.new()
	sprite_name_label.text = "未知"
	sprite_name_label.position = Vector2(10, 50)
	sprite_name_label.size = Vector2(280, 30)
	sprite_name_label.add_theme_font_size_override("font_size", 18)
	sprite_name_label.add_theme_color_override("font_color", Color.WHITE)
	sprite_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_panel.add_child(sprite_name_label)
	
	# 创建属性标签
	attribute_label = Label.new()
	attribute_label.text = "属性: 未知"
	attribute_label.position = Vector2(10, 85)
	attribute_label.size = Vector2(280, 25)
	attribute_label.add_theme_font_size_override("font_size", 16)
	attribute_label.add_theme_color_override("font_color", Color.WHITE)
	attribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_panel.add_child(attribute_label)
	
	# 创建描述标签
	description_label = Label.new()
	description_label.text = "暂无描述"
	description_label.position = Vector2(10, 110)
	description_label.size = Vector2(280, 35)
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))  # 稍浅的白色
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_panel.add_child(description_label)
	
	# 创建血量标签
	hp_label = Label.new()
	hp_label.text = "血量: 0 / 0"
	hp_label.position = Vector2(10, 150)
	hp_label.size = Vector2(280, 25)
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(hp_label)
	
	# 创建血量进度条
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(10, 180)
	hp_bar.size = Vector2(280, 20)
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.show_percentage = false
	info_panel.add_child(hp_bar)
	
	# 创建移动力标签
	movement_label = Label.new()
	movement_label.text = "移动范围: 0"
	movement_label.position = Vector2(10, 210)
	movement_label.size = Vector2(280, 25)
	movement_label.add_theme_font_size_override("font_size", 16)
	movement_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(movement_label)
	
	# 创建攻击距离标签
	attack_range_label = Label.new()
	attack_range_label.text = "攻击距离: 0"
	attack_range_label.position = Vector2(10, 240)
	attack_range_label.size = Vector2(280, 25)
	attack_range_label.add_theme_font_size_override("font_size", 16)
	attack_range_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(attack_range_label)
	
	# 创建施法范围标签
	var cast_range_label = Label.new()
	cast_range_label.name = "CastRangeLabel"
	cast_range_label.text = "施法范围: 0"
	cast_range_label.position = Vector2(10, 270)
	cast_range_label.size = Vector2(280, 25)
	cast_range_label.add_theme_font_size_override("font_size", 16)
	cast_range_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))  # 浅蓝色，区分于攻击距离
	info_panel.add_child(cast_range_label)
	
	# 创建视野范围标签
	vision_range_label = Label.new()
	vision_range_label.text = "视野范围: 0"
	vision_range_label.position = Vector2(10, 300)
	vision_range_label.size = Vector2(280, 25)
	vision_range_label.add_theme_font_size_override("font_size", 16)
	vision_range_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(vision_range_label)
	
	# 创建位置标签
	position_label = Label.new()
	position_label.text = "位置: (0, 0)"
	position_label.position = Vector2(10, 330)
	position_label.size = Vector2(280, 25)
	position_label.add_theme_font_size_override("font_size", 16)
	position_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(position_label)
	
	# 创建玩家标签
	player_label = Label.new()
	player_label.text = "玩家: 0"
	player_label.position = Vector2(10, 360)
	player_label.size = Vector2(280, 25)
	player_label.add_theme_font_size_override("font_size", 16)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	info_panel.add_child(player_label)
	
	# 设置处理输入（用于ESC键关闭）
	set_process_input(true)
	
	# 设置处理（用于鼠标距离检测）
	set_process(true)
	
	# 初始隐藏
	visible = false
	info_panel.visible = false
	
	print("精灵资料卡初始化完成")

# 显示精灵信息
func show_sprite_info(sprite: Sprite):
	if not sprite:
		return
	
	current_sprite = sprite
	tracked_sprite = sprite  # 设置跟踪的精灵（用于距离检测）
	z_index = 1024
	
	visible = true
	info_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  # 允许鼠标事件
	
	_update_info()
	print("显示精灵资料卡: ", sprite.sprite_name, " 血量: ", sprite.current_hp, "/", sprite.max_hp)

# 隐藏资料卡
func hide_info():
	current_sprite = null
	tracked_sprite = null
	visible = false
	info_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标事件
	print("隐藏精灵资料卡")

# 更新信息
func _update_info():
	if not current_sprite:
		print("错误: 更新信息时没有当前精灵")
		return
	
	if not sprite_name_label:
		print("错误: UI节点未初始化")
		return
	
	print("更新精灵信息: ", current_sprite.sprite_name)
	
	# 更新名称
	if sprite_name_label:
		sprite_name_label.text = current_sprite.sprite_name if current_sprite.sprite_name else "未知"
		print("  名称: ", sprite_name_label.text)
	
	# 更新属性
	if attribute_label:
		var attribute_name = _get_attribute_name(current_sprite.attribute)
		var attribute_color = _get_attribute_color(current_sprite.attribute)
		attribute_label.text = "属性: " + attribute_name
		attribute_label.modulate = attribute_color
		print("  属性: ", attribute_name)
	
	# 更新描述
	if description_label:
		var desc = current_sprite.description
		if desc.is_empty():
			desc = "暂无描述"
		description_label.text = desc
		print("  描述: ", desc)
	
	# 更新血量
	if hp_label:
		hp_label.text = "血量: %d / %d" % [current_sprite.current_hp, current_sprite.max_hp]
		print("  血量: ", hp_label.text)
	if hp_bar:
		hp_bar.max_value = current_sprite.max_hp
		hp_bar.value = current_sprite.current_hp
		print("  血量条: ", hp_bar.value, "/", hp_bar.max_value)
		
		# 根据血量设置进度条颜色
		if current_sprite.current_hp <= current_sprite.max_hp * 0.3:
			hp_bar.modulate = Color.RED
		elif current_sprite.current_hp <= current_sprite.max_hp * 0.6:
			hp_bar.modulate = Color.YELLOW
		else:
			hp_bar.modulate = Color.GREEN
	
	# 更新移动力（显示有效移动范围，考虑状态效果加成）
	if movement_label:
		# 获取有效移动范围（考虑状态效果加成）
		var effective_movement = current_sprite.base_movement
		if game_manager and game_manager.game_map and game_manager.terrain_manager:
			effective_movement = current_sprite.get_effective_movement_range(game_manager.game_map, game_manager.terrain_manager)
		
		# 如果有效移动范围与基础移动范围不同，显示更多信息
		if effective_movement != current_sprite.base_movement:
			movement_label.text = "移动范围: %d (基础: %d)" % [effective_movement, current_sprite.base_movement]
		else:
			movement_label.text = "移动范围: %d" % effective_movement
		print("  移动力: ", movement_label.text)
	
	# 更新攻击距离
	if attack_range_label:
		attack_range_label.text = "攻击距离: %d" % current_sprite.attack_range
		print("  攻击距离: ", attack_range_label.text)
	
	# 更新施法范围
	var cast_range_label = info_panel.get_node_or_null("CastRangeLabel") as Label
	if cast_range_label:
		cast_range_label.text = "施法范围: %d" % current_sprite.cast_range
		print("  施法范围: ", cast_range_label.text)
	
	# 更新视野范围
	if vision_range_label:
		vision_range_label.text = "视野范围: %d" % current_sprite.vision_range
		print("  视野范围: ", vision_range_label.text)
	
	# 更新位置
	if position_label:
		position_label.text = "位置: (%d, %d)" % [current_sprite.hex_position.x, current_sprite.hex_position.y]
		print("  位置: ", position_label.text)
	
	# 更新玩家
	if player_label:
		var player_text = "玩家: %d" % current_sprite.owner_player_id
		if current_sprite.owner_player_id == 0:
			player_text += " (己方)"
		else:
			player_text += " (敌方)"
		player_label.text = player_text
		print("  玩家: ", player_label.text)

# 获取属性名称
func _get_attribute_name(attr: String) -> String:
	match attr:
		"fire":
			return "火"
		"wind":
			return "风"
		"water":
			return "水"
		"rock":
			return "岩"
		_:
			return "未知"

# 获取属性颜色
func _get_attribute_color(attr: String) -> Color:
	match attr:
		"fire":
			return Color(1.0, 0.5, 0.0)  # 橙红色
		"wind":
			return Color(0.5, 0.8, 1.0)  # 浅蓝色
		"water":
			return Color(0.0, 0.5, 1.0)  # 蓝色
		"rock":
			return Color(0.6, 0.6, 0.6)  # 灰色
		_:
			return Color.WHITE

# 关闭按钮点击
func _on_close_button_pressed():
	hide_info()

# 处理输入（ESC键关闭、点击外部关闭）
func _input(event: InputEvent):
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_info()
			get_viewport().set_input_as_handled()
	
	# 点击外部关闭（点击在info_panel外部）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var panel_rect = info_panel.get_global_rect()
		if not panel_rect.has_point(mouse_pos):
			# 点击在外部，关闭资料卡
			hide_info()
			get_viewport().set_input_as_handled()

# 处理（检测鼠标距离）
func _process(_delta):
	if not visible or not tracked_sprite or not game_manager:
		return
	
	# 检查精灵是否还存活
	if not tracked_sprite.is_alive:
		hide_info()
		return
	
	# 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 获取精灵在屏幕上的位置
	var sprite_screen_pos = _get_sprite_screen_position(tracked_sprite)
	if sprite_screen_pos == Vector2(-1, -1):
		# 无法获取精灵屏幕位置，隐藏资料卡
		hide_info()
		return
	
	# 计算鼠标与精灵的距离
	var distance = mouse_pos.distance_to(sprite_screen_pos)
	
	# 如果距离超过阈值，隐藏资料卡
	if distance > mouse_distance_threshold:
		hide_info()
		print("鼠标距离精灵过远，隐藏资料卡（距离: ", distance, "，阈值: ", mouse_distance_threshold, "）")

# 获取精灵在屏幕上的位置
func _get_sprite_screen_position(sprite: Sprite) -> Vector2:
	if not game_manager or not game_manager.game_map:
		return Vector2(-1, -1)
	
	# 获取MainUI节点（通过父节点查找）
	var main_ui = get_parent()
	if not main_ui:
		return Vector2(-1, -1)
	
	# 获取MapViewport
	var map_viewport = main_ui.get_node_or_null("MapViewport") as SubViewportContainer
	if not map_viewport:
		return Vector2(-1, -1)
	
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return Vector2(-1, -1)
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return Vector2(-1, -1)
	
	# 将精灵的世界坐标转换为屏幕坐标
	var hex_size = game_manager.game_map.hex_size
	var map_height = game_manager.game_map.map_height
	var map_width = game_manager.game_map.map_width
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	world_pos.y = 0.5  # 精灵高度
	
	# 将3D世界坐标转换为2D屏幕坐标
	var viewport_pos = camera.unproject_position(world_pos)
	
	# 转换为全局屏幕坐标
	var container_rect = map_viewport.get_global_rect()
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	var screen_pos: Vector2
	if map_viewport.stretch:
		var scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale_factor
		var scaled_height = viewport_size.y * scale_factor
		var offset_x = (container_size.x - scaled_width) / 2.0
		var offset_y = (container_size.y - scaled_height) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x * scale_factor
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y * scale_factor
	else:
		var offset_x = (container_size.x - viewport_size.x) / 2.0
		var offset_y = (container_size.y - viewport_size.y) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y
	
	return screen_pos
