class_name ActionArrowManager
extends Control

# 游戏管理器引用
var game_manager: GameManager = null

# 主UI引用（用于获取地图视口）
var main_ui: MainUI = null

# 箭头容器（3D场景中的节点）
var arrow_container_3d: Node3D = null

# UI容器（用于取消按钮和卡牌预览）
var arrow_container_ui: Control = null

# 存储每个行动对应的箭头数据
# key: Action对象, value: Dictionary { "line": MeshInstance3D, "arrow_head": MeshInstance3D, "cancel_button": Button, "card_preview": Control }
var action_arrows: Dictionary = {}

# 当前悬停的箭头
var hovered_arrow_action: ActionResolver.Action = null

# 卡牌预览场景
const CARD_PREVIEW_SCENE := preload("res://scenes/ui/card_preview.tscn")
var current_card_preview: Control = null

# 箭头样式常量
const STRAIGHT_ARROW_COLOR := Color(0.2, 0.8, 1.0, 0.8)  # 蓝色（移动）
const PARABOLIC_ARROW_COLOR := Color(1.0, 0.4, 0.2, 0.8)  # 橙色（攻击/效果）
const ARROW_WIDTH := 4.0
const ARROW_HEAD_SIZE := 12.0
const HOVER_DETECTION_THRESHOLD := 15.0  # 像素

func _ready():
	# 创建UI容器（用于取消按钮和卡牌预览）
	arrow_container_ui = Control.new()
	arrow_container_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrow_container_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow_container_ui)
	
	# 设置处理模式用于悬停检测
	set_process(true)

# 初始化3D箭头容器（需要在地图视口初始化后调用）
func _init_3d_container():
	if not main_ui:
		return
	
	var map_viewport = main_ui.get_node_or_null("MapViewport") as SubViewportContainer
	if not map_viewport:
		return
	
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return
	
	var world = sub_viewport.get_node_or_null("World") as Node3D
	if not world:
		return
	
	# 创建3D箭头容器
	if not arrow_container_3d:
		arrow_container_3d = Node3D.new()
		arrow_container_3d.name = "ActionArrows"
		world.add_child(arrow_container_3d)

# 设置游戏管理器引用
func set_game_manager(gm: GameManager):
	game_manager = gm

# 设置主UI引用
func set_main_ui(ui: MainUI):
	main_ui = ui
	# 延迟初始化3D容器，确保场景树已构建
	call_deferred("_init_3d_container")

# 更新所有箭头（根据行动预览列表）
func update_arrows(previews: Array[Dictionary]):
	# 确保3D容器已初始化
	if not arrow_container_3d:
		_init_3d_container()
		if not arrow_container_3d:
			return  # 如果初始化失败，无法创建箭头
	
	# 获取当前所有行动
	var current_actions: Array[ActionResolver.Action] = []
	for preview in previews:
		if preview.has("action") and preview.action:
			current_actions.append(preview.action)
	
	# 移除不存在的箭头
	var actions_to_remove: Array[ActionResolver.Action] = []
	for action in action_arrows.keys():
		if action not in current_actions:
			actions_to_remove.append(action)
	
	for action in actions_to_remove:
		_remove_arrow(action)
	
	# 添加或更新箭头
	for preview in previews:
		if preview.has("action") and preview.action:
			var action = preview.action as ActionResolver.Action
			if not action_arrows.has(action):
				_create_arrow(action)
			else:
				_update_arrow(action)

