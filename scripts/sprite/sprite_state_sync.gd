class_name SpriteStateSyncInterface
extends RefCounted

# 所有精灵的状态快照
var sprite_states: Dictionary = {}  # key: sprite实例ID或唯一标识, value: 状态字典

signal state_updated(sprite_id: String, state: Dictionary)

# 同步所有精灵的状态
func sync_all_sprites(sprites: Array[Sprite]):
	for sprite in sprites:
		sync_sprite(sprite)

# 同步单个精灵的状态
func sync_sprite(sprite: Sprite):
	var state = {
		"position": sprite.hex_position,
		"current_hp": sprite.current_hp,
		"max_hp": sprite.max_hp,
		"has_bounty": sprite.has_bounty,
		"is_alive": sprite.is_alive,
		"owner_player_id": sprite.owner_player_id,
		"remaining_movement": sprite.remaining_movement,
		"terrain_effects": sprite.current_terrain_effects
	}
	
	var sprite_key = _get_sprite_key(sprite)
	sprite_states[sprite_key] = state
	state_updated.emit(sprite_key, state)

# 获取精灵状态
func get_sprite_state(sprite: Sprite) -> Dictionary:
	var sprite_key = _get_sprite_key(sprite)
	return sprite_states.get(sprite_key, {})

# 获取所有精灵状态（用于UI显示等）
func get_all_states() -> Dictionary:
	return sprite_states.duplicate()

# 生成精灵唯一标识
func _get_sprite_key(sprite: Sprite) -> String:
	return str(sprite.owner_player_id) + "_" + sprite.sprite_id

