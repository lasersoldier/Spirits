class_name ContestPointManager
extends RefCounted

# 赏金状态
enum BountyStatus {
	NONE,        # 未生成
	PENDING,     # 已触发待生成
	GENERATED,   # 已生成
	HELD,        # 被持有
	DROPPED      # 掉落待拾取
}

# 赏金状态
var bounty_status: BountyStatus = BountyStatus.NONE

# 持有赏金的精灵
var bounty_holder: Sprite = null

# 赏金当前所在格（生成时）
var bounty_hex: Vector2i = Vector2i(-1, -1)
# 赏金掉落格
var dropped_hex: Vector2i = Vector2i(-1, -1)

# 首次触发赏金生成的玩家ID
var first_trigger_player_id: int = -1

# 待生成的回合
var pending_round: int = -1

# 公共争夺点状态（key: 争夺点ID, value: 占领信息）
var contest_point_states: Dictionary = {}

# 占领信息类
class ContestPointState:
	var point_id: int
	var hex_coord: Vector2i
	var occupier: Sprite = null
	var occupation_rounds: int = 0
	var last_reward_round: int = -1
	
	func _init(id: int, coord: Vector2i):
		point_id = id
		hex_coord = coord

# 系统引用
var game_map: GameMap
var energy_manager: EnergyManager
# 从玩家套牌中抽取卡牌的函数（由game_manager提供）
var draw_card_from_deck_func: Callable

signal bounty_generated(hex_coord: Vector2i)
signal bounty_acquired(sprite: Sprite)
signal bounty_lost(sprite: Sprite)
signal contest_point_reward(point_id: int, player_id: int, reward: Dictionary)

func _init(map: GameMap, energy_mgr: EnergyManager):
	game_map = map
	energy_manager = energy_mgr
	
	# 初始化公共争夺点
	_initialize_contest_points()

func _initialize_contest_points():
	var contest_points = game_map.contest_points
	for i in range(contest_points.size()):
		var coord = contest_points[i]
		var state = ContestPointState.new(i, coord)
		contest_point_states[i] = state

# 检查是否有精灵进入赏金区域（回合开始时调用）
func check_bounty_generation(entering_sprites: Array[Sprite], current_round: int):
	if bounty_status != BountyStatus.NONE:
		return
	
	# 检查是否有精灵进入赏金区域
	for sprite in entering_sprites:
		if game_map.is_in_bounty_zone(sprite.hex_position):
			# 首次进入，触发下一回合生成
			bounty_status = BountyStatus.PENDING
			first_trigger_player_id = sprite.owner_player_id
			pending_round = current_round + 1
			break

# 处理待生成赏金
func process_pending_bounty(all_sprites: Array[Sprite], current_round: int):
	if bounty_status != BountyStatus.PENDING:
		return
	if pending_round == -1 or pending_round > current_round:
		return
	generate_bounty(all_sprites)
	
# 生成赏金
func generate_bounty(all_sprites: Array[Sprite]):
	if bounty_status != BountyStatus.PENDING:
		return
	
	bounty_status = BountyStatus.GENERATED
	dropped_hex = Vector2i(-1, -1)
	pending_round = -1
	var spawn_hex = _select_bounty_hex(all_sprites)
	bounty_hex = spawn_hex

	# 播报赏金生成位置
	bounty_generated.emit(bounty_hex)

# 争夺赏金（回合结算时调用）
func contest_bounty(candidates: Array[Sprite]) -> Sprite:
	if bounty_status != BountyStatus.GENERATED and bounty_status != BountyStatus.DROPPED:
		return null
	
	var target_hex = get_active_bounty_hex()
	if target_hex == Vector2i(-1, -1):
		return null

	# 筛选在赏金位置的精灵
	var in_zone: Array[Sprite] = []
	for sprite in candidates:
		if sprite.is_alive and sprite.hex_position == target_hex:
			in_zone.append(sprite)
	
	if in_zone.is_empty():
		return null
	
	# 按优先级判定归属
	var winner = _determine_bounty_winner(in_zone)
	
	if winner:
		acquire_bounty(winner)
	
	return winner

# 判定赏金归属（优先级：血量>能量>默认顺序）
func _determine_bounty_winner(candidates: Array[Sprite]) -> Sprite:
	if candidates.size() == 1:
		return candidates[0]
	
	# 优先级1：血量最高
	var max_hp = -1
	var hp_candidates: Array[Sprite] = []
	for sprite in candidates:
		if sprite.current_hp > max_hp:
			max_hp = sprite.current_hp
			hp_candidates = [sprite]
		elif sprite.current_hp == max_hp:
			hp_candidates.append(sprite)
	
	if hp_candidates.size() == 1:
		return hp_candidates[0]
	
	# 优先级2：能量点数最高（若血量相同）
	var max_energy = -1
	var winner: Sprite = null
	for sprite in hp_candidates:
		var energy = energy_manager.get_energy(sprite.owner_player_id)
		if energy > max_energy:
			max_energy = energy
			winner = sprite
	
	if winner:
		return winner

	# 最终兜底：按玩家ID和精灵ID排序
	hp_candidates.sort_custom(Callable(self, "_compare_bounty_sprites"))
	return hp_candidates[0]

