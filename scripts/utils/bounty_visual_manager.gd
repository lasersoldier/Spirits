class_name BountyVisualManager
extends Node3D

var game_map: GameMap
var contest_manager: ContestPointManager
var sprite_renderer: SpriteRenderer

var ground_node: MeshInstance3D = null
var ground_hex: Vector2i = Vector2i(-1, -1)

var carry_mesh: MeshInstance3D = null
var carry_sprite: Sprite = null

const GROUND_COLOR := Color(1.0, 0.6, 0.1, 0.95)
const CARRY_COLOR := Color(1.0, 0.85, 0.2, 0.95)
const CARRY_OFFSET := Vector3(0, 0.9, 0)

func setup(map: GameMap, contest_mgr: ContestPointManager, sprite_rend: SpriteRenderer):
	game_map = map
	contest_manager = contest_mgr
	sprite_renderer = sprite_rend
	
	if contest_manager:
		contest_manager.bounty_generated.connect(_on_bounty_generated)
		contest_manager.bounty_lost.connect(_on_bounty_dropped)
		contest_manager.bounty_acquired.connect(_on_bounty_acquired)
	
	if game_map:
		game_map.terrain_changed.connect(_on_terrain_changed)
	
	_sync_visual_state()

func _sync_visual_state():
	_hide_ground_visual()
	_detach_from_sprite()
	
	if not contest_manager:
		return
	
	match contest_manager.bounty_status:
		ContestPointManager.BountyStatus.GENERATED, ContestPointManager.BountyStatus.DROPPED:
			var hex = contest_manager.get_active_bounty_hex()
			if hex != Vector2i(-1, -1):
				_show_ground_visual(hex)
		ContestPointManager.BountyStatus.HELD:
			var holder = contest_manager.bounty_holder
			if holder:
				_attach_to_sprite(holder)

func _on_bounty_generated(hex: Vector2i):
	_detach_from_sprite()
	_show_ground_visual(hex)

func _on_bounty_dropped(sprite: Sprite):
	if sprite:
		_detach_from_sprite()
		_show_ground_visual(sprite.hex_position)
	else:
		_sync_visual_state()

func _on_bounty_acquired(sprite: Sprite):
	_hide_ground_visual()
	if sprite:
		_attach_to_sprite(sprite)

func _on_terrain_changed(hex_coord: Vector2i, _terrain: TerrainTile):
	if hex_coord == ground_hex:
		_update_ground_position()

func _show_ground_visual(hex: Vector2i):
	ground_hex = hex
	
	if not ground_node or not is_instance_valid(ground_node):
		ground_node = _create_bounty_mesh_instance(GROUND_COLOR, Vector3(1.1, 1.5, 1.1))
		add_child(ground_node)
	
	ground_node.visible = true
	_update_ground_position()

func _hide_ground_visual():
	if ground_node and is_instance_valid(ground_node):
		ground_node.visible = false
	ground_hex = Vector2i(-1, -1)

func _update_ground_position():
	if not ground_node or not is_instance_valid(ground_node):
		return
	if ground_hex == Vector2i(-1, -1) or not game_map:
		return
	
	var world_pos = _get_world_position_for_hex(ground_hex)
	ground_node.position = world_pos

func _attach_to_sprite(sprite: Sprite):
	if not sprite or not sprite.is_alive:
		return
	
	if carry_sprite == sprite and carry_mesh and is_instance_valid(carry_mesh):
		return
	
	_detach_from_sprite()
	
	if not sprite_renderer:
		return
	
	var host_node = sprite_renderer.get_sprite_node(sprite)
	if not host_node:
		call_deferred("_attach_to_sprite", sprite)
		return
	
	var mesh_instance = _create_bounty_mesh_instance(CARRY_COLOR, Vector3(0.5, 0.8, 0.5))
	host_node.add_child(mesh_instance)
	mesh_instance.position = CARRY_OFFSET
	mesh_instance.visible = true
	
	carry_sprite = sprite
	carry_mesh = mesh_instance

func _detach_from_sprite():
	if carry_mesh and is_instance_valid(carry_mesh):
		carry_mesh.queue_free()
	carry_mesh = null
	carry_sprite = null

func _create_bounty_mesh_instance(color: Color, scale: Vector3) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = ModelGenerator.create_bounty_crystal_mesh()
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.1
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	mesh_instance.material_override = material
	mesh_instance.scale = scale
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance

func _get_world_position_for_hex(hex_coord: Vector2i) -> Vector3:
	if not game_map:
		return Vector3.ZERO
	
	var hex_size = game_map.hex_size
	var world = HexGrid.hex_to_world(hex_coord, hex_size, game_map.map_height, game_map.map_width)
	var terrain = game_map.get_terrain(hex_coord)
	var height = 3.0
	if terrain:
		match terrain.height_level:
			1:
				height = 3.0
			2:
				height = 6.0
			3:
				height = 12.0
	world.y = height + 0.2
	return world


