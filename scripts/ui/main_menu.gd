class_name MainMenu
extends Control

# 场景路径
@export_file("*.tscn") var single_player_scene: String = "res://scenes/main.tscn"
@export_file("*.tscn") var training_scene: String = "res://scenes/training.tscn"
@export_file("*.tscn") var deck_scene: String = ""  # 卡组管理场景（待实现）
@export_file("*.tscn") var settings_scene: String = ""  # 设置场景（待实现）

# UI 节点引用
@onready var particle_background: ParticleBackground = $ParticleBackground
@onready var title_label: Label = $ContentLayer/Header/TitleContainer/TitleLabel
@onready var subtitle_label: Label = $ContentLayer/Header/TitleContainer/SubtitleLabel
@onready var lore_panel: Panel = $ContentLayer/MenuArea/LorePanel
@onready var lore_label: RichTextLabel = $ContentLayer/MenuArea/LorePanel/LoreLabel
@onready var menu_container: VBoxContainer = $ContentLayer/MenuArea/MenuContainer
@onready var description_label: Label = $ContentLayer/MenuArea/DescriptionLabel
@onready var footer_left: HBoxContainer = $ContentLayer/Footer/FooterLeft
@onready var footer_right: Label = $ContentLayer/Footer/FooterRight

# 菜单项配置
var menu_items: Array[Dictionary] = [
	{
		"id": "campaign",
		"label": "单人游戏",
		"desc": "开始你的冒险之旅",
		"scene": "single_player_scene"
	},
	{
		"id": "training",
		"label": "训练场",
		"desc": "磨练你的技能",
		"scene": "training_scene"
	}
]

var menu_buttons: Array[Button] = []
var hovered_item: String = ""
var description_tween: Tween = null
var button_tweens: Dictionary = {}  # 存储每个按钮的 tween

# Lore 文本（可以后续连接 AI 服务）
var lore_text: String = "Connecting to the ley lines..."

func _ready():
	print("MainMenu: _ready() called")
	print("MainMenu: menu_container path: ContentLayer/MenuArea/MenuContainer")
	print("MainMenu: menu_container node: ", get_node_or_null("ContentLayer/MenuArea/MenuContainer"))
	_setup_ui()
	_connect_signals()
	_load_lore()

func _setup_ui():
	# 设置标题
	if title_label:
		title_label.text = "SPIRIT CONTINENT"
	else:
		push_warning("MainMenu: title_label is null")
	
	if subtitle_label:
		subtitle_label.text = "Season of the Flame"
	else:
		push_warning("MainMenu: subtitle_label is null")
	
	# 等待一帧确保所有节点都已初始化
	await get_tree().process_frame
	
	# 创建菜单按钮
	_create_menu_buttons()
	
	# 设置 Lore 文本
	if lore_label:
		lore_label.text = "[i]\"" + lore_text + "\"[/i]"
	else:
		push_warning("MainMenu: lore_label is null")
	
	# 设置底部信息
	_setup_footer()

func _create_menu_buttons():
	if not menu_container:
		push_error("MainMenu: menu_container is null!")
		return
	
	print("MainMenu: Creating menu buttons, container found: ", menu_container)
	
	# 清除现有按钮
	for child in menu_container.get_children():
		child.queue_free()
	menu_buttons.clear()
	
	# 创建新按钮
	for item in menu_items:
		var button = _create_menu_button(item)
		menu_container.add_child(button)
		menu_buttons.append(button)
		print("MainMenu: Created button: ", item.label)
		print("MainMenu: Button visible: ", button.visible)
		print("MainMenu: Button size: ", button.size)
		print("MainMenu: Button position: ", button.position)
		print("MainMenu: Button global position: ", button.get_global_rect())
	
	print("MainMenu: Total buttons created: ", menu_buttons.size())
	print("MainMenu: MenuContainer position: ", menu_container.position)
	print("MainMenu: MenuContainer size: ", menu_container.size)
	print("MainMenu: MenuContainer global rect: ", menu_container.get_global_rect())
	print("MainMenu: MenuArea position: ", menu_container.get_parent().position if menu_container.get_parent() else "null")
	print("MainMenu: MenuArea size: ", menu_container.get_parent().size if menu_container.get_parent() else "null")

