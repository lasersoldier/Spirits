class_name CameraController
extends Camera3D

# 摄像机移动速度
var move_speed: float = 10.0

# 摄像机高度（固定，只允许在XZ平面移动）
var camera_height: float = 15.0

# 摄像机固定旋转角度（斜向下看）
var fixed_rotation: Vector3 = Vector3(-0.523599, 0, 0)  # 约30度向下

# 相机旋转控制
var rotation_speed: float = 2.0  # 旋转速度
var is_rotating: bool = false  # 是否正在旋转

# 摄像机移动范围限制（可选）
var min_x: float = -30.0
var max_x: float = 30.0
var min_z: float = -30.0
var max_z: float = 30.0

# 是否启用移动限制
var enable_bounds: bool = false

func _ready():
	# 设置摄像机初始位置在原点(0, 0)
	position = Vector3(0.0, camera_height, 0.0)
	# 设置固定的旋转角度（斜向下）
	rotation = fixed_rotation
	
	print("摄像机初始位置: ", position)

func _process(delta):
	_handle_movement(delta)

func _handle_movement(delta):
	var move_direction = Vector3.ZERO
	
	# WASD 控制（相对于当前视角方向）
	# 获取相机的朝向（只考虑Y轴旋转，忽略X轴俯视角度）
	var camera_forward = -transform.basis.z  # 相机前方（负Z方向）
	var camera_right = transform.basis.x     # 相机右方（X方向）
	
	# 将方向投影到XZ平面（忽略Y分量）
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	# 根据输入计算移动方向（相对于视角）
	if Input.is_key_pressed(KEY_W):
		move_direction += camera_forward  # 向前（相机朝向）
	if Input.is_key_pressed(KEY_S):
		move_direction -= camera_forward  # 向后（相机反方向）
	if Input.is_key_pressed(KEY_A):
		move_direction -= camera_right    # 向左（相机左侧）
	if Input.is_key_pressed(KEY_D):
		move_direction += camera_right    # 向右（相机右侧）
	
	# 标准化移动方向
	if move_direction.length() > 0:
		move_direction = move_direction.normalized()
	
	# 应用移动（只在XZ平面，保持Y高度不变）
	var new_position = position + move_direction * move_speed * delta
	new_position.y = camera_height  # 保持固定高度
	
	# 应用边界限制
	if enable_bounds:
		new_position.x = clamp(new_position.x, min_x, max_x)
		new_position.z = clamp(new_position.z, min_z, max_z)
	
	position = new_position
	# 如果不在旋转状态，保持固定的俯视角度
	if not is_rotating:
		rotation.x = fixed_rotation.x  # 保持俯视角度

# 处理输入事件（用于检测按键刚刚按下）
func _input(event):
	# 按R键重置相机到原点
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_to_origin()
	
	# 处理鼠标右键旋转
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# 右键按下，开始旋转
				is_rotating = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # 捕获鼠标
			else:
				# 右键释放，停止旋转
				is_rotating = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # 释放鼠标
	
	# 处理鼠标移动（旋转相机）
	if event is InputEventMouseMotion and is_rotating:
		var mouse_delta = event.relative
		# 水平移动控制Y轴旋转（左右旋转）
		rotation.y -= mouse_delta.x * rotation_speed * 0.001
		# 保持俯视角度不变
		rotation.x = fixed_rotation.x

# 将相机重定位到原点(0, 0)
func reset_to_origin():
	position = Vector3(0.0, camera_height, 0.0)
	rotation = fixed_rotation
	print("相机已重置到原点: ", position)
