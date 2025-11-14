class_name MapClickHandler
extends Node

# 地图点击处理器：将鼠标点击转换为六边形坐标

var game_map: GameMap
var camera: Camera3D
var sub_viewport: SubViewport

signal hex_clicked(hex_coord: Vector2i)

func _init(map: GameMap, cam: Camera3D, viewport: SubViewport):
	game_map = map
	camera = cam
	sub_viewport = viewport

func _ready():
	# 设置处理输入
	set_process_input(true)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 使用 SubViewport 的输入系统
		if sub_viewport:
			# 获取鼠标在 SubViewport 中的位置
			var viewport_pos = _get_mouse_pos_in_viewport()
			# 检查是否在视口范围内（包括边界）
			if viewport_pos.x >= 0 and viewport_pos.y >= 0:
				var viewport_size = Vector2(sub_viewport.size)
				if viewport_pos.x <= viewport_size.x and viewport_pos.y <= viewport_size.y:
					_handle_click_in_viewport(viewport_pos)
					return
		
		# 回退到原来的方法（如果不在 SubViewport 范围内）
		var global_mouse_pos = get_viewport().get_mouse_position()
		_handle_click(global_mouse_pos)

# 尝试使用 SubViewport 的输入系统直接处理
func _unhandled_input(_event: InputEvent):
	# 如果 SubViewport 的 handle_input_locally = false，输入事件会传递到这里
	# 我们可以尝试在这里处理
	pass

# 获取鼠标在 SubViewport 中的位置
func _get_mouse_pos_in_viewport() -> Vector2:
	if not sub_viewport:
		return Vector2.ZERO
	
	var container = sub_viewport.get_parent() as SubViewportContainer
	if not container:
		return Vector2.ZERO
	
	# 获取主视口的鼠标位置
	var main_viewport = get_viewport()
	var global_mouse = main_viewport.get_mouse_position()
	
	# 获取容器的全局矩形
	var container_rect = container.get_global_rect()
	if not container_rect.has_point(global_mouse):
		return Vector2.ZERO
	
	# 转换为容器局部坐标
	var local_pos = global_mouse - container_rect.position
	
	# 获取视口和容器大小
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	# 调试：输出容器信息
	print("容器信息: 全局位置=", container_rect.position, " | 大小=", container_size, " | 视口大小=", viewport_size)
	
	# 计算视口坐标
	var viewport_pos: Vector2
	var offset_x: float = 0.0
	var offset_y: float = 0.0
	
	if container.stretch:
		# 拉伸模式：保持宽高比
		var scale = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale
		var scaled_height = viewport_size.y * scale
		offset_x = (container_size.x - scaled_width) / 2.0
		offset_y = (container_size.y - scaled_height) / 2.0
		viewport_pos.x = (local_pos.x - offset_x) / scale
		viewport_pos.y = (local_pos.y - offset_y) / scale
	else:
		# 非拉伸模式：原始大小
		# 当 stretch = false 时，SubViewport 以原始大小显示
		# SubViewportContainer 的默认行为是：如果容器比视口大，视口会居中显示
		# 如果容器比视口小，视口会被裁剪（从左上角开始）
		if container_size.x >= viewport_size.x:
			# 容器比视口宽，视口居中显示
			offset_x = (container_size.x - viewport_size.x) / 2.0
			viewport_pos.x = local_pos.x - offset_x
		else:
			# 容器比视口窄，视口被裁剪（从左上角开始）
			# 将容器坐标映射到视口坐标
			viewport_pos.x = (local_pos.x / container_size.x) * viewport_size.x
		
		if container_size.y >= viewport_size.y:
			# 容器比视口高，视口居中显示
			offset_y = (container_size.y - viewport_size.y) / 2.0
			viewport_pos.y = local_pos.y - offset_y
		else:
			# 容器比视口矮，视口被裁剪（从左上角开始）
			# 将容器坐标映射到视口坐标
			viewport_pos.y = (local_pos.y / container_size.y) * viewport_size.y
	
	# 限制在视口范围内
	viewport_pos.x = clamp(viewport_pos.x, 0, viewport_size.x)
	viewport_pos.y = clamp(viewport_pos.y, 0, viewport_size.y)
	
	# 调试输出
	print("坐标转换: 全局鼠标=", global_mouse, " | 容器局部=", local_pos, " | 视口坐标=", viewport_pos, " | 偏移=(", offset_x, ", ", offset_y, ")")
	
	return viewport_pos

