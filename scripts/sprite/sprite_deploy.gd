class_name SpriteDeployInterface
extends RefCounted

# 精灵库引用
var sprite_library: SpriteLibrary

# 地图引用
var game_map: GameMap

# 已部署的精灵列表（按玩家ID分组）
var deployed_sprites: Dictionary = {}  # key: player_id, value: Array[Sprite]

signal sprite_deployed(sprite: Sprite, player_id: int, position: Vector2i)

func _init(library: SpriteLibrary, map: GameMap):
	sprite_library = library
	game_map = map

# 人类玩家部署：从基础精灵中选择自定义数量
func deploy_human_player(player_id: int, selected_sprite_ids: Array[String], deploy_positions: Array[Vector2i]) -> Array[Sprite]:
	if selected_sprite_ids.is_empty():
		push_error("必须至少选择1只精灵")
		return []
	
	if selected_sprite_ids.size() != deploy_positions.size():
		push_error("部署精灵数量与位置数量不匹配")
		return []
	
	var sprites: Array[Sprite] = []
	
	for i in range(selected_sprite_ids.size()):
		var sprite_id = selected_sprite_ids[i]
		var position = deploy_positions[i]
		
		# 验证位置是否有效
		if not _is_valid_deploy_position(player_id, position):
			push_error("部署位置无效: " + str(position))
			continue
		
		# 创建精灵实例
		var sprite_data = sprite_library.get_sprite_data(sprite_id)
		if sprite_data.is_empty():
			push_error("精灵数据不存在: " + sprite_id)
			continue
		
		var sprite = Sprite.new(sprite_data)
		sprite.owner_player_id = player_id
		sprite.hex_position = position
		
		sprites.append(sprite)
		
		# 记录部署
		if not deployed_sprites.has(player_id):
			deployed_sprites[player_id] = []
		deployed_sprites[player_id].append(sprite)
		
		sprite_deployed.emit(sprite, player_id, position)
	
	return sprites

func deploy_custom_sprite(player_id: int, sprite_id: String, position: Vector2i) -> Sprite:
	if sprite_id.is_empty():
		push_error("自定义部署失败：缺少精灵ID")
		return null
	
	var sprite_data = sprite_library.get_sprite_data(sprite_id)
	if sprite_data.is_empty():
		push_error("自定义部署失败：精灵数据不存在 " + sprite_id)
		return null
	
	var sprite = Sprite.new(sprite_data)
	sprite.owner_player_id = player_id
	sprite.hex_position = position
	
	if not deployed_sprites.has(player_id):
		deployed_sprites[player_id] = []
	deployed_sprites[player_id].append(sprite)
	sprite_deployed.emit(sprite, player_id, position)
	
	return sprite

# AI玩家部署：随机分配3只不同属性的精灵
func deploy_ai_player(player_id: int) -> Array[Sprite]:
	var base_sprites = sprite_library.get_base_sprites()
	if base_sprites.size() < 4:
		push_error("基础精灵数据不足")
		return []
	
	# 随机选择3只不同属性的精灵
	var selected_sprites_data: Array[Dictionary] = []
	var used_attributes: Array[String] = []
	
	# 打乱顺序
	base_sprites.shuffle()
	
	for sprite_data in base_sprites:
		var attr = sprite_data.get("attribute", "")
		if attr != "" and attr not in used_attributes:
			selected_sprites_data.append(sprite_data)
			used_attributes.append(attr)
			if selected_sprites_data.size() >= 3:
				break
	
	if selected_sprites_data.size() < 3:
		push_error("无法选择3只不同属性的精灵")
		return []
	
	# 获取部署位置
	var deploy_positions = game_map.get_deploy_positions(player_id)
	if deploy_positions.size() < 3:
		push_error("部署位置不足")
		return []
	
	var sprites: Array[Sprite] = []
	
	for i in range(3):
		var sprite_data = selected_sprites_data[i]
		var position = deploy_positions[i]
		
		var sprite = Sprite.new(sprite_data)
		sprite.owner_player_id = player_id
		sprite.hex_position = position
		
		sprites.append(sprite)
		
		# 记录部署
		if not deployed_sprites.has(player_id):
			deployed_sprites[player_id] = []
		deployed_sprites[player_id].append(sprite)
		
		sprite_deployed.emit(sprite, player_id, position)
	
	return sprites

func remove_sprite(sprite: Sprite):
	if not sprite:
		return
	var pid = sprite.owner_player_id
	if deployed_sprites.has(pid):
		deployed_sprites[pid].erase(sprite)

# 验证部署位置是否有效
func _is_valid_deploy_position(player_id: int, position: Vector2i) -> bool:
	# 先检查位置是否是玩家的部署位置
	var valid_positions = game_map.get_deploy_positions(player_id)
	if position in valid_positions:
		# 如果是部署位置，还需要检查是否有实际地形板块（坐标白名单）
		if game_map.has_terrain_tile(position):
			return true
		# 如果部署位置没有地形，也允许部署（类似玩家0和AI的固定部署位置）
		return true
	
	# 如果不是部署位置，检查位置是否在地图范围内且有地形
	if not game_map._is_valid_hex(position):
		return false
	
	# 检查是否有实际地形板块（坐标白名单）
	if not game_map.has_terrain_tile(position):
		return false
	
	return false
	
	# 检查位置是否已被占用
	# 这里可以添加更多验证逻辑

# 获取玩家的所有精灵
func get_player_sprites(player_id: int) -> Array[Sprite]:
	var sprites: Array[Sprite] = []
	if deployed_sprites.has(player_id):
		var player_sprites = deployed_sprites[player_id]
		# 确保类型正确
		for sprite in player_sprites:
			if sprite is Sprite:
				sprites.append(sprite as Sprite)
	return sprites

# 获取所有已部署的精灵
func get_all_sprites() -> Array[Sprite]:
	var all_sprites: Array[Sprite] = []
	for player_id in deployed_sprites.keys():
		all_sprites.append_array(deployed_sprites[player_id])
	return all_sprites
