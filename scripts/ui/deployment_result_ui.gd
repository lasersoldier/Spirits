class_name DeploymentResultUI
extends Control

# 部署结果展示界面
# 显示所有玩家选择的精灵信息

# 游戏管理器引用
var game_manager: GameManager

# 精灵资料卡引用（从MainUI获取）
var sprite_info_card: SpriteInfoCard = null

# UI节点
var main_panel: Panel
var players_container: VBoxContainer
var continue_button: Button

signal continue_pressed()

func _ready():
	_create_ui()

func _create_ui():
	# 获取屏幕尺寸（使用缩放后的尺寸，而非原始尺寸）
	var screen_size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 改为IGNORE，让子控件接收事件
	
	# 创建主面板（直接使用缩放后的值，避免二次缩放）
	var panel_width = screen_size.x * 0.7
	var panel_height = screen_size.y * 0.8
	main_panel = Panel.new()
	main_panel.size = Vector2(panel_width, panel_height)  # 不再调用scale_vec2
	main_panel.position = Vector2((screen_size.x - panel_width) / 2, (screen_size.y - panel_height) / 2)
	# 关键：允许鼠标事件穿透到子控件
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_panel)
	
	# 创建垂直布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 确保容器不拦截鼠标事件
	main_panel.add_child(vbox)
	
	# 标题（使用全局缩放）
	var title_label = Label.new()
	title_label.text = "部署完成"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(title_label, 28)
	vbox.add_child(title_label)
	
	# 说明文字（使用全局缩放）
	var instruction_label = Label.new()
	instruction_label.text = "所有玩家已部署完成，点击精灵可查看详细信息"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(instruction_label, 18)
	vbox.add_child(instruction_label)
	
	# 玩家信息显示区域
	players_container = VBoxContainer.new()
	players_container.add_theme_constant_override("separation", 20)
	players_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 确保容器不拦截鼠标事件
	vbox.add_child(players_container)
	
	# 填充空间
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# 继续按钮
	continue_button = Button.new()
	continue_button.text = "继续游戏"
	UIScaleManager.apply_scale_to_button(continue_button, 20)
	continue_button.pressed.connect(_on_continue_button_pressed)
	vbox.add_child(continue_button)
	
	# 加载玩家部署信息
	_load_deployment_info()

func _load_deployment_info():
	if not game_manager or not game_manager.sprite_deploy:
		print("错误: 无法获取游戏管理器或部署系统")
		return
	
	# 获取所有玩家的部署信息
	var deployed_sprites = game_manager.sprite_deploy.deployed_sprites
	
	# 遍历每个玩家（0-3）
	for player_id in range(GameManager.PLAYER_COUNT):
		if not deployed_sprites.has(player_id):
			continue
		
		var player_sprites = deployed_sprites[player_id] as Array[Sprite]
		if player_sprites.is_empty():
			continue
		
		# 创建玩家行
		var player_row = HBoxContainer.new()
		player_row.add_theme_constant_override("separation", 15)
		player_row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 确保容器不拦截鼠标事件
		players_container.add_child(player_row)
		
		# 玩家标签
		var player_label = Label.new()
		var player_name = "玩家 " + str(player_id)
		if player_id == GameManager.HUMAN_PLAYER_ID:
			player_name += " (你)"
		else:
			player_name += " (AI)"
		player_label.text = player_name
		player_label.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(150, 0))
		UIScaleManager.apply_scale_to_label(player_label, 20)
		player_row.add_child(player_label)
		
		# 显示该玩家的精灵卡片
		for sprite in player_sprites:
			if not sprite is Sprite:
				continue
			
			var sprite_card = _create_sprite_card(sprite)
			player_row.add_child(sprite_card)