# 直接在 SubViewport 坐标系统中处理点击
func _handle_click_in_viewport(viewport_pos: Vector2):
	if not camera or not game_map or not sub_viewport:
		return
	
	print("SubViewport坐标: ", viewport_pos)
	
	# 确保坐标在 SubViewport 范围内
	var viewport_size = Vector2(sub_viewport.size)
	viewport_pos.x = clamp(viewport_pos.x, 0, viewport_size.x)
	viewport_pos.y = clamp(viewport_pos.y, 0, viewport_size.y)
	
	# 创建从摄像机发出的射线
	# 重要：project_ray_origin 和 project_ray_normal 使用的是相对于摄像机所在 Viewport 的坐标
	# 由于摄像机在 SubViewport 中，所以坐标应该是相对于 SubViewport 的
	# 
	# 但是，当 SubViewport 在容器中居中显示时，坐标系统可能不一致
	# 我们需要确保传递给 project_ray_origin 的坐标是相对于 SubViewport 的
	# 
	# 尝试：确保坐标是相对于 SubViewport 的（0,0 到 viewport_size）
	# 注意：viewport_pos 已经是相对于 SubViewport 的坐标了
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	
	# 如果坐标系统不一致，可能需要调整
	# 但是，由于摄像机在 SubViewport 中，project_ray_origin 应该使用 SubViewport 的坐标
	# 所以这里应该没问题
	
	# 调试：输出视口大小和坐标，确保坐标系统一致
	print("射线计算: 视口大小=", viewport_size, " | 坐标=", viewport_pos, " | 坐标比例=(", viewport_pos.x / viewport_size.x, ", ", viewport_pos.y / viewport_size.y, ")")
	
	print("射线起点: ", from, " | 射线方向: ", ray_dir)
	
	# 射线与Y=0平面相交（地图平面）
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	
	var denom = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		print("警告: 射线与平面平行")
		return  # 射线与平面平行
	
	var t = (plane_point - from).dot(plane_normal) / denom
	if t < 0:
		print("警告: 射线方向错误, t=", t)
		return  # 射线方向错误
	
	var world_pos = from + ray_dir * t
	print("射线与地面交点: ", world_pos)
	
	# 将世界坐标转换为六边形坐标
	var hex_coord = HexGrid.world_to_hex(world_pos, game_map.hex_size, game_map.map_height)
	
	# 检查坐标是否有效
	if game_map._is_valid_hex(hex_coord):
		print("点击了六边形坐标: ", hex_coord)
		hex_clicked.emit(hex_coord)
	else:
		print("无效的六边形坐标: ", hex_coord)

func _handle_click(screen_pos: Vector2):
	if not camera or not game_map or not sub_viewport:
		return
	
	# 获取SubViewportContainer（父节点）
	var container = sub_viewport.get_parent() as SubViewportContainer
	if not container:
		return
	
	# 使用get_global_rect()获取容器的全局矩形
	var container_global_rect = container.get_global_rect()
	
	# 检查点击是否在容器内
	if not container_global_rect.has_point(screen_pos):
		return
	
	# 将全局屏幕坐标转换为容器内的局部坐标
	var local_pos = screen_pos - container_global_rect.position
	
	# 获取SubViewport的固定尺寸和容器的实际尺寸
	var viewport_size = Vector2(sub_viewport.size)  # 固定为 1920x1080
	var container_size = container_global_rect.size
	
	# 当 stretch = false 时，SubViewport 以固定大小显示
	# 计算 SubViewport 在容器中的实际显示区域
	var viewport_pos: Vector2
	
	# 使用 SubViewportContainer 的 stretch_mode 来计算实际显示区域
	# 当 stretch = false 时，SubViewport 会以原始大小显示，可能居中
	# 计算缩放和偏移
	var scale_factor: float = 1.0
	var offset_x: float = 0.0
	var offset_y: float = 0.0
	
	if container.stretch:
		# stretch = true 时，会拉伸填充
		scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale_factor
		var scaled_height = viewport_size.y * scale_factor
		offset_x = (container_size.x - scaled_width) / 2.0
		offset_y = (container_size.y - scaled_height) / 2.0
		viewport_pos.x = (local_pos.x - offset_x) / scale_factor
		viewport_pos.y = (local_pos.y - offset_y) / scale_factor
	else:
		# stretch = false 时，以原始大小显示，居中
		offset_x = (container_size.x - viewport_size.x) / 2.0
		offset_y = (container_size.y - viewport_size.y) / 2.0
		viewport_pos.x = local_pos.x - offset_x
		viewport_pos.y = local_pos.y - offset_y
	
	# 确保坐标在SubViewport范围内
	viewport_pos.x = clamp(viewport_pos.x, 0, viewport_size.x)
	viewport_pos.y = clamp(viewport_pos.y, 0, viewport_size.y)
	
	# 调试输出
	print("屏幕坐标: ", screen_pos, " | 容器局部: ", local_pos, " | SubViewport坐标: ", viewport_pos, " | 容器大小: ", container_size, " | 视口大小: ", viewport_size, " | 偏移: (", offset_x, ", ", offset_y, ")")
	
	# 调试输出（可以注释掉）
	# print("屏幕坐标: ", screen_pos, " | 容器局部: ", local_pos, " | SubViewport坐标: ", viewport_pos)
	
	# 创建从摄像机发出的射线
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	
	# 射线与Y=0平面相交（地图平面）
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	
	var denom = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		return  # 射线与平面平行
	
	var t = (plane_point - from).dot(plane_normal) / denom
	if t < 0:
		return  # 射线方向错误
	
	var world_pos = from + ray_dir * t
	
	# 将世界坐标转换为六边形坐标
	var hex_coord = HexGrid.world_to_hex(world_pos, game_map.hex_size, game_map.map_height)
	
	# 检查坐标是否有效
	if game_map._is_valid_hex(hex_coord):
		print("点击了六边形坐标: ", hex_coord)
		hex_clicked.emit(hex_coord)