# 创建箭头
func _create_arrow(action: ActionResolver.Action):
	if not action or not action.sprite or not arrow_container_3d:
		return
	
	# 获取起点和终点的世界坐标
	var start_pos_3d = _get_sprite_world_position(action.sprite)
	var end_pos_3d = _get_target_world_position(action)
	
	if start_pos_3d == Vector3(-1, -1, -1) or end_pos_3d == Vector3(-1, -1, -1):
		return
	
	# 判断箭头类型
	var is_move = action.action_type == ActionResolver.ActionType.MOVE
	var arrow_data = {}
	
	# 创建3D箭头线条
	var line_mesh = _create_3d_line_mesh(start_pos_3d, end_pos_3d, is_move)
	arrow_container_3d.add_child(line_mesh)
	arrow_data["line"] = line_mesh
	
	# 创建箭头头部（3D）
	var arrow_head = _create_3d_arrow_head(end_pos_3d, start_pos_3d, is_move)
	arrow_container_3d.add_child(arrow_head)
	arrow_data["arrow_head"] = arrow_head
	
	# 创建取消按钮（UI元素，初始隐藏）
	var cancel_button = Button.new()
	cancel_button.text = "X"
	cancel_button.visible = false
	cancel_button.custom_minimum_size = Vector2(30, 30)
	cancel_button.pressed.connect(func(): _on_cancel_button_pressed(action))
	arrow_container_ui.add_child(cancel_button)
	arrow_data["cancel_button"] = cancel_button
	
	# 存储箭头数据
	arrow_data["action"] = action
	action_arrows[action] = arrow_data

# 更新箭头位置（当精灵或目标移动时）
func _update_arrow(action: ActionResolver.Action):
	if not action_arrows.has(action) or not arrow_container_3d:
		return
	
	var arrow_data = action_arrows[action]
	var start_pos_3d = _get_sprite_world_position(action.sprite)
	var end_pos_3d = _get_target_world_position(action)
	
	if start_pos_3d == Vector3(-1, -1, -1) or end_pos_3d == Vector3(-1, -1, -1):
		return
	
	# 移除旧的线条并创建新的
	var old_line = arrow_data.get("line") as MeshInstance3D
	if old_line:
		old_line.queue_free()
	
	var is_move = action.action_type == ActionResolver.ActionType.MOVE
	var new_line = _create_3d_line_mesh(start_pos_3d, end_pos_3d, is_move)
	arrow_container_3d.add_child(new_line)
	arrow_data["line"] = new_line
	
	# 更新箭头头部位置和方向
	var arrow_head = arrow_data.get("arrow_head") as MeshInstance3D
	if arrow_head:
		# 计算方向（使用上面已声明的is_move变量）
		var direction: Vector3
		if is_move:
			# 直线：从起点指向终点
			direction = (end_pos_3d - start_pos_3d).normalized()
		else:
			# 抛物线：使用终点处的切线方向
			direction = _get_parabolic_tangent_at_end(start_pos_3d, end_pos_3d)
		
		if direction.length() > 0.001:
			# 将箭头放在终点位置，但稍微后退一点，让尖头正好在终点
			var arrow_mesh = arrow_head.mesh as CylinderMesh
			var arrow_height = arrow_mesh.height if arrow_mesh else 0.8
			var arrow_base_pos = end_pos_3d - direction * (arrow_height * 0.5)
			arrow_head.position = arrow_base_pos
			
			# 让圆锥沿着direction方向
			var y_axis = direction  # Y轴沿着方向（尖头在+Y方向）
			
			# 计算垂直于direction的X轴
			var x_axis: Vector3
			if abs(direction.dot(Vector3.UP)) < 0.9:
				x_axis = direction.cross(Vector3.UP).normalized()
			else:
				x_axis = direction.cross(Vector3.RIGHT).normalized()
			
			# Z轴 = X × Y
			var z_axis = x_axis.cross(y_axis).normalized()
			
			# 设置Basis
			arrow_head.basis = Basis(x_axis, y_axis, z_axis)
		else:
			arrow_head.position = end_pos_3d

# 移除箭头
func _remove_arrow(action: ActionResolver.Action):
	if not action_arrows.has(action):
		return
	
	var arrow_data = action_arrows[action]
	
	# 移除所有节点
	if arrow_data.has("line"):
		var line = arrow_data["line"] as MeshInstance3D
		if line and is_instance_valid(line):
			line.queue_free()
	
	if arrow_data.has("arrow_head"):
		var arrow_head = arrow_data["arrow_head"] as MeshInstance3D
		if arrow_head and is_instance_valid(arrow_head):
			arrow_head.queue_free()
	
	if arrow_data.has("cancel_button"):
		var button = arrow_data["cancel_button"] as Button
		if button and is_instance_valid(button):
			button.queue_free()
	
	# 如果当前悬停的是这个箭头，清除悬停状态
	if hovered_arrow_action == action:
		hovered_arrow_action = null
		if current_card_preview:
			current_card_preview.queue_free()
			current_card_preview = null
	
	action_arrows.erase(action)

