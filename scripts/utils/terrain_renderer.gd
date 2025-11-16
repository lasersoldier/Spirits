class_name TerrainRenderer
extends Node3D

# 地形渲染器：用于在3D场景中渲染地形板块

var game_map: GameMap
var terrain_nodes: Dictionary = {}  # key: hex_coord string, value: MeshInstance3D
var highlight_nodes: Dictionary = {}  # key: hex_coord string, value: MeshInstance3D（可部署位置高亮，绿色）
var selected_highlight_nodes: Dictionary = {}  # key: hex_coord string, value: MeshInstance3D（已选择位置高亮，红色）
var preview_nodes: Dictionary = {}  # key: hex_coord string, value: MeshInstance3D（精灵预览）

# 战争迷雾系统
var fog_of_war_manager: FogOfWarManager = null
var current_player_id: int = -1
var fog_overlay_nodes: Dictionary = {}  # key: hex_coord string, value: MeshInstance3D（迷雾覆盖层）

func _init(map: GameMap):
	game_map = map

func _ready():
	# 确保TerrainRenderer的变换是恒等的，避免高亮节点随摄像机旋转而偏移
	transform = Transform3D.IDENTITY
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	
	if game_map:
		game_map.terrain_changed.connect(_on_terrain_changed)
		# 延迟渲染，确保地图完全初始化
		call_deferred("_render_all_terrain")

func _render_all_terrain():
	if not game_map:
		push_error("TerrainRenderer: game_map 为空")
		return
	
	var all_coords = game_map.get_all_terrain_coords()
	print("TerrainRenderer: 开始渲染 ", all_coords.size(), " 个地形板块")
	
	if all_coords.is_empty():
		push_warning("TerrainRenderer: 没有地形坐标可渲染")
		return
	
	for coord in all_coords:
		var terrain = game_map.get_terrain(coord)
		if terrain:
			_render_terrain_tile(coord, terrain)
	
	print("TerrainRenderer: 完成渲染，共 ", terrain_nodes.size(), " 个地形节点")
	
	# 如果迷雾系统已设置，初始化迷雾覆盖层
	if fog_of_war_manager and current_player_id >= 0:
		call_deferred("_update_fog_overlay")

func _render_terrain_tile(hex_coord: Vector2i, terrain: TerrainTile):
	var key = _coord_to_key(hex_coord)
	print("TerrainRenderer: 渲染地形 - 坐标: ", hex_coord, " 类型: ", TerrainTile.TerrainType.keys()[terrain.terrain_type], " 高度: ", terrain.height_level)
	
	# 如果已存在，先移除
	if terrain_nodes.has(key):
		var old_node = terrain_nodes[key]
		old_node.queue_free()
		terrain_nodes.erase(key)
	
	# 创建新的地形节点
	var mesh_instance = MeshInstance3D.new()
	
	# 根据地形类型和层级生成网格
	var height = _get_height_for_level(terrain.height_level)
	var hex_size = game_map.hex_size if game_map else 1.5
	var mesh = ModelGenerator.create_hex_terrain_mesh(hex_size, height)
	mesh_instance.mesh = mesh
	
	# 设置材质
	var material = _create_terrain_material(terrain)
	mesh_instance.material_override = material
	
	# 设置位置（高度体现在网格本身，网格从底部开始）
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	# 地形网格从底部开始，所以Y位置就是0（地面），高度由网格本身提供
	world_pos.y = 0.0
	mesh_instance.position = world_pos
	
	print("TerrainRenderer: 地形节点位置: ", world_pos, " 网格高度: ", height)
	
	add_child(mesh_instance)
	terrain_nodes[key] = mesh_instance

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

