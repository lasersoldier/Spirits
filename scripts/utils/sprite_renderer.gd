class_name SpriteRenderer
extends Node3D

# 精灵渲染器：用于在3D场景中渲染精灵

var sprite_nodes: Dictionary = {}  # key: sprite实例, value: MeshInstance3D
var sprite_tweens: Dictionary = {}  # key: sprite实例, value: Tween（用于移动动画）
var sprite_connections: Dictionary = {}  # key: sprite实例, value: Callable（用于追踪和断开信号连接）
var game_map: GameMap  # 地图引用，用于获取地图参数

# 移动动画时长（秒）
var move_animation_duration: float = 0.3

func _init():
	pass

# 渲染精灵
func render_sprite(sprite: Sprite):
	if sprite_nodes.has(sprite):
		_update_sprite_position(sprite)
		return
	
	# 创建新的精灵节点
	var mesh_instance = MeshInstance3D.new()
	
	# 根据精灵属性生成网格
	var mesh = _get_sprite_mesh(sprite.attribute)
	mesh_instance.mesh = mesh
	
	# 设置材质
	var material = _create_sprite_material(sprite.attribute)
	mesh_instance.material_override = material
	
	# 设置位置
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	# 将精灵放在地形上方
	world_pos.y = 0.5  # 稍微抬高一点，避免与地形重叠
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	sprite_nodes[sprite] = mesh_instance
	
	# 连接精灵的移动信号（信号已经包含sprite作为第一个参数，不需要绑定）
	if not sprite_connections.has(sprite):
		sprite.sprite_moved.connect(_on_sprite_moved)
		sprite_connections[sprite] = _on_sprite_moved

# 更新精灵位置（立即更新，无动画）
func _update_sprite_position(sprite: Sprite):
	if not sprite_nodes.has(sprite):
		return
	
	var mesh_instance = sprite_nodes[sprite]
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	world_pos.y = 0.5  # 稍微抬高一点
	mesh_instance.position = world_pos
	
	# 如果正在移动，停止之前的动画
	if sprite_tweens.has(sprite):
		var tween = sprite_tweens[sprite]
		if tween:
			tween.kill()
		sprite_tweens.erase(sprite)

# 处理精灵移动信号（带平滑动画）
func _on_sprite_moved(sprite: Sprite, from: Vector2i, to: Vector2i):
	print("SpriteRenderer: 收到移动信号 - ", sprite.sprite_name, " 从 ", from, " 移动到 ", to)
	
	if not sprite_nodes.has(sprite):
		print("SpriteRenderer: 警告 - 精灵节点不存在，无法更新位置")
		return
	
	var mesh_instance = sprite_nodes[sprite]
	print("SpriteRenderer: 开始更新精灵位置")
	
	# 停止之前的移动动画（如果有）
	if sprite_tweens.has(sprite):
		var old_tween = sprite_tweens[sprite]
		if old_tween:
			old_tween.kill()
	
	# 计算目标世界坐标
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var target_pos = HexGrid.hex_to_world(to, hex_size, map_height, map_width)
	target_pos.y = 0.5  # 稍微抬高一点
	
	# 获取起始位置
	var start_pos = mesh_instance.position
	var start_y = start_pos.y
	var peak_y = start_y + 0.3  # 跳跃高度
	var end_y = target_pos.y
	
	# 创建新的移动动画（使用并行动画实现跳跃效果）
	var tween = create_tween()
	tween.set_parallel(true)  # 启用并行模式，可以同时动画多个属性
	
	# 水平移动（XZ平面）
	var horizontal_target = Vector3(target_pos.x, start_y, target_pos.z)
	tween.tween_property(mesh_instance, "position:x", target_pos.x, move_animation_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mesh_instance, "position:z", target_pos.z, move_animation_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 垂直跳跃（Y轴）- 先上升后下降
	tween.tween_property(mesh_instance, "position:y", peak_y, move_animation_duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mesh_instance, "position:y", end_y, move_animation_duration * 0.5).set_delay(move_animation_duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# 存储 tween 以便后续可以停止
	sprite_tweens[sprite] = tween
	
	# 动画完成后清理
	tween.finished.connect(func(): 
		sprite_tweens.erase(sprite)
	)

# 移除精灵
func remove_sprite(sprite: Sprite):
	# 停止移动动画（如果有）
	if sprite_tweens.has(sprite):
		var tween = sprite_tweens[sprite]
		if tween:
			tween.kill()
		sprite_tweens.erase(sprite)
	
	# 断开信号连接
	if sprite_connections.has(sprite):
		var callable = sprite_connections[sprite]
		if sprite.sprite_moved.is_connected(callable):
			sprite.sprite_moved.disconnect(callable)
		sprite_connections.erase(sprite)
	
	# 移除节点
	if sprite_nodes.has(sprite):
		var node = sprite_nodes[sprite]
		node.queue_free()
		sprite_nodes.erase(sprite)

# 获取精灵网格
func _get_sprite_mesh(attribute: String) -> ArrayMesh:
	match attribute:
		"fire":
			return ModelGenerator.create_sprite_mesh_fire()
		"wind":
			return ModelGenerator.create_sprite_mesh_wind()
		"water":
			return ModelGenerator.create_sprite_mesh_water()
		"rock":
			return ModelGenerator.create_sprite_mesh_rock()
		_:
			return ModelGenerator.create_box_mesh(0.5, 0.5, 0.5)

# 创建精灵材质
func _create_sprite_material(attribute: String) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	match attribute:
		"fire":
			material.albedo_color = Color(1.0, 0.5, 0.0)  # 橙红色
		"wind":
			material.albedo_color = Color(0.5, 0.8, 1.0)  # 浅蓝色
		"water":
			material.albedo_color = Color(0.0, 0.2, 0.8)  # 深蓝色
		"rock":
			material.albedo_color = Color(0.4, 0.4, 0.4)  # 深灰色
	
	material.metallic = 0.1
	material.roughness = 0.7
	
	return material