# 清除所有箭头
func clear_all_arrows():
	var actions_to_remove: Array[ActionResolver.Action] = []
	for action in action_arrows.keys():
		actions_to_remove.append(action)
	
	for action in actions_to_remove:
		_remove_arrow(action)

# 获取地形高度（与TerrainRenderer保持一致）
func _get_height_for_level(level: int) -> float:
	match level:
		1:
			return 3.0  # 1级地形高度
		2:
			return 6.0  # 2级地形高度
		3:
			return 12.0  # 3级地形高度
		_:
			return 3.0

# 获取精灵的世界坐标
func _get_sprite_world_position(sprite: Sprite) -> Vector3:
	if not game_manager or not game_manager.game_map:
		return Vector3(-1, -1, -1)
	
	var hex_size = game_manager.game_map.hex_size
	var map_height = game_manager.game_map.map_height
	var map_width = game_manager.game_map.map_width
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	
	# 获取地形高度
	var terrain = game_manager.game_map.get_terrain(sprite.hex_position)
	var terrain_height = 3.0  # 默认高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	
	world_pos.y = terrain_height + 0.5  # 精灵脚底高度
	return world_pos

# 获取目标的世界坐标
func _get_target_world_position(action: ActionResolver.Action) -> Vector3:
	if not action:
		return Vector3(-1, -1, -1)
	
	# 如果目标是精灵
	if action.target is Sprite:
		return _get_sprite_world_position(action.target as Sprite)
	
	# 如果目标是位置（Vector2i）
	if action.target is Vector2i:
		return _get_hex_world_position(action.target as Vector2i)
	
	return Vector3(-1, -1, -1)

# 获取六边形的世界坐标
func _get_hex_world_position(hex_coord: Vector2i) -> Vector3:
	if not game_manager or not game_manager.game_map:
		return Vector3(-1, -1, -1)
	
	var hex_size = game_manager.game_map.hex_size
	var map_height = game_manager.game_map.map_height
	var map_width = game_manager.game_map.map_width
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	
	# 获取地形高度
	var terrain = game_manager.game_map.get_terrain(hex_coord)
	var terrain_height = 3.0  # 默认高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	
	world_pos.y = terrain_height  # 地形顶部
	return world_pos

# 获取精灵的屏幕坐标（用于UI元素定位）
func _get_sprite_screen_position(sprite: Sprite) -> Vector2:
	if not game_manager or not game_manager.game_map or not main_ui:
		return Vector2(-1, -1)
	
	var map_viewport = main_ui.get_node_or_null("MapViewport") as SubViewportContainer
	if not map_viewport:
		return Vector2(-1, -1)
	
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return Vector2(-1, -1)
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return Vector2(-1, -1)
	
	# 将精灵的世界坐标转换为屏幕坐标
	var hex_size = game_manager.game_map.hex_size
	var map_height = game_manager.game_map.map_height
	var map_width = game_manager.game_map.map_width
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	world_pos.y = 0.5  # 精灵脚底高度
	
	# 将3D世界坐标转换为2D屏幕坐标
	var viewport_pos = camera.unproject_position(world_pos)
	
	# 转换为全局屏幕坐标
	var container_rect = map_viewport.get_global_rect()
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	var screen_pos: Vector2
	if map_viewport.stretch:
		var scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale_factor
		var scaled_height = viewport_size.y * scale_factor
		var offset_x = (container_size.x - scaled_width) / 2.0
		var offset_y = (container_size.y - scaled_height) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x * scale_factor
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y * scale_factor
	else:
		var offset_x = (container_size.x - viewport_size.x) / 2.0
		var offset_y = (container_size.y - viewport_size.y) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y
	
	return screen_pos

# 获取目标的屏幕坐标
func _get_target_screen_position(action: ActionResolver.Action) -> Vector2:
	if not action:
		return Vector2(-1, -1)
	
	# 如果目标是精灵
	if action.target is Sprite:
		return _get_sprite_screen_position(action.target as Sprite)
	
	# 如果目标是位置（Vector2i）
	if action.target is Vector2i:
		return _get_hex_screen_position(action.target as Vector2i)
	
	return Vector2(-1, -1)

