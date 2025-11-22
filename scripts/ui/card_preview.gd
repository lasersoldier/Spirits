class_name CardPreview
extends Control

var card: Card = null
var preview_card_face: CardFace = null

@onready var main_container: HBoxContainer = $MainContainer
@onready var card_container: VBoxContainer = $MainContainer/CardContainer
@onready var preview_card: Control = $MainContainer/CardContainer/PreviewCard
@onready var explanation_content: VBoxContainer = $MainContainer/ExplanationPanel/ScrollContainer/ExplanationContent
@onready var title_label: Label = $MainContainer/ExplanationPanel/ScrollContainer/ExplanationContent/TitleLabel

const CARD_FACE_SCENE_PATH = "res://scenes/ui/card_face.tscn"
const CARD_FACE_SCENE := preload("res://scenes/ui/card_face.tscn")

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(card_data: Card):
	card = card_data
	custom_minimum_size = Vector2(700, 500)
	size = Vector2(700, 500)
	# 确保所有@onready节点都已准备好
	if not is_inside_tree():
		await ready
	# 等待节点完全初始化
	await get_tree().process_frame
	# 使用 call_deferred 确保在下一帧执行，此时所有节点都已准备好
	call_deferred("_display_preview_card")
	call_deferred("_display_explanations")

func _display_preview_card():
	if not card or not preview_card:
		print("CardPreview: _display_preview_card 失败 - card=", card, " preview_card=", preview_card)
		return
	
	# 清空现有卡牌
	for child in preview_card.get_children():
		child.queue_free()
	
	# 扩展调试信息
	print("CardPreview: ========== 开始调试场景加载 ==========")
	print("CardPreview: 场景路径: ", CARD_FACE_SCENE_PATH)
	print("CardPreview: 预加载场景是否有效: ", CARD_FACE_SCENE != null)
	if CARD_FACE_SCENE:
		print("CardPreview: 预加载场景资源路径: ", CARD_FACE_SCENE.resource_path)
		print("CardPreview: 预加载场景类型: ", CARD_FACE_SCENE.get_class())
	
	# 检查资源是否存在
	var resource_exists = ResourceLoader.exists(CARD_FACE_SCENE_PATH)
	print("CardPreview: 资源文件是否存在: ", resource_exists)
	
	# 获取场景资源 - 优先使用动态加载，因为预加载可能有问题
	var scene_to_use: PackedScene = null
	
	# 先尝试动态加载（更可靠）
	print("CardPreview: 尝试动态加载场景...")
	scene_to_use = load(CARD_FACE_SCENE_PATH) as PackedScene
	if scene_to_use:
		print("CardPreview: 动态加载成功")
	else:
		# 如果动态加载失败，尝试使用预加载的
		print("CardPreview: 动态加载失败，尝试使用预加载的场景...")
		scene_to_use = CARD_FACE_SCENE
		if scene_to_use:
			print("CardPreview: 使用预加载场景")
		else:
			push_error("CardPreview: 所有加载方式都失败")
	
	if not scene_to_use:
		push_error("CardPreview: 无法获取场景资源")
		var error_label = Label.new()
		error_label.text = "场景资源无效\n路径: " + CARD_FACE_SCENE_PATH
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_card.add_child(error_label)
		return
	
	# 检查场景状态
	print("CardPreview: 场景资源路径: ", scene_to_use.resource_path if scene_to_use.resource_path else "空")
	var scene_state = scene_to_use.get_state()
	var node_count = scene_state.get_node_count() if scene_state else 0
	print("CardPreview: 场景状态节点数: ", node_count)
	
	if node_count == 0:
		push_error("CardPreview: 场景状态为空，节点数为0！场景文件可能损坏")
		var error_label = Label.new()
		error_label.text = "场景文件损坏\n节点数为0\n请检查场景文件"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_card.add_child(error_label)
		return
	
	# 尝试实例化
	print("CardPreview: 开始实例化场景...")
	preview_card_face = scene_to_use.instantiate()
	print("CardPreview: instantiate() 返回: ", preview_card_face)
	print("CardPreview: 返回类型: ", typeof(preview_card_face))
	
	if not preview_card_face:
		push_error("CardPreview: instantiate() 返回 null")
		var error_label = Label.new()
		error_label.text = "无法实例化场景\n请检查场景文件是否损坏"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_card.add_child(error_label)
		return
	
	# 检查类型
	print("CardPreview: 实例化对象类型: ", preview_card_face.get_class())
	print("CardPreview: 是否为 CardFace: ", preview_card_face is CardFace)
	
	if not preview_card_face is CardFace:
		push_error("CardPreview: 实例化的对象不是 CardFace 类型, 实际类型: ", preview_card_face.get_class())
		preview_card_face.queue_free()
		preview_card_face = null
		var error_label = Label.new()
		error_label.text = "卡牌类型错误\n期望: CardFace\n实际: " + str(preview_card_face.get_class() if preview_card_face else "null")
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_card.add_child(error_label)
		return
	
	print("CardPreview: ========== 场景加载成功 ==========")
	print("CardPreview: 成功实例化卡牌, 类型: ", preview_card_face.get_class())
	
	# 先设置大小和属性，再添加到场景树
	# 宽度固定为260，高度自动填充父容器（与效果说明区域等高）
	preview_card_face.custom_minimum_size = Vector2(260, 0)
	preview_card_face.size = Vector2(260, 0)
	preview_card_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_card_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.add_child(preview_card_face)
	
	# 使用 call_deferred 确保在下一帧设置卡牌数据
	call_deferred("_set_preview_card_data")

