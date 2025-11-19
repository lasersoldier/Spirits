class_name SpriteRenderer
extends Node3D

# 精灵渲染器：用于在3D场景中渲染精灵

var sprite_nodes: Dictionary = {}  # key: sprite实例, value: MeshInstance3D
var sprite_tweens: Dictionary = {}  # key: sprite实例, value: Tween（用于移动动画）
var sprite_connections: Dictionary = {}  # key: sprite实例, value: Callable（用于追踪和断开信号连接）
var game_map: GameMap  # 地图引用，用于获取地图参数

# 战争迷雾系统
var fog_of_war_manager: FogOfWarManager = null
var current_player_id: int = -1
var all_sprites: Array[Sprite] = []  # 所有精灵列表（用于可见性检查）

# 分散站位系统
var sprite_hex_indices: Dictionary = {}  # key: sprite实例, value: 在该六边形内的索引（用于计算偏移）
var hex_sprite_groups: Dictionary = {}  # key: hex_coord (String), value: Array[Sprite]（缓存每个位置的精灵列表）

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
	
	# 更新所有精灵的布局（重新计算索引）
	_update_all_sprites_layout()
	
	# 设置位置（包含分散站位偏移）
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	
	# 计算分散站位偏移
	var index_in_hex = sprite_hex_indices.get(sprite, 0)
	var sprites_at_hex = _get_sprites_at_hex(sprite.hex_position)
	var total_in_hex = sprites_at_hex.size()
	var offset = _calculate_sprite_offset(sprite.hex_position, index_in_hex, total_in_hex)
	world_pos += offset
	
	# 将精灵放在地形上方（根据地形高度）
	var terrain = game_map.get_terrain(sprite.hex_position) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_terrain_height_for_level(terrain.height_level)
	# 地形从Y=0开始，顶部在Y=terrain_height，精灵站在地形顶部
	world_pos.y = terrain_height + 0.5  # 地形顶部 + 偏移，让精灵站在地形上
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	sprite_nodes[sprite] = mesh_instance
	
	# 应用迷雾效果
	_update_sprite_fog_visibility(sprite)
	
	# 连接精灵的移动信号（信号已经包含sprite作为第一个参数，不需要绑定）
	if not sprite_connections.has(sprite):
		sprite.sprite_moved.connect(_on_sprite_moved)
		sprite_connections[sprite] = _on_sprite_moved

# 更新精灵位置（立即更新，无动画）
func _update_sprite_position(sprite: Sprite):
	if not sprite_nodes.has(sprite):
		return
	
	var mesh_instance = sprite_nodes[sprite]
	
	# 更新所有精灵的布局（重新计算索引）
	_update_all_sprites_layout()
	
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(sprite.hex_position, hex_size, map_height, map_width)
	
	# 计算分散站位偏移
	var index_in_hex = sprite_hex_indices.get(sprite, 0)
	var sprites_at_hex = _get_sprites_at_hex(sprite.hex_position)
	var total_in_hex = sprites_at_hex.size()
	var offset = _calculate_sprite_offset(sprite.hex_position, index_in_hex, total_in_hex)
	world_pos += offset
	
	# 将精灵放在地形上方（根据地形高度）- 重新获取最新地形信息
	var terrain = game_map.get_terrain(sprite.hex_position) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_terrain_height_for_level(terrain.height_level)
	else:
		push_warning("SpriteRenderer: 精灵 " + sprite.sprite_name + " 在位置 " + str(sprite.hex_position) + " 没有找到地形，使用默认高度")
	# 地形从Y=0开始，顶部在Y=terrain_height，精灵站在地形顶部
	var new_y = terrain_height + 0.5  # 地形顶部 + 偏移，让精灵站在地形上
	world_pos.y = new_y
	mesh_instance.position = world_pos
	
	# 如果正在移动，停止之前的动画
	if sprite_tweens.has(sprite):
		var tween = sprite_tweens[sprite]
		if tween:
			tween.kill()
		sprite_tweens.erase(sprite)
	
	# 更新迷雾可见性（位置改变后）
	_update_sprite_fog_visibility(sprite)