func _create_sprite_card(sprite: Sprite) -> Button:
	var sprite_card = Button.new()
	# 直接使用缩放后的值，避免坐标错位
	var card_size = Vector2(200, 120)  # 原始尺寸
	sprite_card.custom_minimum_size = card_size  # 不再调用scale_vec2
	sprite_card.size = card_size  # 强制设置尺寸
	
	# 关键：禁用缩放管理器对按钮的直接缩放，改为通过全局缩放因子统一处理
	# 移除 UIScaleManager.apply_scale_to_button(sprite_card, 18)
	
	sprite_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sprite_card.focus_mode = Control.FOCUS_NONE
	sprite_card.toggle_mode = false
	sprite_card.text = ""
	sprite_card.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保按钮自身拦截事件
	
	# 修复锚点：不使用PRESET_FULL_RECT，改为手动设置
	var card_vbox = VBoxContainer.new()
	card_vbox.anchor_left = 0.0
	card_vbox.anchor_top = 0.0
	card_vbox.anchor_right = 1.0
	card_vbox.anchor_bottom = 1.0
	card_vbox.offset_left = 5  # 增加内边距，避免内容溢出
	card_vbox.offset_top = 5
	card_vbox.offset_right = -5
	card_vbox.offset_bottom = -5
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_card.add_child(card_vbox)
	
	# 标签文字大小直接使用缩放后的值
	var name_label = Label.new()
	name_label.text = sprite.sprite_name if sprite.sprite_name else "未知"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scale_factor = UIScaleManager.get_scale()
	name_label.add_theme_font_size_override("font_size", 18 * scale_factor)  # 使用缩放因子
	card_vbox.add_child(name_label)
	
	var attr_label = Label.new()
	var attribute_name = _get_attribute_name(sprite.attribute)
	var attribute_color = _get_attribute_color(sprite.attribute)
	attr_label.text = "属性: " + attribute_name
	attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attr_label.modulate = attribute_color
	attr_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attr_label.add_theme_font_size_override("font_size", 16 * scale_factor)
	card_vbox.add_child(attr_label)
	
	# 绑定事件（添加调试日志）
	sprite_card.pressed.connect(func():
		print("卡片点击触发！精灵名称：", sprite.sprite_name)
		_on_sprite_card_pressed(sprite)
	)
	sprite_card.mouse_entered.connect(_on_sprite_card_mouse_entered.bind(sprite_card))
	sprite_card.mouse_exited.connect(_on_sprite_card_mouse_exited.bind(sprite_card))
	
	return sprite_card

func _on_sprite_card_mouse_entered(sprite_card: Button):
	# 鼠标进入时高亮
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.3, 0.3, 0.3, 1.0)
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	sprite_card.add_theme_stylebox_override("normal", style_box)
	sprite_card.add_theme_stylebox_override("hover", style_box)

func _on_sprite_card_mouse_exited(sprite_card: Button):
	# 鼠标离开时恢复
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	style_box.border_color = Color(0.6, 0.6, 0.6, 1.0)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	sprite_card.add_theme_stylebox_override("normal", style_box)
	sprite_card.add_theme_stylebox_override("hover", style_box)

func _on_sprite_card_pressed(sprite: Sprite):
	_show_sprite_info(sprite)

func _show_sprite_info(sprite: Sprite):
	if not sprite:
		return
	
	# 从父节点（MainUI）获取sprite_info_card
	if not sprite_info_card:
		var main_ui = get_parent() as MainUI
		if main_ui:
			sprite_info_card = main_ui.sprite_info_card
	
	# 如果还是没有，创建一个新的
	if not sprite_info_card:
		sprite_info_card = SpriteInfoCard.new()
		sprite_info_card.game_manager = game_manager
		add_child(sprite_info_card)
	
	# 显示资料卡
	sprite_info_card.show_sprite_info(sprite)

func _on_continue_button_pressed():
	# 隐藏资料卡（如果正在显示）
	if sprite_info_card and sprite_info_card.visible:
		sprite_info_card.hide_info()
	
	# 发出继续信号
	continue_pressed.emit()
	
	# 关闭界面
	queue_free()

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

