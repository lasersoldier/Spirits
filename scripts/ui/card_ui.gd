class_name CardUI
extends Panel

# 卡牌引用
var card: Card = null

# 拖动状态
var is_dragging: bool = false
var is_right_dragging: bool = false  # 右键拖拽状态
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

# 信号
signal card_drag_started(card_ui: CardUI, card: Card)
signal card_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)
signal card_right_drag_started(card_ui: CardUI, card: Card)
signal card_right_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)
signal card_right_clicked(card_ui: CardUI, card: Card)

func _ready():
	# 设置鼠标输入
	mouse_filter = MOUSE_FILTER_STOP
	# 设置样式，让卡牌看起来可点击
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style_box.border_color = Color(0.5, 0.5, 0.7, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", style_box)
	# 监听全局输入，确保拖动时即使鼠标移出卡牌也能检测到释放
	set_process_unhandled_input(true)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖动
				_start_drag(event.position)
			else:
				# 结束拖动
				_end_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# 开始右键拖动
				_start_right_drag(event.position)
			else:
				# 结束右键拖动
				_end_right_drag(event.position)

func _unhandled_input(event: InputEvent):
	# 处理全局鼠标释放事件（拖动时鼠标可能移出卡牌）
	if event is InputEventMouseButton:
		if is_dragging and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(Vector2.ZERO)
			get_viewport().set_input_as_handled()
		elif is_right_dragging and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_end_right_drag(Vector2.ZERO)
			get_viewport().set_input_as_handled()

func _process(_delta):
	if is_dragging or is_right_dragging:
		_update_drag_position(Vector2.ZERO)

func _start_drag(_mouse_pos: Vector2):
	# 如果已经在右键拖拽，先结束右键拖拽
	if is_right_dragging:
		_end_right_drag(Vector2.ZERO)
	
	is_dragging = true
	original_position = position
	# 设置处理模式，确保能接收鼠标事件
	set_process(true)
	# 发出拖动开始信号（不移动卡牌，而是显示箭头）
	card_drag_started.emit(self, card)

func _update_drag_position(_mouse_pos: Vector2):
	if not is_dragging:
		return
	# 卡牌不移动，只是更新箭头位置
	# 通过信号通知主UI更新箭头

func _end_drag(_mouse_pos: Vector2):
	if not is_dragging:
		return
	
	is_dragging = false
	set_process(false)
	
	# 发出拖动结束信号
	var global_mouse = get_global_mouse_position()
	card_drag_ended.emit(self, card, global_mouse)

func _start_right_drag(_mouse_pos: Vector2):
	# 如果已经在左键拖拽，先结束左键拖拽
	if is_dragging:
		_end_drag(Vector2.ZERO)
	
	is_right_dragging = true
	original_position = position
	# 设置处理模式，确保能接收鼠标事件
	set_process(true)
	# 发出右键拖动开始信号
	card_right_drag_started.emit(self, card)

func _end_right_drag(_mouse_pos: Vector2):
	if not is_right_dragging:
		return
	
	is_right_dragging = false
	set_process(false)
	
	# 发出右键拖动结束信号
	var global_mouse = get_global_mouse_position()
	card_right_drag_ended.emit(self, card, global_mouse)

func set_card(c: Card):
	card = c