func _create_terrain_material(terrain: TerrainTile) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	match terrain.terrain_type:
		TerrainTile.TerrainType.NORMAL:
			material.albedo_color = Color(0.8, 0.75, 0.7)  # 浅米色
		TerrainTile.TerrainType.FOREST:
			# 森林：绿色六边形，更明显的绿色
			material.albedo_color = Color(0.1, 0.6, 0.2)  # 鲜艳的绿色
			material.emission_enabled = true
			material.emission = Color(0.1, 0.6, 0.2) * 0.3  # 绿色发光
		TerrainTile.TerrainType.WATER:
			# 水流：蓝色六边形，不透明但明显
			material.albedo_color = Color(0.2, 0.5, 1.0)  # 鲜艳的蓝色，不透明
			material.emission_enabled = true
			material.emission = Color(0.2, 0.5, 1.0) * 0.3  # 蓝色发光
			# 移除透明度，让蓝色更明显
		TerrainTile.TerrainType.ROCK:
			material.albedo_color = Color(0.3, 0.3, 0.3)  # 深灰色
			material.emission_enabled = true
			material.emission = Color(0.3, 0.3, 0.3) * 0.1
	
	material.metallic = 0.1
	material.roughness = 0.7
	# 对于普通地形，也添加一些自发光
	if terrain.terrain_type == TerrainTile.TerrainType.NORMAL:
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.1
	
	return material

func _on_terrain_changed(hex_coord: Vector2i, terrain: TerrainTile):
	print("TerrainRenderer: 收到地形变化信号 - 坐标: ", hex_coord, " 类型: ", TerrainTile.TerrainType.keys()[terrain.terrain_type], " 高度: ", terrain.height_level)
	_render_terrain_tile(hex_coord, terrain)
	# 地形变化后更新高亮节点位置（因为高度可能改变）
	_update_highlight_positions(hex_coord)
	# 地形变化后更新迷雾覆盖层（因为高度可能改变）
	call_deferred("_update_fog_overlay")

func _coord_to_key(hex_coord: Vector2i) -> String:
	return str(hex_coord.x) + "_" + str(hex_coord.y)

# 设置战争迷雾管理器和当前玩家ID
func set_fog_manager(manager: FogOfWarManager, player_id: int):
	fog_of_war_manager = manager
	current_player_id = player_id
	
	# 连接视野更新信号
	if fog_of_war_manager:
		fog_of_war_manager.vision_updated.connect(_on_vision_updated)
	
	# 初始化迷雾覆盖层
	call_deferred("_update_fog_overlay")

# 视野更新处理
func _on_vision_updated(_player_id: int):
	# 只更新当前玩家的视野显示
	if _player_id == current_player_id:
		_update_fog_overlay()

# 更新迷雾覆盖层
func _update_fog_overlay():
	if not fog_of_war_manager or current_player_id < 0:
		return
	
	if not game_map:
		return
	
	# 获取所有地形坐标
	var all_coords = game_map.get_all_terrain_coords()
	
	for coord in all_coords:
		var key = _coord_to_key(coord)
		var is_visible = fog_of_war_manager.is_visible_to_player(coord, current_player_id)
		
		if is_visible:
			# 可见：移除迷雾覆盖层
			if fog_overlay_nodes.has(key):
				var fog_node = fog_overlay_nodes[key]
				if is_instance_valid(fog_node):
					fog_node.queue_free()
				fog_overlay_nodes.erase(key)
		else:
			# 不可见：创建或更新迷雾覆盖层
			if not fog_overlay_nodes.has(key):
				_create_fog_overlay(coord)

# 创建迷雾覆盖层
func _create_fog_overlay(hex_coord: Vector2i):
	var key = _coord_to_key(hex_coord)
	
	# 如果已存在，先移除
	if fog_overlay_nodes.has(key):
		var old_node = fog_overlay_nodes[key]
		if is_instance_valid(old_node):
			old_node.queue_free()
		fog_overlay_nodes.erase(key)
	
	# 获取地形高度
	var terrain = game_map.get_terrain(hex_coord) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	
	# 创建迷雾覆盖层网格（比地形略大一点，确保完全覆盖）
	var hex_size = game_map.hex_size if game_map else 1.5
	var fog_mesh = ModelGenerator.create_hex_terrain_mesh(hex_size * 1.01, 0.1)  # 略大于地形，厚度0.1
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = fog_mesh
	
	# 创建暗色半透明材质
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.7)  # 黑色，70%不透明
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 不受光照影响
	mesh_instance.material_override = material
	
	# 设置位置（在地形上方略高一点）
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	world_pos.y = terrain_height + 0.05  # 在地形顶部上方一点
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	fog_overlay_nodes[key] = mesh_instance