func _compare_bounty_sprites(a: Sprite, b: Sprite) -> bool:
	if a.owner_player_id == b.owner_player_id:
		return a.sprite_id < b.sprite_id
	return a.owner_player_id < b.owner_player_id

# 获得赏金
func acquire_bounty(sprite: Sprite):
	if not sprite or not sprite.is_alive:
		return
	
	bounty_status = BountyStatus.HELD
	bounty_holder = sprite
	bounty_hex = Vector2i(-1, -1)
	dropped_hex = Vector2i(-1, -1)
	sprite.acquire_bounty()
	bounty_acquired.emit(sprite)
	
	# 实时播报位置（即使处于森林地形也会暴露）
	# 这个功能在UI层实现

# 失去赏金（精灵被击败时调用）
func lose_bounty():
	if bounty_status != BountyStatus.HELD or not bounty_holder:
		return
	
	var holder = bounty_holder
	var drop_position = holder.hex_position
	bounty_holder.lose_bounty()
	bounty_lost.emit(holder)
	
	bounty_holder = null
	dropped_hex = drop_position
	bounty_status = BountyStatus.DROPPED

# 检查公共争夺点占领（回合结束时调用）
func check_contest_points(sprites: Array[Sprite], current_round_num: int):
	for point_id in contest_point_states.keys():
		var state = contest_point_states[point_id] as ContestPointState
		
		# 检查是否有精灵在该争夺点
		var occupier: Sprite = null
		for sprite in sprites:
			if sprite.is_alive and sprite.hex_position == state.hex_coord:
				# 检查是否被敌方攻击（简化版：如果该位置有多个精灵，则未占领）
				var enemies_at_point = _get_enemy_sprites_at_point(sprite, sprites, state.hex_coord)
				if enemies_at_point.is_empty():
					occupier = sprite
					break
		
		# 更新占领状态
		if occupier:
			if state.occupier == occupier:
				# 继续占领
				state.occupation_rounds += 1
			else:
				# 新占领
				state.occupier = occupier
				state.occupation_rounds = 1
			
			# 检查是否可以获得奖励（占领1回合且未在上一回合获得奖励）
			if state.occupation_rounds >= 1 and state.last_reward_round < current_round_num:
				_give_contest_point_reward(point_id, occupier, current_round_num)
		else:
			# 无人占领或冲突
			state.occupier = null
			state.occupation_rounds = 0

# 给予争夺点奖励
func _give_contest_point_reward(point_id: int, sprite: Sprite, current_round_num: int):
	var state = contest_point_states[point_id] as ContestPointState
	state.last_reward_round = current_round_num
	
	# 奖励：随机卡牌1张 + 能量点1点
	var reward = {
		"card": null,  # 从玩家自己的套牌中抽卡
		"energy": 1
	}
	
	# 从玩家自己的套牌中抽卡
	if draw_card_from_deck_func.is_valid():
		reward.card = draw_card_from_deck_func.call(sprite.owner_player_id) as Card
	
	# 给予能量
	energy_manager.on_contest_point_captured(sprite.owner_player_id)
	
	contest_point_reward.emit(point_id, sprite.owner_player_id, reward)

# 获取争夺点的敌方精灵
func _get_enemy_sprites_at_point(sprite: Sprite, all_sprites: Array[Sprite], hex_coord: Vector2i) -> Array[Sprite]:
	var enemies: Array[Sprite] = []
	for other in all_sprites:
		if other.is_alive and other.owner_player_id != sprite.owner_player_id and other.hex_position == hex_coord:
			enemies.append(other)
	return enemies

# 获取持有赏金的精灵位置（用于播报）
func get_bounty_holder_position() -> Vector2i:
	if bounty_holder and bounty_holder.is_alive:
		return bounty_holder.hex_position
	return Vector2i(-1, -1)

# 获取当前赏金所在位置（未被持有时）
func get_active_bounty_hex() -> Vector2i:
	match bounty_status:
		BountyStatus.GENERATED:
			return bounty_hex
		BountyStatus.DROPPED:
			return dropped_hex
		_:
			return Vector2i(-1, -1)

# 检查是否持有赏金
func is_bounty_held() -> bool:
	return bounty_status == BountyStatus.HELD and bounty_holder != null and bounty_holder.is_alive

func get_pending_round() -> int:
	return pending_round

func _select_bounty_hex(all_sprites: Array[Sprite]) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for coord in game_map.bounty_zone_tiles:
		if game_map.is_valid_hex_with_terrain(coord):
			candidates.append(coord)
	if candidates.is_empty():
		return Vector2i.ZERO

	var reference_positions: Array[Vector2i] = []
	for sprite in all_sprites:
		if sprite.is_alive:
			reference_positions.append(sprite.hex_position)

	if reference_positions.is_empty():
		return candidates[0]

	var best_hex = candidates[0]
	var best_sum = -INF
	var best_min = -INF
	for candidate in candidates:
		var total_distance = HexGrid.sum_distance_to_points(candidate, reference_positions)
		var min_distance = INF
		for ref in reference_positions:
			var distance = HexGrid.hex_distance(candidate, ref)
			min_distance = min(min_distance, distance)
		if total_distance > best_sum or (total_distance == best_sum and min_distance > best_min):
			best_sum = total_distance
			best_min = min_distance
			best_hex = candidate

	return best_hex
