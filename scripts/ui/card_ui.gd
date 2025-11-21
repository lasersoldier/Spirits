class_name CardUI
extends Control

# 卡牌引用
var card: Card = null

# 卡牌展示
const CARD_FACE_SCENE := preload("res://scenes/ui/card_face.tscn")
var card_face: CardFace

# 游戏管理器引用（用于检查当前阶段）
var game_manager: GameManager = null

# 拖动状态
var is_dragging: bool = false
var is_right_dragging: bool = false  # 右键拖拽状态
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

# 是否允许拖动（部署阶段禁用）
var can_drag: bool = true

# 信号
signal card_drag_started(card_ui: CardUI, card: Card)
signal card_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)
signal card_right_drag_started(card_ui: CardUI, card: Card)
signal card_right_drag_ended(card_ui: CardUI, card: Card, drop_position: Vector2)
signal card_right_clicked(card_ui: CardUI, card: Card)

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = false
	set_process_unhandled_input(true)
	card_face = CARD_FACE_SCENE.instantiate()
	card_face.set_selected(false)
	add_child(card_face)
	card_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_mouse_filter_recursive(card_face, Control.MOUSE_FILTER_IGNORE)
	# CardFace 会在自己的 _ready 中把 mouse_filter 重置为 STOP，这里延迟一次确保它保持 IGNORE
	call_deferred("_ensure_card_face_mouse_filter")
	if card:
		card_face.set_card(card)

func _gui_input(event: InputEvent):
	# 检查是否允许拖动（部署阶段禁用）
	if not can_drag:
		return
	
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

func _start_drag(_mouse_pos: Vector2):
	# 检查是否允许拖动
	if not can_drag:
		return
	
	# 如果已经在右键拖拽，先结束右键拖拽
	if is_right_dragging:
		_end_right_drag(Vector2.ZERO)
	
	is_dragging = true
	original_position = position
	# 设置处理模式，确保能接收鼠标事件
	set_process(true)
	# 发出拖动开始信号（不移动卡牌，而是显示箭头）
	card_drag_started.emit(self, card)

func _end_drag(_mouse_pos: Vector2):
	if not is_dragging:
		return
	
	is_dragging = false
	set_process(false)
	
	# 发出拖动结束信号
	var global_mouse = get_global_mouse_position()
	card_drag_ended.emit(self, card, global_mouse)

func _start_right_drag(_mouse_pos: Vector2):
	# 检查是否允许拖动
	if not can_drag:
		return
	
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
	if card_face:
		card_face.set_card(card)

func _ensure_card_face_mouse_filter():
	if card_face:
		_set_mouse_filter_recursive(card_face, Control.MOUSE_FILTER_IGNORE)

func _set_mouse_filter_recursive(node: Node, mode: int):
	if node is Control:
		node.mouse_filter = mode
	for child in node.get_children():
		_set_mouse_filter_recursive(child, mode)

# 设置游戏管理器引用
func set_game_manager(gm: GameManager):
	game_manager = gm
	_update_drag_state()

# 更新拖动状态（根据当前游戏阶段）
func _update_drag_state():
	if not game_manager:
		can_drag = true
		return
	
	# 部署阶段禁用拖动
	can_drag = (game_manager.current_phase != GameManager.GamePhase.DEPLOYMENT)
	
	# 更新卡牌外观（禁用时变灰）
	if not can_drag:
		if card_face:
			card_face.set_disabled(true)
	else:
		if card_face:
			card_face.set_disabled(false)