func _create_menu_button(item: Dictionary) -> Button:
	var button = Button.new()
	button.text = item.label
	button.custom_minimum_size = Vector2(320, 64)
	button.visible = true  # 确保可见
	button.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保可以接收鼠标事件
	
	# 设置按钮样式 - 使用更亮的颜色确保可见
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.25, 0.8)  # 更亮的背景
	style_normal.border_color = Color(0.6, 0.6, 0.6, 0.8)  # 更亮的边框
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_bottom_right = 32
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.3, 0.3, 0.35, 0.9)  # 悬停时更亮
	style_hover.border_color = Color(1.0, 0.75, 0.25, 1.0)  # 金色边框
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_hover)
	
	# 设置字体大小和颜色
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))  # 浅色文字
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))  # 悬停时白色
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	
	# 连接信号
	button.mouse_entered.connect(func(): _on_menu_item_hovered(item.label, item.desc))
	button.mouse_exited.connect(func(): _on_menu_item_unhovered())
	button.pressed.connect(func(): _on_menu_item_pressed(item))
	
	return button

func _connect_signals():
	# 信号连接已在按钮创建时完成
	pass

func _on_menu_item_hovered(label: String, desc: String):
	hovered_item = label
	
	# 停止之前的描述隐藏动画
	if description_tween:
		description_tween.kill()
		description_tween = null
	
	if description_label:
		description_label.text = desc
		# 立即显示，不等待动画
		description_label.modulate.a = 1.0
	
	# 更新按钮样式（添加高亮效果）
	for i in range(menu_buttons.size()):
		var button = menu_buttons[i]
		# 停止之前的按钮动画
		if button_tweens.has(button):
			var old_tween = button_tweens[button]
			if old_tween:
				old_tween.kill()
		
		if menu_items[i].label == label:
			var tween = create_tween()
			tween.tween_property(button, "modulate", Color(1.1, 1.1, 0.95, 1.0), 0.2)
			button_tweens[button] = tween
		else:
			# 其他按钮恢复原色
			var tween = create_tween()
			tween.tween_property(button, "modulate", Color.WHITE, 0.2)
			button_tweens[button] = tween

func _on_menu_item_unhovered():
	# 延迟检查，确保鼠标真的离开了所有按钮
	await get_tree().create_timer(0.05).timeout
	
	# 如果鼠标已经移动到另一个按钮上，hovered_item 会被更新，这里就不隐藏
	if hovered_item != "":
		return
	
	hovered_item = ""
	if description_label:
		# 停止之前的动画
		if description_tween:
			description_tween.kill()
		description_tween = create_tween()
		description_tween.tween_property(description_label, "modulate:a", 0.0, 0.2)
	
	# 恢复所有按钮样式
	for button in menu_buttons:
		# 停止之前的动画
		if button_tweens.has(button):
			var old_tween = button_tweens[button]
			if old_tween:
				old_tween.kill()
		var tween = create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, 0.2)
		button_tweens[button] = tween

func _on_menu_item_pressed(item: Dictionary):
	var scene_path = ""
	match item.scene:
		"single_player_scene":
			scene_path = single_player_scene
		"training_scene":
			scene_path = training_scene
		"deck_scene":
			scene_path = deck_scene
		"settings_scene":
			scene_path = settings_scene
	
	if scene_path.is_empty():
		push_warning("MainMenu: Scene path is empty for " + item.label)
		return
	
	_load_scene(scene_path)

func _load_scene(scene_path: String):
	if scene_path.is_empty():
		push_warning("MainMenu: scene path is empty")
		return
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("MainMenu: failed to load scene: " + scene_path + " (error " + str(error) + ")")

func _load_lore():
	# 这里可以连接 AI 服务生成 lore
	# 目前使用占位文本
	lore_text = "In the realm where elemental forces converge, ancient spirits awaken to guide the chosen ones through trials of fire, water, wind, and earth."
	if lore_label:
		lore_label.text = "[i]\"" + lore_text + "\"[/i]"

func _setup_footer():
	if footer_left:
		# 可以添加版本、服务器等信息
		pass
	if footer_right:
		footer_right.text = "UID: 114514"