# 高亮显示可部署位置
func highlight_deploy_positions(positions: Array[Vector2i]):
	print("TerrainRenderer: 开始高亮 ", positions.size(), " 个位置")
	# 清除之前的高亮
	clear_highlights()
	
	# 为每个位置创建高亮
	for pos in positions:
		_create_highlight(pos)
	
	print("TerrainRenderer: 高亮完成，共创建 ", highlight_nodes.size(), " 个高亮节点")

# 创建高亮节点
func _create_highlight(hex_coord: Vector2i):
	var key = _coord_to_key(hex_coord)
	
	# 如果已存在，先移除
	if highlight_nodes.has(key):
		return
	
	# 创建高亮网格（比板块略小一点的六边形，放在地形上方）
	var hex_size = game_map.hex_size if game_map else 1.5
	var highlight_mesh = ModelGenerator.create_hex_terrain_mesh(hex_size * 0.95, 0.1)  # 比板块略小一点
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = highlight_mesh
	
	# 创建高亮材质（绿色半透明，更明显）
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 1.0, 0.0, 0.7)  # 绿色半透明，更不透明
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.0, 1.0, 0.0, 0.5)  # 绿色发光，更亮
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 不受光照影响
	mesh_instance.material_override = material
	
	# 设置位置（根据地形高度调整）
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	# 获取该位置的地形高度
	var terrain = game_map.get_terrain(hex_coord) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	# 高亮放在地形顶部上方一点（地形从Y=0开始，顶部在Y=terrain_height）
	world_pos.y = terrain_height + 0.2  # 地形顶部 + 小偏移
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	highlight_nodes[key] = mesh_instance
	print("TerrainRenderer: 创建高亮节点 ", hex_coord, " 位置: ", world_pos)

# 清除所有高亮
func clear_highlights():
	for key in highlight_nodes.keys():
		var node = highlight_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	highlight_nodes.clear()
	
	# 清除已选择位置高亮
	clear_selected_highlights()
	
	# 清除预览
	clear_previews()

# 高亮显示已选择的位置（红色）
func highlight_selected_position(hex_coord: Vector2i):
	var key = _coord_to_key(hex_coord)
	
	# 如果已存在，先移除
	if selected_highlight_nodes.has(key):
		return
	
	# 创建红色高亮网格
	var hex_size = game_map.hex_size if game_map else 1.5
	var highlight_mesh = ModelGenerator.create_hex_terrain_mesh(hex_size * 0.95, 0.1)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = highlight_mesh
	
	# 创建红色高亮材质
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.7)  # 红色半透明
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0, 0.5)  # 红色发光
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	
	# 设置位置（根据地形高度调整）
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	# 获取该位置的地形高度
	var terrain = game_map.get_terrain(hex_coord) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	# 高亮放在地形顶部上方一点（地形从Y=0开始，顶部在Y=terrain_height）
	world_pos.y = terrain_height + 0.2  # 地形顶部 + 小偏移
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	selected_highlight_nodes[key] = mesh_instance

# 清除已选择位置高亮
func clear_selected_highlights():
	for key in selected_highlight_nodes.keys():
		var node = selected_highlight_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	selected_highlight_nodes.clear()