# 获取六边形的屏幕坐标
func _get_hex_screen_position(hex_coord: Vector2i) -> Vector2:
	if not game_manager or not game_manager.game_map or not main_ui:
		return Vector2(-1, -1)
	
	var map_viewport = main_ui.get_node_or_null("MapViewport") as SubViewportContainer
	if not map_viewport:
		return Vector2(-1, -1)
	
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return Vector2(-1, -1)
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return Vector2(-1, -1)
	
	# 获取地形高度
	var terrain = game_manager.game_map.get_terrain(hex_coord)
	var terrain_height = 3.0  # 默认高度
	if terrain:
		# 根据地形高度级别计算实际高度
		terrain_height = terrain.height_level * 3.0
	
	# 将六边形坐标转换为世界坐标
	var hex_size = game_manager.game_map.hex_size
	var map_height = game_manager.game_map.map_height
	var map_width = game_manager.game_map.map_width
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	world_pos.y = terrain_height  # 地形顶部
	
	# 将3D世界坐标转换为2D屏幕坐标
	var viewport_pos = camera.unproject_position(world_pos)
	
	# 转换为全局屏幕坐标
	var container_rect = map_viewport.get_global_rect()
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	var screen_pos: Vector2
	if map_viewport.stretch:
		var scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale_factor
		var scaled_height = viewport_size.y * scale_factor
		var offset_x = (container_size.x - scaled_width) / 2.0
		var offset_y = (container_size.y - scaled_height) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x * scale_factor
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y * scale_factor
	else:
		var offset_x = (container_size.x - viewport_size.x) / 2.0
		var offset_y = (container_size.y - viewport_size.y) / 2.0
		screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x
		screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y
	
	return screen_pos

# 创建3D线条mesh
func _create_3d_line_mesh(start: Vector3, end: Vector3, is_straight: bool) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	
	# 生成顶点数组
	var vertices = PackedVector3Array()
	
	if is_straight:
		# 直线
		vertices.append(start)
		vertices.append(end)
	else:
		# 抛物线
		var points = _calculate_parabolic_points_3d(start, end)
		for point in points:
			vertices.append(point)
	
	# 创建表面
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	
	# 创建材质
	var material = StandardMaterial3D.new()
	if is_straight:
		material.albedo_color = STRAIGHT_ARROW_COLOR
	else:
		material.albedo_color = PARABOLIC_ARROW_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = material
	return mesh_instance

