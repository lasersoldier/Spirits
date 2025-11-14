class_name MapClickHandler
extends Node

# 地图点击处理器：将鼠标点击转换为六边形坐标

var game_map: GameMap
var camera: Camera3D
var sub_viewport: SubViewport
var container: SubViewportContainer  # 缓存容器引用，避免重复获取

signal hex_clicked(hex_coord: Vector2i)

func _init(map: GameMap, cam: Camera3D, viewport: SubViewport):
	game_map = map
	camera = cam
	sub_viewport = viewport
	# 初始化时获取容器引用（假设SubViewport的父节点一定是SubViewportContainer）
	container = sub_viewport.get_parent() as SubViewportContainer

func _ready():
	set_process_input(true)
	# 监听视口大小变化，分辨率改变时触发重新计算
	get_viewport().connect("size_changed", _on_viewport_resized)

func _on_viewport_resized():
	# 可选：分辨率变化时可添加调试信息或强制刷新逻辑
	print("屏幕分辨率变化: ", get_viewport().size)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sub_viewport and container:
			var main_viewport = get_viewport()
			var global_mouse = main_viewport.get_mouse_position()
			# 直接通过统一的坐标转换逻辑处理，不再区分是否在视口内（后续逻辑会判断）
			var viewport_pos = _convert_global_to_viewport_pos(global_mouse)
			# 检查是否为有效坐标（无效坐标返回 Vector2(-1, -1)）
			if viewport_pos.x >= 0 and viewport_pos.y >= 0:
				_handle_click_in_viewport(viewport_pos)

# 核心优化：统一全局坐标到SubViewport坐标的转换逻辑
func _convert_global_to_viewport_pos(global_mouse: Vector2) -> Vector2:
	if not container or not sub_viewport:
		return Vector2(-1, -1)  # 返回无效坐标
	
	# 获取容器的全局矩形（包含位置和大小）
	var container_rect = container.get_global_rect()
	# 检查鼠标是否在容器范围内（不在则返回无效）
	if not container_rect.has_point(global_mouse):
		return Vector2(-1, -1)  # 返回无效坐标
	
	# 1. 转换为容器的局部坐标（相对于容器左上角）
	var local_in_container = global_mouse - container_rect.position
	
	# 2. 获取容器和SubViewport的尺寸
	var container_size = container_rect.size
	var viewport_size = Vector2(sub_viewport.size)  # SubViewport的实际渲染尺寸（转换为Vector2）
	
	# 3. 处理缩放和偏移（关键适配逻辑）
	var scale = Vector2(1, 1)
	var offset = Vector2(0, 0)
	
	if container.stretch:
		# 拉伸模式：保持宽高比，计算缩放比例
		# 注意：当 SubViewport 尺寸与容器同步时，viewport_size 应该等于 container_size
		# 但如果启用了 stretch_aspect=KEEP，可能会有缩放和偏移
		if viewport_size.x > 0 and viewport_size.y > 0:
			var scale_x = container_size.x / viewport_size.x
			var scale_y = container_size.y / viewport_size.y
			# 取最小缩放比例（避免拉伸变形，Godot默认行为）
			var min_scale = min(scale_x, scale_y)
			scale = Vector2(min_scale, min_scale)
			# 计算居中偏移（容器与缩放后视口的差距）
			var scaled_viewport_size = viewport_size * scale
			offset = (container_size - scaled_viewport_size) / 2
		else:
			# 如果视口尺寸无效，直接使用容器坐标
			return local_in_container
	else:
		# 非拉伸模式：SubViewport以原始尺寸显示，居中对齐
		offset = (container_size - viewport_size) / 2
		# 若容器小于视口，偏移为0（从左上角开始显示）
		offset.x = max(0, offset.x)
		offset.y = max(0, offset.y)
	
	# 4. 转换为SubViewport内部坐标（修正偏移并除以缩放）
	var local_in_viewport = (local_in_container - offset) / scale
	# 限制坐标在SubViewport范围内（避免越界）
	local_in_viewport.x = clamp(local_in_viewport.x, 0, viewport_size.x)
	local_in_viewport.y = clamp(local_in_viewport.y, 0, viewport_size.y)
	
	return local_in_viewport

func _handle_click_in_viewport(viewport_pos: Vector2):
	if not camera or not game_map:
		return
	
	# 生成射线（使用SubViewport坐标，与摄像机所在视口匹配）
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	
	# 射线与地图平面（Y=0）相交计算
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	var denom = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		print("射线与地图平面平行")
		return
	var t = (plane_point - from).dot(plane_normal) / denom
	if t < 0:
		print("射线方向错误（指向摄像机后方）")
		return
	
	# 计算交点并转换为六边形坐标
	var world_pos = from + ray_dir * t
	var hex_coord = HexGrid.world_to_hex(world_pos, game_map.hex_size, game_map.map_height)
	
	if game_map._is_valid_hex(hex_coord):
		print("有效点击：", hex_coord)
		hex_clicked.emit(hex_coord)
	else:
		print("无效坐标：", hex_coord)