# 更新高亮节点位置（当地形高度变化时）
func _update_highlight_positions(hex_coord: Vector2i):
	var key = _coord_to_key(hex_coord)
	
	# 获取新的地形高度
	var terrain = game_map.get_terrain(hex_coord) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	
	# 更新绿色高亮节点位置
	if highlight_nodes.has(key):
		var highlight_node = highlight_nodes[key]
		if is_instance_valid(highlight_node):
			var hex_size = game_map.hex_size if game_map else 1.5
			var map_height = game_map.map_height if game_map else 20
			var map_width = game_map.map_width if game_map else 20
			var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
			world_pos.y = terrain_height + 0.2  # 地形顶部 + 小偏移
			highlight_node.position = world_pos
			print("TerrainRenderer: 更新绿色高亮节点位置 ", hex_coord, " 到 ", world_pos)
	
	# 更新红色高亮节点位置
	if selected_highlight_nodes.has(key):
		var selected_node = selected_highlight_nodes[key]
		if is_instance_valid(selected_node):
			var hex_size = game_map.hex_size if game_map else 1.5
			var map_height = game_map.map_height if game_map else 20
			var map_width = game_map.map_width if game_map else 20
			var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
			world_pos.y = terrain_height + 0.2  # 地形顶部 + 小偏移
			selected_node.position = world_pos
			print("TerrainRenderer: 更新红色高亮节点位置 ", hex_coord, " 到 ", world_pos)

# 显示精灵预览
func show_sprite_preview(hex_coord: Vector2i, _sprite_id: String, sprite_attribute: String):
	var key = _coord_to_key(hex_coord)
	
	# 如果已存在，先移除
	if preview_nodes.has(key):
		var old_node = preview_nodes[key]
		if is_instance_valid(old_node):
			old_node.queue_free()
		preview_nodes.erase(key)
	
	# 创建预览网格（根据精灵属性）
	var preview_mesh = _get_sprite_preview_mesh(sprite_attribute)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = preview_mesh
	
	# 创建预览材质（半透明）
	var material = StandardMaterial3D.new()
	var color = _get_attribute_color(sprite_attribute)
	material.albedo_color = Color(color.r, color.g, color.b, 0.6)  # 半透明
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color * 0.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	
	# 设置位置（根据地形高度调整）
	var hex_size = game_map.hex_size if game_map else 1.5
	var map_height = game_map.map_height if game_map else 20
	var map_width = game_map.map_width if game_map else 20
	var world_pos = HexGrid.hex_to_world(hex_coord, hex_size, map_height, map_width)
	# 获取该位置的地形高度
	var terrain = game_map.get_terrain(hex_coord) if game_map else null
	var terrain_height = 3.0  # 默认1级高度
	if terrain:
		terrain_height = _get_height_for_level(terrain.height_level)
	# 预览放在地形顶部上方（地形从Y=0开始，顶部在Y=terrain_height）
	world_pos.y = terrain_height + 0.5  # 地形顶部 + 偏移
	mesh_instance.position = world_pos
	
	add_child(mesh_instance)
	preview_nodes[key] = mesh_instance

# 清除预览
func clear_preview(hex_coord: Vector2i):
	var key = _coord_to_key(hex_coord)
	if preview_nodes.has(key):
		var node = preview_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
		preview_nodes.erase(key)

# 清除所有预览
func clear_previews():
	for key in preview_nodes.keys():
		var node = preview_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	preview_nodes.clear()

# 获取精灵预览网格
func _get_sprite_preview_mesh(attribute: String) -> ArrayMesh:
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
			return ModelGenerator.create_box_mesh(0.4, 0.4, 0.4)

# 获取属性颜色
func _get_attribute_color(attr: String) -> Color:
	match attr:
		"fire":
			return Color(1.0, 0.5, 0.0)  # 橙红色
		"wind":
			return Color(0.5, 0.8, 1.0)  # 浅蓝色
		"water":
			return Color(0.0, 0.2, 0.8)  # 深蓝色
		"rock":
			return Color(0.4, 0.4, 0.4)  # 深灰色
		_:
			return Color.WHITE