# 计算3D抛物线点
func _calculate_parabolic_points_3d(start: Vector3, end: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var distance = start.distance_to(end)
	var height = distance * 0.3  # 根据距离自动调整弧度
	
	# 使用二次贝塞尔曲线
	var control_point = (start + end) / 2.0
	control_point.y += height  # 向上偏移作为控制点（3D中Y是高度）
	
	# 生成曲线点
	var num_points = max(20, int(distance / 0.5))  # 根据距离调整点数
	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var point = _bezier_quadratic_3d(start, control_point, end, t)
		points.append(point)
	
	return points

# 二次贝塞尔曲线计算（3D）
func _bezier_quadratic_3d(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u = 1.0 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2

# 计算抛物线在终点处的切线方向
func _get_parabolic_tangent_at_end(start: Vector3, end: Vector3) -> Vector3:
	var distance = start.distance_to(end)
	var height = distance * 0.3
	var control_point = (start + end) / 2.0
	control_point.y += height
	
	# 对于二次贝塞尔曲线 B(t) = (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
	# 在终点 t=1 处的切线方向是：B'(1) = 2(P₂ - P₁)
	# 即 2(end - control_point)
	var tangent = 2.0 * (end - control_point)
	return tangent.normalized()

# 创建3D箭头头部
func _create_3d_arrow_head(position: Vector3, from: Vector3, is_straight: bool) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	# 使用CylinderMesh，设置top_radius为0来创建圆锥
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.4
	arrow_mesh.height = 0.8
	
	var material = StandardMaterial3D.new()
	if is_straight:
		material.albedo_color = STRAIGHT_ARROW_COLOR
	else:
		material.albedo_color = PARABOLIC_ARROW_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mesh_instance.mesh = arrow_mesh
	mesh_instance.material_override = material
	
	# 计算方向
	var direction: Vector3
	if is_straight:
		# 直线：从起点指向终点
		direction = (position - from).normalized()
	else:
		# 抛物线：使用终点处的切线方向
		direction = _get_parabolic_tangent_at_end(from, position)
	
	if direction.length() > 0.001:
		# 将箭头放在终点位置，但稍微后退一点，让尖头正好在终点
		var arrow_base_pos = position - direction * (arrow_mesh.height * 0.5)
		mesh_instance.position = arrow_base_pos
		
		# 让圆锥沿着direction方向
		# CylinderMesh默认Y轴向上，我们需要让Y轴沿着direction方向
		# 使用Basis直接设置方向：Y轴沿着direction，X和Z轴垂直于direction
		var y_axis = direction  # Y轴沿着方向（尖头在+Y方向）
		
		# 计算垂直于direction的X轴
		var x_axis: Vector3
		if abs(direction.dot(Vector3.UP)) < 0.9:
			x_axis = direction.cross(Vector3.UP).normalized()
		else:
			x_axis = direction.cross(Vector3.RIGHT).normalized()
		
		# Z轴 = X × Y
		var z_axis = x_axis.cross(y_axis).normalized()
		
		# 设置Basis（注意：由于尖头在+Y方向，我们需要让+Y指向目标）
		mesh_instance.basis = Basis(x_axis, y_axis, z_axis)
	else:
		mesh_instance.position = position
	
	return mesh_instance

# 处理取消按钮点击
func _on_cancel_button_pressed(action: ActionResolver.Action):
	if not game_manager:
		return
	
	var result = game_manager.cancel_action(action)
	if result.success:
		# 箭头会在 _update_action_preview 中被移除，这里不需要手动移除
		# 通知主UI更新（这会触发 update_arrows，自动移除箭头）
		if main_ui:
			main_ui._update_action_preview()

# 处理函数：检测悬停
func _process(_delta):
	if not game_manager:
		return
	
	var mouse_pos = get_global_mouse_position()
	var closest_action: ActionResolver.Action = null
	var closest_distance = HOVER_DETECTION_THRESHOLD
	
	# 检测所有箭头
	for action in action_arrows.keys():
		var distance = _get_distance_to_arrow(mouse_pos, action)
		if distance < closest_distance:
			closest_distance = distance
			closest_action = action
	
	# 更新悬停状态
	if closest_action != hovered_arrow_action:
		# 清除之前的悬停
		if hovered_arrow_action and action_arrows.has(hovered_arrow_action):
			_hide_hover_ui(hovered_arrow_action)
		
		# 设置新的悬停
		hovered_arrow_action = closest_action
		if hovered_arrow_action:
			_show_hover_ui(hovered_arrow_action, mouse_pos)

# 获取鼠标到箭头的距离（通过3D到2D投影）
func _get_distance_to_arrow(mouse_pos: Vector2, action: ActionResolver.Action) -> float:
	if not action_arrows.has(action) or not main_ui:
		return INF
	
	var arrow_data = action_arrows[action]
	var line = arrow_data.get("line") as MeshInstance3D
	if not line:
		return INF
	
	# 获取3D箭头路径的点（从mesh中提取或重新计算）
	var start_pos_3d = _get_sprite_world_position(action.sprite)
	var end_pos_3d = _get_target_world_position(action)
	
	if start_pos_3d == Vector3(-1, -1, -1) or end_pos_3d == Vector3(-1, -1, -1):
		return INF
	
	# 获取相机用于投影
	var map_viewport = main_ui.get_node_or_null("MapViewport") as SubViewportContainer
	if not map_viewport:
		return INF
	
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return INF
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return INF
	
	# 生成路径点并投影到屏幕
	var is_move = action.action_type == ActionResolver.ActionType.MOVE
	var points_3d: Array[Vector3] = []
	
	if is_move:
		points_3d = [start_pos_3d, end_pos_3d]
	else:
		points_3d = _calculate_parabolic_points_3d(start_pos_3d, end_pos_3d)
	
	# 将3D点投影到屏幕坐标
	var points_2d: Array[Vector2] = []
	for point_3d in points_3d:
		var viewport_pos = camera.unproject_position(point_3d)
		var container_rect = map_viewport.get_global_rect()
		var viewport_size = Vector2(sub_viewport.size)
		var container_size = container_rect.size
		
		var screen_pos: Vector2
		if map_viewport.stretch:
			var scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
			var scaled_width = viewport_size.x * scale_factor
			var scaled_height = viewport_size.y * scale_factor
			var offset_x = (container_size.x - scaled_width) / 2.0
			var offset_y = (container_size.y - scaled_height) / 2.0
			screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x * scale_factor
			screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y * scale_factor
		else:
			var offset_x = (container_size.x - viewport_size.x) / 2.0
			var offset_y = (container_size.y - viewport_size.y) / 2.0
			screen_pos.x = container_rect.position.x + offset_x + viewport_pos.x
			screen_pos.y = container_rect.position.y + offset_y + viewport_pos.y
		
		points_2d.append(screen_pos)
	
	# 计算到路径的最短距离
	var min_distance = INF
	for i in range(points_2d.size() - 1):
		var segment_start = points_2d[i]
		var segment_end = points_2d[i + 1]
		var distance = _point_to_segment_distance(mouse_pos, segment_start, segment_end)
		min_distance = min(min_distance, distance)
	
	return min_distance

# 计算点到线段的距离
func _point_to_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg_vec = seg_end - seg_start
	var point_vec = point - seg_start
	var seg_length_sq = seg_vec.length_squared()
	
	if seg_length_sq < 0.0001:
		return point.distance_to(seg_start)
	
	var t = clamp(point_vec.dot(seg_vec) / seg_length_sq, 0.0, 1.0)
	var projection = seg_start + t * seg_vec
	return point.distance_to(projection)

# 显示悬停UI
func _show_hover_ui(action: ActionResolver.Action, mouse_pos: Vector2):
	if not action_arrows.has(action):
		return
	
	var arrow_data = action_arrows[action]
	
	# 显示取消按钮
	var cancel_button = arrow_data.get("cancel_button") as Button
	if cancel_button:
		# 计算箭头中点位置（使用屏幕坐标）
		var start_pos = _get_sprite_screen_position(action.sprite)
		var end_pos = _get_target_screen_position(action)
		var mid_pos = (start_pos + end_pos) / 2.0
		mid_pos.y -= 40  # 向上偏移
		
		cancel_button.position = mid_pos - cancel_button.size / 2.0
		cancel_button.visible = true
	
	# 如果是攻击/效果行动且有卡牌，显示卡牌预览
	if action.card and (action.action_type == ActionResolver.ActionType.ATTACK or 
						action.action_type == ActionResolver.ActionType.EFFECT):
		if not current_card_preview:
			var preview = CARD_PREVIEW_SCENE.instantiate()
			if preview and preview.has_method("setup"):
				arrow_container_ui.add_child(preview)
				preview.setup(action.card)
				current_card_preview = preview
				
				# 定位预览（在箭头旁边，使用 call_deferred 确保节点已初始化）
				call_deferred("_position_card_preview", preview, mouse_pos)

# 定位卡牌预览
func _position_card_preview(preview: Control, mouse_pos: Vector2):
	if not preview or not is_instance_valid(preview):
		return
	
	var preview_size = preview.size if preview.size != Vector2.ZERO else Vector2(700, 500)
	var preview_pos = mouse_pos + Vector2(20, 0)
	
	# 确保不超出屏幕
	var viewport_size = get_viewport().get_visible_rect().size
	if preview_pos.x + preview_size.x > viewport_size.x:
		preview_pos.x = mouse_pos.x - preview_size.x - 20
	if preview_pos.y + preview_size.y > viewport_size.y:
		preview_pos.y = viewport_size.y - preview_size.y - 10
	
	preview.position = preview_pos

# 隐藏悬停UI
func _hide_hover_ui(action: ActionResolver.Action):
	if not action_arrows.has(action):
		return
	
	var arrow_data = action_arrows[action]
	
	# 隐藏取消按钮
	var cancel_button = arrow_data.get("cancel_button") as Button
	if cancel_button:
		cancel_button.visible = false
	
	# 隐藏卡牌预览
	if current_card_preview:
		current_card_preview.queue_free()
		current_card_preview = null