func _set_preview_card_data():
	# 在节点完全初始化后设置卡牌数据
	if preview_card_face and is_instance_valid(preview_card_face) and card:
		preview_card_face.set_card(card)

func _display_explanations():
	if not card or not explanation_content:
		return
	
	# 清空现有解释
	for child in explanation_content.get_children():
		if child != title_label:
			child.queue_free()
	
	# 获取简称描述
	var short_desc = card.get_short_description()
	print("CardPreview: 简称描述 = ", short_desc)
	
	if short_desc.is_empty():
		# 如果没有简称，显示原始描述
		var fallback_label = Label.new()
		fallback_label.text = "无效果说明"
		fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation_content.add_child(fallback_label)
		return
	
	# 提取所有简称代码
	var codes = CardEffectShortener.extract_short_codes(short_desc)
	print("CardPreview: 提取到的简称代码数量 = ", codes.size(), " 代码: ", codes)
	
	if codes.is_empty():
		# 如果没有提取到简称代码，显示原始描述
		var fallback_label = Label.new()
		fallback_label.text = short_desc
		fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation_content.add_child(fallback_label)
		return
	
	# 为每个简称创建解释
	for code in codes:
		var explanation = CardEffectShortener.get_explanation(code)
		print("CardPreview: 简称代码 '", code, "' 的解释 = '", explanation, "'")
		# 即使解释为空，也显示简称代码
		if explanation.is_empty():
			explanation = "效果说明暂未定义"
		
		# 创建解释项
		var item_container = VBoxContainer.new()
		item_container.add_theme_constant_override("separation", 4)
		explanation_content.add_child(item_container)
		
		# 简称标签
		var code_label = Label.new()
		code_label.text = code
		code_label.add_theme_font_size_override("font_size", 16)
		code_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # 金色
		item_container.add_child(code_label)
		
		# 解释文本
		var desc_label = Label.new()
		desc_label.text = explanation
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 14)
		item_container.add_child(desc_label)
		
		# 分隔线（最后一个不添加）
		if code != codes[codes.size() - 1]:
			var separator = HSeparator.new()
			explanation_content.add_child(separator)

# 预览由card_face控制关闭，这里不需要额外逻辑

var mouse_in_preview: bool = false
var close_timer: Timer = null
var mouse_check_timer: Timer = null

func _on_mouse_entered():
	# 鼠标进入预览，取消关闭定时器
	mouse_in_preview = true
	if close_timer:
		close_timer.stop()
		close_timer.queue_free()
		close_timer = null
	# 停止鼠标检测定时器
	if mouse_check_timer:
		mouse_check_timer.stop()
		mouse_check_timer.queue_free()
		mouse_check_timer = null

func _on_mouse_exited():
	# 鼠标离开预览，启动关闭定时器
	mouse_in_preview = false
	# 取消之前的定时器
	if close_timer:
		close_timer.stop()
		close_timer.queue_free()
	# 创建新的定时器，延迟更短（0.1秒）
	close_timer = Timer.new()
	close_timer.wait_time = 0.1
	close_timer.one_shot = true
	close_timer.timeout.connect(_check_and_close)
	add_child(close_timer)
	close_timer.start()

func _check_and_close():
	# 检查鼠标是否真的不在预览窗口内
	if not mouse_in_preview:
		var mouse_pos = get_global_mouse_position()
		var rect = get_global_rect()
		if not rect.has_point(mouse_pos):
			queue_free()
		else:
			# 如果鼠标还在预览内，启动持续检测
			_start_mouse_check()

func _start_mouse_check():
	# 持续检测鼠标位置
	if mouse_check_timer:
		mouse_check_timer.stop()
		mouse_check_timer.queue_free()
	
	mouse_check_timer = Timer.new()
	mouse_check_timer.wait_time = 0.1
	mouse_check_timer.timeout.connect(_check_mouse_position)
	add_child(mouse_check_timer)
	mouse_check_timer.start()

func _check_mouse_position():
	# 检查鼠标是否还在预览窗口内
	var mouse_pos = get_global_mouse_position()
	var rect = get_global_rect()
	
	if not rect.has_point(mouse_pos):
		# 鼠标不在预览内，关闭预览
		queue_free()
	else:
		# 鼠标还在预览内，继续检测
		_start_mouse_check()

func _exit_tree():
	# 清理
	if preview_card_face:
		preview_card_face.queue_free()
