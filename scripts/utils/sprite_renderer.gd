class_name SpriteRenderer
extends Node3D

# 精灵渲染器：用于在3D场景中渲染精灵

var sprite_nodes: Dictionary = {}  # key: sprite实例, value: MeshInstance3D
var game_map: GameMap  # 地图引用，用于获取地图参数

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

# 更新精灵位置
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

# 移除精灵
func remove_sprite(sprite: Sprite):
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

