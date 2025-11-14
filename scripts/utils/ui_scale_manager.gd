extends Node
# UI缩放管理器 - 单例（通过autoload加载）
# 用于根据分辨率自动缩放所有UI元素

# 基础分辨率（设计分辨率）
const BASE_WIDTH: int = 1920
const BASE_HEIGHT: int = 1080

# 当前缩放比例
var scale_factor: float = 1.0

# 缩放比例的最小和最大值
const MIN_SCALE: float = 0.5
const MAX_SCALE: float = 3.0

# 单例实例
static var instance: UIScaleManager

func _ready():
	instance = self
	# 监听窗口大小变化
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# 初始化缩放
	_update_scale()

func _on_viewport_size_changed():
	_update_scale()

# 更新缩放比例
func _update_scale():
	# 固定缩放系数为1.0，不随窗口大小变化（用于测试高亮偏移问题）
	scale_factor = 1.0
	
	# 注释掉原来的动态缩放逻辑
	#var viewport_size = get_viewport().get_visible_rect().size
	#if viewport_size.x <= 0 or viewport_size.y <= 0:
	#	return
	#
	## 基于宽度和高度的较小值来计算缩放，保持比例
	#var scale_x = viewport_size.x / BASE_WIDTH
	#var scale_y = viewport_size.y / BASE_HEIGHT
	#scale_factor = min(scale_x, scale_y)
	#
	## 限制在最小和最大值之间
	#scale_factor = clamp(scale_factor, MIN_SCALE, MAX_SCALE)
	
	print("UI缩放比例更新: ", scale_factor, " (固定为1.0，不随窗口大小变化)")

# 获取缩放后的值（用于尺寸）
func scale_value(value: float) -> float:
	return value * scale_factor

# 获取缩放后的值（用于整数尺寸）
func scale_value_int(value: int) -> int:
	return int(value * scale_factor)

# 获取缩放后的Vector2
func scale_vector2(vec: Vector2) -> Vector2:
	return vec * scale_factor

# 获取缩放后的字体大小
func scale_font_size(base_size: int) -> int:
	return int(base_size * scale_factor)

# 应用缩放到一个Control节点
func apply_scale_to_control(control: Control):
	if not control:
		return
	
	# 缩放自定义最小尺寸
	if control.custom_minimum_size != Vector2.ZERO:
		control.custom_minimum_size = scale_vector2(control.custom_minimum_size)
	
	# 缩放位置和偏移
	if control.position != Vector2.ZERO:
		control.position = scale_vector2(control.position)
	
	# 缩放尺寸（如果size不为零，说明是手动设置的尺寸）
	# 注意：如果使用anchors，size可能会自动计算，所以只缩放明确设置的size
	if control.size != Vector2.ZERO and control.layout_mode == 0:
		# layout_mode = 0 表示使用位置模式（不使用anchors）
		control.size = scale_vector2(control.size)

# 应用缩放到一个Label节点（包括字体大小）
func apply_scale_to_label(label: Label, base_font_size: int = 16):
	if not label:
		return
	
	apply_scale_to_control(label)
	
	# 缩放字体大小
	if base_font_size > 0:
		var scaled_size = scale_font_size(base_font_size)
		label.add_theme_font_size_override("font_size", scaled_size)

# 应用缩放到一个Button节点
func apply_scale_to_button(button: Button, base_font_size: int = 16):
	if not button:
		return
	
	apply_scale_to_control(button)
	
	# 缩放字体大小
	if base_font_size > 0:
		var scaled_size = scale_font_size(base_font_size)
		button.add_theme_font_size_override("font_size", scaled_size)

# 应用缩放到一个Panel节点
func apply_scale_to_panel(panel: Panel):
	apply_scale_to_control(panel)

# 获取当前缩放比例
static func get_scale() -> float:
	if instance:
		return instance.scale_factor
	return 1.0

# 静态方法：缩放值
static func scale(val: float) -> float:
	if instance:
		return instance.scale_value(val)
	return val

# 静态方法：缩放整数
static func scale_int(val: int) -> int:
	if instance:
		return instance.scale_value_int(val)
	return val

# 静态方法：缩放Vector2
static func scale_vec2(vec: Vector2) -> Vector2:
	if instance:
		return instance.scale_vector2(vec)
	return vec

# 实例方法：缩放Vector2（用于非静态调用）
func scale_vec2_instance(vec: Vector2) -> Vector2:
	return scale_vector2(vec)

# 静态方法：缩放字体大小
static func scale_font(base_size: int) -> int:
	if instance:
		return instance.scale_font_size(base_size)
	return base_size