# 处理精灵移动信号（带平滑动画）
func _on_sprite_moved(sprite: Sprite, from: Vector2i, to: Vector2i):
	if not sprite_nodes.has(sprite):
		push_warning("SpriteRenderer: 精灵节点不存在，无法更新位置")
		return
	
	var mesh_instance = sprite_nodes[sprite]
	
	# 停止之前的移动动画（如果有）
	if sprite_tweens.has(sprite):
		var old_tween = sprite_tweens[sprite]
		if old_tween:
			old_tween.kill()
	
	# 更新所有精灵的布局（重新计算索引）
	_update_all_sprites_layout()
	
	# 计算目标世界坐标
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var target_pos = HexGrid.hex_to_world(to, hex_size, map_height, map_width)
	
	# 计算分散站位偏移
	var index_in_hex = sprite_hex_indices.get(sprite, 0)
	var sprites_at_hex = _get_sprites_at_hex(to)
	var total_in_hex = sprites_at_hex.size()
	var offset = _calculate_sprite_offset(to, index_in_hex, total_in_hex)
	target_pos += offset
	
	# 将精灵放在目标地形上方（根据地形高度）
	var terrain = game_map.get_terrain(to) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_terrain_height_for_level(terrain.height_level)
	# 地形从Y=0开始，顶部在Y=terrain_height，精灵站在地形顶部
	target_pos.y = terrain_height + 0.5  # 地形顶部 + 偏移，让精灵站在地形上
	
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
		# 移动完成后更新迷雾可见性
		_update_sprite_fog_visibility(sprite)
		# 移动完成后重新布局所有精灵（确保位置正确）
		_update_all_sprites_layout()
		# 重新获取地形高度并更新所有精灵的位置（地形可能在移动后发生了变化）
		for s in sprite_nodes.keys():
			if s.is_alive:
				_update_sprite_position(s)
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
	
	# 清除索引和缓存
	sprite_hex_indices.erase(sprite)
	# 重新布局所有精灵（移除后需要重新计算位置）
	_update_all_sprites_layout()
	# 更新所有剩余精灵的位置
	for s in sprite_nodes.keys():
		if s.is_alive:
			_update_sprite_position(s)

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

# 获取地形高度（与TerrainRenderer保持一致）
func _get_terrain_height_for_level(level: int) -> float:
	match level:
		1:
			return 3.0  # 1级地形高度
		2:
			return 6.0  # 2级地形高度
		3:
			return 12.0  # 3级地形高度
		_:
			return 3.0

# 设置战争迷雾管理器和当前玩家ID
func set_fog_manager(manager: FogOfWarManager, player_id: int):
	fog_of_war_manager = manager
	current_player_id = player_id
	
	# 连接视野更新信号
	if fog_of_war_manager:
		fog_of_war_manager.vision_updated.connect(_on_vision_updated)
	
	# 更新所有精灵的可见性
	_update_all_sprites_fog_visibility()

# 视野更新处理
func _on_vision_updated(_player_id: int):
	# 只更新当前玩家的视野显示
	if _player_id == current_player_id:
		_update_all_sprites_fog_visibility()

# 更新所有精灵的迷雾可见性
func _update_all_sprites_fog_visibility():
	for sprite in sprite_nodes.keys():
		_update_sprite_fog_visibility(sprite)

# 更新单个精灵的迷雾可见性
func _update_sprite_fog_visibility(sprite: Sprite):
	if not sprite_nodes.has(sprite):
		return
	
	if not fog_of_war_manager or current_player_id < 0:
		# 没有迷雾系统，显示所有精灵
		var mesh_instance = sprite_nodes[sprite]
		mesh_instance.visible = true
		return
	
	var mesh_instance = sprite_nodes[sprite]
	
	# 检查精灵位置是否对当前玩家可见
	# 己方精灵始终可见，敌方精灵只有在视野内才可见
	if sprite.owner_player_id == current_player_id:
		# 己方精灵：始终可见
		mesh_instance.visible = true
	else:
		# 敌方精灵：使用新的可见性检查（考虑森林隐藏）
		var observer_sprites: Array[Sprite] = []
		for s in all_sprites:
			if s.owner_player_id == current_player_id and s.is_alive:
				observer_sprites.append(s)
		
		var is_visible = fog_of_war_manager.is_sprite_visible_to_player(sprite, current_player_id, observer_sprites, game_map)
		mesh_instance.visible = is_visible

