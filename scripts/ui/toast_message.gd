class_name ToastMessage
extends Control

# 飘字提示系统
# 用于显示"金币不足"、"保存成功"等消息

signal finished

@onready var label: Label = $Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var message: String = ""
var duration: float = 2.0
var fade_duration: float = 0.5

func _ready():
	# 设置初始状态
	modulate.a = 0.0
	label.text = message
	
	# 创建动画
	_create_animation()
	
	# 动画在_create_animation中已创建

func setup(text: String, display_time: float = 2.0):
	message = text
	duration = display_time
	if label:
		label.text = message

func _create_animation():
	if not animation_player:
		return
	
	# 使用Tween代替AnimationPlayer（更简单）
	var tween = create_tween()
	
	# 淡入
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	
	# 上移
	var start_pos = position
	tween.parallel().tween_property(self, "position:y", start_pos.y - 100, duration + fade_duration)
	
	# 等待
	tween.tween_interval(duration)
	
	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	
	# 完成
	tween.tween_callback(_on_animation_finished)

func _on_animation_finished():
	finished.emit()
	queue_free()

# 静态方法：显示Toast消息
static func show(parent: Node, text: String, duration: float = 2.0, position: Vector2 = Vector2.ZERO):
	var toast_scene = load("res://scenes/ui/toast_message.tscn")
	if not toast_scene:
		push_error("ToastMessage: 无法加载场景 res://scenes/ui/toast_message.tscn")
		return null
	
	var toast = toast_scene.instantiate()
	parent.add_child(toast)
	toast.setup(text, duration)
	
	# 设置位置（默认在屏幕底部中央）
	if position == Vector2.ZERO:
		var viewport_size = parent.get_viewport().get_visible_rect().size
		toast.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y - 100)
	else:
		toast.position = position
	
	return toast

