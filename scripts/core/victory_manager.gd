class_name VictoryManager
extends RefCounted

# 游戏状态
enum GameState {
	PLAYING,     # 进行中
	VICTORY,     # 胜利
	DEFEAT       # 失败
}

# 当前游戏状态
var game_state: GameState = GameState.PLAYING

# 胜利玩家ID
var winner_player_id: int = -1

# 系统引用
var game_map: GameMap
var contest_point_manager: ContestPointManager

signal game_ended(state: GameState, winner_id: int)
signal player_defeated(player_id: int)

func _init(map: GameMap, contest_mgr: ContestPointManager):
	game_map = map
	contest_point_manager = contest_mgr

# 检查胜利条件：持有赏金的精灵从任意起始点（撤离点）撤离
func check_victory_condition(_sprites: Array[Sprite]) -> bool:
	if game_state != GameState.PLAYING:
		return false
	
	# 检查是否有精灵持有赏金
	if not contest_point_manager.is_bounty_held():
		return false
	
	var bounty_holder = contest_point_manager.bounty_holder
	if not bounty_holder or not bounty_holder.is_alive:
		return false
	
	# 检查是否在任意起始点（撤离点）
	var holder_pos = bounty_holder.hex_position
	
	# 检查是否在任意玩家的起始点
	for spawn in game_map.spawn_points:
		if not spawn is Dictionary:
			continue
		var hex_coord = spawn.get("hex_coord", {})
		if hex_coord is Dictionary:
			var spawn_coord = Vector2i(hex_coord.get("q", 0), hex_coord.get("r", 0))
			if holder_pos == spawn_coord:
				declare_victory(bounty_holder.owner_player_id)
				return true
	
	return false

# 检查失败条件：己方3只精灵全部被击败
func check_defeat_condition(player_id: int, player_sprites: Array[Sprite]) -> bool:
	if game_state != GameState.PLAYING:
		return false
	
	# 检查是否所有精灵都被击败
	var all_defeated = true
	for sprite in player_sprites:
		if sprite.is_alive:
			all_defeated = false
			break
	
	if all_defeated:
		declare_defeat(player_id)
		return true
	
	return false

# 声明胜利
func declare_victory(winner_id: int):
	game_state = GameState.VICTORY
	winner_player_id = winner_id
	game_ended.emit(game_state, winner_id)

# 声明失败
func declare_defeat(player_id: int):
	game_state = GameState.DEFEAT
	player_defeated.emit(player_id)
	
	# 如果所有玩家都失败，游戏结束（这种情况不应该发生，但作为保护）
	# 这里可以添加更多逻辑

# 检查游戏是否结束
func is_game_ended() -> bool:
	return game_state != GameState.PLAYING

# 获取游戏结果信息
func get_game_result() -> Dictionary:
	return {
		"state": game_state,
		"winner_id": winner_player_id
	}