# 获取指定六边形的所有精灵
func _get_sprites_at_hex(hex_coord: Vector2i) -> Array[Sprite]:
	var key = _coord_to_key(hex_coord)
	
	# 如果缓存中有，直接返回
	if hex_sprite_groups.has(key):
		var cached = hex_sprite_groups[key] as Array[Sprite]
		# 验证缓存是否仍然有效（检查精灵是否仍然存在且位置正确）
		var valid_sprites: Array[Sprite] = []
		for sprite in cached:
			if is_instance_valid(sprite) and sprite.is_alive and sprite.hex_position == hex_coord:
				valid_sprites.append(sprite)
		if valid_sprites.size() == cached.size():
			return valid_sprites
	
	# 重新计算
	var sprites_at_hex: Array[Sprite] = []
	for sprite in sprite_nodes.keys():
		if sprite.is_alive and sprite.hex_position == hex_coord:
			sprites_at_hex.append(sprite)
	
	# 更新缓存
	hex_sprite_groups[key] = sprites_at_hex
	return sprites_at_hex

# 坐标转字符串key（用于字典查找）
func _coord_to_key(coord: Vector2i) -> String:
	return str(coord.x) + "_" + str(coord.y)

# 计算精灵在六边形内的偏移位置
func _calculate_sprite_offset(hex_coord: Vector2i, index: int, total: int) -> Vector3:
	var has_contest_marker = false
	if game_map:
		has_contest_marker = game_map.is_contest_point(hex_coord) >= 0
	
	var effective_total = total
	if has_contest_marker:
		effective_total += 1  # 将争夺点地标视为占位，留出额外空间
	
	if effective_total <= 1:
		return Vector3.ZERO
	
	# 如果没有地标且只有一个精灵，就不需要偏移
	if not has_contest_marker and total <= 1:
		return Vector3.ZERO
	
	var hex_size = game_map.hex_size if game_map else 1.5
	var radius = hex_size * (0.55 if has_contest_marker else 0.4)
	
	var angle_step = TAU / effective_total
	var angle_index = float(index)
	if has_contest_marker:
		# 将地标视为第0个占位，精灵从第1个角度开始排布
		angle_index += 1.0
	var angle = angle_index * angle_step
	
	var offset_x = radius * cos(angle)
	var offset_z = radius * sin(angle)
	return Vector3(offset_x, 0, offset_z)

# 更新所有精灵的位置（公共方法，可在回合结束后调用）
func update_all_sprite_positions():
	for sprite in sprite_nodes.keys():
		if sprite.is_alive:
			_update_sprite_position(sprite)

# 更新所有精灵的布局（重新计算每个位置的精灵索引）
func _update_all_sprites_layout():
	# 清空索引
	sprite_hex_indices.clear()
	hex_sprite_groups.clear()
	
	# 按位置分组精灵
	var hex_groups: Dictionary = {}  # key: hex_coord (String), value: Array[Sprite]
	
	for sprite in sprite_nodes.keys():
		if not sprite.is_alive:
			continue
		
		var key = _coord_to_key(sprite.hex_position)
		if not hex_groups.has(key):
			hex_groups[key] = []
		hex_groups[key].append(sprite)
	
	# 为每个位置的精灵分配索引
	for key in hex_groups.keys():
		var sprites = hex_groups[key] as Array[Sprite]
		# 按玩家ID和精灵ID排序，确保索引稳定
		sprites.sort_custom(func(a: Sprite, b: Sprite): return a.owner_player_id < b.owner_player_id or (a.owner_player_id == b.owner_player_id and a.sprite_id < b.sprite_id))
		
		for i in range(sprites.size()):
			sprite_hex_indices[sprites[i]] = i
		
		# 更新缓存
		hex_sprite_groups[key] = sprites

