class_name GameManager
extends Node

# 游戏状态
enum GamePhase {
	DEPLOYMENT,    # 部署阶段
	PLAYING,       # 游戏进行中
	ENDED          # 游戏结束
}

# 当前游戏阶段
var current_phase: GamePhase = GamePhase.DEPLOYMENT

# 当前回合数
var current_round: int = 0

# 玩家数量
const PLAYER_COUNT: int = 4  # 1人类 + 3AI

# 人类玩家ID（固定为0）
const HUMAN_PLAYER_ID: int = 0

# 回合计时（秒）
const HUMAN_TURN_TIME: float = 30.0
const AI_TURN_TIME: float = 1.0

# 当前回合剩余时间
var turn_time_remaining: float = 0.0

# 模式配置
@export var training_mode: bool = false
@export_range(1, 6, 1, "or_greater") var human_deploy_count: int = 3

# 所有玩家是否已提交行动
var actions_submitted: Dictionary = {}  # key: player_id, value: bool

# 每个精灵本回合的行动次数（用于限制每回合只能进行一次移动和一次攻击）
var sprite_action_counts: Dictionary = {}  # key: sprite_id (String), value: {"move": int, "attack": int}

# 系统组件
var game_map: GameMap
var sprite_library: SpriteLibrary
var card_library: CardLibrary
var sprite_deploy: SpriteDeployInterface
var deck_builder: DeckBuilder
var hand_managers: Dictionary = {}  # key: player_id, value: HandCardManager
var energy_manager: EnergyManager
var terrain_manager: TerrainManager
var card_interface: CardSpriteInterface
var action_resolver: ActionResolver
var status_effect_manager: StatusEffectManager
var delayed_effect_manager: DelayedEffectManager
var contest_point_manager: ContestPointManager
var victory_manager: VictoryManager
var ai_players: Dictionary = {}  # key: player_id, value: AIPlayer
var state_sync: SpriteStateSyncInterface
var fog_of_war_manager: FogOfWarManager
var main_ui: MainUI = null

# 所有精灵列表
var all_sprites: Array[Sprite] = []

# 渲染器
var terrain_renderer: TerrainRenderer
var sprite_renderer: SpriteRenderer
var bounty_visual_manager: BountyVisualManager
var victory_screen: VictoryScreen = null

const VICTORY_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/victory_screen.tscn")

# 玩家卡组
var player_decks: Dictionary = {}  # key: player_id, value: Array[Card]
# 玩家剩余套牌（用于抽卡）
var player_remaining_decks: Dictionary = {}  # key: player_id, value: Array[Card]
var training_enemy_layout: Array[Dictionary] = []
var fog_enabled_state: bool = true
var training_enemy_player_ids: Array[int] = []

signal phase_changed(new_phase: GamePhase)
signal round_started(round: int)
signal round_ended(round: int)
signal action_submitted(player_id: int)
signal all_actions_submitted()
signal action_added(action: ActionResolver.Action)  # 当行动添加到队列时发出

func _ready():
	_initialize_systems()
	# 等待系统初始化完成后，设置UI并开始游戏
	await get_tree().process_frame
	_setup_ui()
	await _setup_map_rendering()
	_setup_viewport_adaptation()
	# 自动开始游戏（或进入部署阶段）
	await get_tree().process_frame
	call_deferred("start_game")

func _initialize_systems():
	# 初始化库
	sprite_library = SpriteLibrary.new()
	card_library = CardLibrary.new()
	
	# 尝试从场景中获取GameMap，如果没有则创建新的
	game_map = get_node_or_null("GameMap") as GameMap
	if not game_map:
		game_map = GameMap.new()
		add_child(game_map)
	# 等待一帧确保地图初始化完成
	await get_tree().process_frame
	training_enemy_layout = game_map.get_training_enemy_configs()
	_refresh_training_enemy_player_ids()
	
	# 初始化部署系统
	sprite_deploy = SpriteDeployInterface.new(sprite_library, game_map)
	
	# 初始化卡组构建器
	deck_builder = DeckBuilder.new(card_library)
	
	# 初始化能量管理器
	energy_manager = EnergyManager.new()
	for player_id in range(PLAYER_COUNT):
		energy_manager.initialize_player(player_id)
	
	# 初始化地形管理器
	terrain_manager = TerrainManager.new(game_map)
	
	# 初始化卡牌接口与效果管理器
	# 初始化卡牌接口
	card_interface = CardSpriteInterface.new(card_library)
	status_effect_manager = StatusEffectManager.new()
	delayed_effect_manager = DelayedEffectManager.new(card_interface)
	card_interface.set_aux_managers(status_effect_manager, delayed_effect_manager)
	
	# 初始化行动结算器
	action_resolver = ActionResolver.new(game_map, terrain_manager, card_interface, energy_manager, all_sprites, delayed_effect_manager)
	
	# 初始化争夺点管理器
	contest_point_manager = ContestPointManager.new(game_map, energy_manager)
	# 设置从玩家套牌中抽取卡牌的函数
	contest_point_manager.draw_card_from_deck_func = draw_card_from_player_deck
	
	# 初始化胜利管理器
	victory_manager = VictoryManager.new(game_map, contest_point_manager)
	
	# 初始化状态同步
	state_sync = SpriteStateSyncInterface.new()
	
	# 初始化战争迷雾管理器
	fog_of_war_manager = FogOfWarManager.new()
	if training_mode:
		fog_enabled_state = false
	
	# 连接信号
	_connect_signals()

func _connect_signals():
	# 连接精灵信号
	# 这些信号会在精灵创建后连接
	
	# 连接争夺点信号
	contest_point_manager.bounty_generated.connect(_on_bounty_generated)
	contest_point_manager.bounty_acquired.connect(_on_bounty_acquired)
	contest_point_manager.bounty_lost.connect(_on_bounty_lost)
	
	# 连接胜利管理器信号
	victory_manager.game_ended.connect(_on_game_ended)

# 开始游戏
func start_game():
	# 构建所有玩家的卡组
	_build_all_decks()
	
	# 分发起手卡牌（在发出phase_changed信号之前，确保手牌已准备好）
	_deal_starting_hands()
	
	# 设置阶段并发出信号（此时手牌已准备好，UI可以立即显示）
	current_phase = GamePhase.DEPLOYMENT
	phase_changed.emit(current_phase)
	
	if training_mode:
		_deploy_training_enemies()

# 构建所有玩家的卡组
func _build_all_decks():
	player_decks.clear()
	
	for player_id in range(PLAYER_COUNT):
		if player_id == HUMAN_PLAYER_ID:
			player_decks[player_id] = _build_default_human_deck()
		else:
			var difficulty = _get_ai_difficulty(player_id)
			player_decks[player_id] = deck_builder.build_ai_deck(difficulty, player_id)

# 构建默认人类卡组（简化版）
func _build_default_human_deck() -> Array[Card]:
	var deck: Array[Card] = []
	var all_card_ids = card_library.get_all_card_ids()
	
	# 每种卡牌3张，共30张
	for card_id in all_card_ids:
		for i in range(3):
			var card_data = card_library.get_card_data(card_id)
			deck.append(Card.new(card_data))
	
	deck.shuffle()
	return deck

func _get_ai_difficulty(player_id: int) -> String:
	match player_id:
		1:
			return "normal"
		2:
			return "easy"
		3:
			return "hard"
		_:
			return "normal"

func _get_ai_player_difficulty(player_id: int) -> AIPlayer.Difficulty:
	match player_id:
		2:
			return AIPlayer.Difficulty.EASY
		3:
			return AIPlayer.Difficulty.HARD
		_:
			return AIPlayer.Difficulty.NORMAL

# 分发起手卡牌
func _deal_starting_hands():
	for player_id in range(PLAYER_COUNT):
		var hand_manager = HandCardManager.new(player_id)
		hand_managers[player_id] = hand_manager
		
		var deck = player_decks[player_id]
		# 创建剩余套牌的副本（深拷贝）
		var remaining_deck: Array[Card] = []
		for card in deck:
			remaining_deck.append(card.duplicate_card())
		player_remaining_decks[player_id] = remaining_deck
		
		# 分发前5张作为起手
		var starting_count = min(5, remaining_deck.size())
		for i in range(starting_count):
			var card = remaining_deck[i]
			hand_manager.add_card(card)
		
		# 从剩余套牌中移除已分发的卡牌
		remaining_deck = remaining_deck.slice(starting_count)
		player_remaining_decks[player_id] = remaining_deck

# 部署阶段：人类玩家部署
func deploy_human_player(selected_sprite_ids: Array[String], deploy_positions: Array[Vector2i]):
	var required_count = get_required_human_deploy_count()
	if selected_sprite_ids.size() != required_count or deploy_positions.size() != required_count:
		push_error("部署数量必须为 " + str(required_count) + " 个")
		return
	var sprites = sprite_deploy.deploy_human_player(HUMAN_PLAYER_ID, selected_sprite_ids, deploy_positions)
	all_sprites.append_array(sprites)
	_connect_sprite_signals(sprites)
	# 部署后更新视野
	update_all_players_vision()

# 部署阶段：AI玩家部署
func deploy_ai_players():
	if training_mode:
		_deploy_training_enemies()
		return
	for ai_id in range(1, PLAYER_COUNT):
		var sprites = sprite_deploy.deploy_ai_player(ai_id)
		all_sprites.append_array(sprites)
		_connect_sprite_signals(sprites)
		
		# 创建AI玩家
		var difficulty = _get_ai_player_difficulty(ai_id)
		var ai_player = AIPlayer.new(ai_id, difficulty, game_map, sprites, hand_managers[ai_id], energy_manager, contest_point_manager)
		ai_players[ai_id] = ai_player
	# AI部署后更新视野
	update_all_players_vision()

# 连接精灵信号
func _connect_sprite_signals(sprites: Array[Sprite]):
	for sprite in sprites:
		sprite.sprite_died.connect(_on_sprite_died.bind(sprite))
		# 注意：bounty_acquired信号会传递sprite参数，不需要bind
		sprite.bounty_acquired.connect(_on_sprite_bounty_acquired)
		# 连接精灵移动信号以更新视野
		sprite.sprite_moved.connect(_on_sprite_vision_changed)

# 处理精灵部署事件（渲染精灵）
func _on_sprite_deployed(sprite: Sprite, _player_id: int, _position: Vector2i, renderer: SpriteRenderer):
	if renderer:
		renderer.render_sprite(sprite)
		print("精灵已渲染: ", sprite.sprite_id, " 位置: ", sprite.hex_position)

# 开始游戏回合
func start_playing_phase():
	current_phase = GamePhase.PLAYING
	phase_changed.emit(current_phase)
	
	# 确保视野已初始化
	update_all_players_vision()
	
	current_round = 1
	start_round()

# 开始回合
func start_round():
	round_started.emit(current_round)
	
	# 重置行动提交状态
	actions_submitted.clear()
	for player_id in range(PLAYER_COUNT):
		actions_submitted[player_id] = false
	_auto_submit_inactive_players()
	
	# 初始化回合
	_initialize_round()
	
	# 开始回合计时
	turn_time_remaining = HUMAN_TURN_TIME
	_start_turn_timer()
	
	# 注意：AI行动不在回合开始时生成，而是在人类玩家提交回合后生成
	# 这样可以确保AI和人类玩家的行动在同一回合结算

# 初始化回合
func _initialize_round():
	# 结算延迟卡牌效果与持续区域效果
	if delayed_effect_manager:
		delayed_effect_manager.resolve_pending_effects(game_map, terrain_manager, all_sprites)
		delayed_effect_manager.tick_active_fields(all_sprites, game_map, terrain_manager)
		# 延迟效果可能会创建地形变化请求（例如地形卡牌延迟生效或持续区域到期触发的地形效果）
		# 这些请求不经过行动结算器，因此需要在此处立即结算，确保地形在回合开始前更新
		if terrain_manager:
			terrain_manager.resolve_terrain_changes()
	# 每回合为所有玩家自动增长1点能量
	if energy_manager:
		for player_id in range(PLAYER_COUNT):
			energy_manager.add_energy(player_id, 1)
	
	# 重置所有精灵的行动计数
	sprite_action_counts.clear()
	
	# 所有精灵开始回合
	for sprite in all_sprites:
		if sprite.is_alive:
			sprite.start_turn()
			# 初始化该精灵的行动计数
			sprite_action_counts[sprite.sprite_id] = {"move": 0, "attack": 0}
	
	# 检查赏金生成
	var entering_sprites: Array[Sprite] = []
	for sprite in all_sprites:
		if sprite.is_alive and game_map.is_in_bounty_zone(sprite.hex_position):
			entering_sprites.append(sprite)
	contest_point_manager.check_bounty_generation(entering_sprites, current_round)
	contest_point_manager.process_pending_bounty(all_sprites, current_round)
	_update_bounty_status_ui()
	
	# 更新地形效果持续时间
	terrain_manager.update_terrain_durations()
	
	# 处理水流传播（每回合开始时）
	terrain_manager.spread_water_flow()
	
	# 处理焦土地形伤害（每回合开始时，所有在焦土上的精灵-1血）
	for sprite in all_sprites:
		if sprite.is_alive:
			var terrain = game_map.get_terrain(sprite.hex_position)
			if terrain and terrain.terrain_type == TerrainTile.TerrainType.SCORCHED:
				sprite.take_damage(1)
				print("焦土伤害: ", sprite.sprite_name, " 在焦土上受到1点伤害，当前血量: ", sprite.current_hp)
	
	# 更新卡牌冷却
	for player_id in hand_managers.keys():
		var hand = hand_managers[player_id]
		for card in hand.hand_cards:
			card.update_cooldown()

# 开始回合计时
func _start_turn_timer():
	# 使用Timer节点或_process实现
	pass

func _process(delta):
	if current_phase == GamePhase.PLAYING:
		if turn_time_remaining > 0:
			turn_time_remaining -= delta
			if turn_time_remaining <= 0:
				# 时间到，强制提交（如果还未提交）
				# 注意：暂时禁用自动提交，让玩家手动控制回合结束
				# if not actions_submitted.get(HUMAN_PLAYER_ID, false):
				# 	submit_human_actions([])  # 空行动
				pass

# 生成AI行动
func _generate_ai_actions():
	for ai_id in ai_players.keys():
		var ai = ai_players[ai_id]
		ai.update_state()
		var actions = ai.generate_actions()
		
		# 添加行动到结算器
		for action in actions:
			action_resolver.add_action(action.player_id, action.action_type, action.sprite, action.target, action.card, action.data)
		
		# 标记为已提交
		actions_submitted[ai_id] = true
		action_submitted.emit(ai_id)

# 添加人类玩家行动（不立即提交，等待回合结束）
# 返回 Dictionary: {"success": bool, "message": String}
func add_human_action(action: ActionResolver.Action) -> Dictionary:
	if actions_submitted.get(HUMAN_PLAYER_ID, false):
		return {"success": false, "message": "回合已提交，无法添加行动"}
	
	# 检查行动限制（每回合每个精灵只能进行一次移动和一次攻击/施法）
	var check_result = _can_add_action(action)
	if not check_result.success:
		return check_result
	
	# 添加行动到结算器
	action_resolver.add_action(action.player_id, action.action_type, action.sprite, action.target, action.card, action.data)
	
	# 更新行动计数
	_record_action(action)
	
	# 发出信号通知UI更新预览
	action_added.emit(action)
	
	return {"success": true, "message": ""}

# 提交人类玩家行动（旧方法，保留兼容性）
func submit_human_actions(actions: Array[ActionResolver.Action]):
	if actions_submitted.get(HUMAN_PLAYER_ID, false):
		return  # 已经提交过了
	
	# 添加行动到结算器
	for action in actions:
		action_resolver.add_action(action.player_id, action.action_type, action.sprite, action.target, action.card, action.data)
	
	# 立即提交（用于AI或特殊情况）
	submit_human_turn()

# 提交人类玩家回合（按下回合结束按钮时调用）
func submit_human_turn():
	if actions_submitted.get(HUMAN_PLAYER_ID, false):
		return  # 已经提交过了
	
	actions_submitted[HUMAN_PLAYER_ID] = true
	action_submitted.emit(HUMAN_PLAYER_ID)
	
	# 人类玩家提交后，生成AI行动
	_generate_ai_actions()
	
	# 检查是否所有玩家都已提交
	_check_all_submitted()

# 检查是否可以添加行动（限制每回合每个精灵只能进行一次移动和一次攻击/施法）
# 返回 Dictionary: {"success": bool, "message": String}
func _can_add_action(action: ActionResolver.Action) -> Dictionary:
	if not action.sprite:
		return {"success": true, "message": ""}  # 没有精灵的行动（如地形变化）不受限制
	
	var sprite_id = action.sprite.sprite_id
	var sprite_name = action.sprite.sprite_name
	var counts = sprite_action_counts.get(sprite_id, {"move": 0, "attack": 0})
	var is_basic_action = action.data.get("is_basic_action", false)
	
	# 检查行动类型
	match action.action_type:
		ActionResolver.ActionType.MOVE:
			# 移动行动：基本移动和卡牌移动都受限制，每回合只能移动一次
			if counts.move >= 1:
				return {"success": false, "message": "您已经移动过该精灵"}
		ActionResolver.ActionType.ATTACK:
			# 攻击行动：基本攻击不受限制（可以多次弃牌攻击），卡牌攻击受限制
			if not is_basic_action and counts.attack >= 1:
				return {"success": false, "message": "您已经攻击过该精灵"}
		ActionResolver.ActionType.TERRAIN, ActionResolver.ActionType.EFFECT:
			# 地形变化、效果：都算作施法/攻击，共享一次限制（基本行动不受限制）
			if not is_basic_action and counts.attack >= 1:
				var action_name = ""
				match action.action_type:
					ActionResolver.ActionType.TERRAIN:
						action_name = "施法"
					ActionResolver.ActionType.EFFECT:
						action_name = "施法"
				return {"success": false, "message": "您已经" + action_name + "过该精灵"}
		_:
			# 其他类型的行动不受限制
			pass
	
	return {"success": true, "message": ""}

# 记录行动（更新计数）
func _record_action(action: ActionResolver.Action):
	if not action.sprite:
		return  # 没有精灵的行动不记录
	
	var sprite_id = action.sprite.sprite_id
	var counts = sprite_action_counts.get(sprite_id, {"move": 0, "attack": 0})
	var is_basic_action = action.data.get("is_basic_action", false)
	
	# 更新计数
	match action.action_type:
		ActionResolver.ActionType.MOVE:
			# 移动行动：基本移动和卡牌移动都计数
			counts.move += 1
		ActionResolver.ActionType.ATTACK:
			# 攻击行动：只有卡牌攻击计数，基本攻击不计数（可以多次弃牌攻击）
			if not is_basic_action:
				counts.attack += 1
		ActionResolver.ActionType.TERRAIN, ActionResolver.ActionType.EFFECT:
			# 地形变化、效果：只有卡牌行动计数，基本行动不计数
			if not is_basic_action:
				counts.attack += 1
	
	sprite_action_counts[sprite_id] = counts

# 撤销行动记录（更新计数）
func _unrecord_action(action: ActionResolver.Action):
	if not action.sprite:
		return  # 没有精灵的行动不记录
	
	var sprite_id = action.sprite.sprite_id
	var counts = sprite_action_counts.get(sprite_id, {"move": 0, "attack": 0})
	var is_basic_action = action.data.get("is_basic_action", false)
	
	# 减少计数
	match action.action_type:
		ActionResolver.ActionType.MOVE:
			# 移动行动：基本移动和卡牌移动都计数
			counts.move = max(0, counts.move - 1)
		ActionResolver.ActionType.ATTACK:
			# 攻击行动：只有卡牌攻击计数，基本攻击不计数
			if not is_basic_action:
				counts.attack = max(0, counts.attack - 1)
		ActionResolver.ActionType.TERRAIN, ActionResolver.ActionType.EFFECT:
			# 地形变化、效果：只有卡牌行动计数，基本行动不计数
			if not is_basic_action:
				counts.attack = max(0, counts.attack - 1)
	
	sprite_action_counts[sprite_id] = counts

# 取消行动（从队列中移除并返回卡牌到手牌）
# 返回 Dictionary: {"success": bool, "message": String}
func cancel_action(action: ActionResolver.Action) -> Dictionary:
	if actions_submitted.get(HUMAN_PLAYER_ID, false):
		return {"success": false, "message": "回合已提交，无法取消行动"}
	
	# 检查行动是否存在
	var action_exists = false
	for a in action_resolver.actions:
		if a == action:
			action_exists = true
			break
	
	if not action_exists:
		return {"success": false, "message": "找不到要取消的行动"}
	
	# 如果行动包含卡牌，先检查手牌是否有空间
	if action.card:
		var hand_manager = hand_managers.get(HUMAN_PLAYER_ID)
		if hand_manager:
			if hand_manager.is_hand_full():
				return {"success": false, "message": "手牌已满，无法取消此行动"}
	
	# 从行动队列中移除
	var removed_action = action_resolver.remove_action_by_reference(action)
	if not removed_action:
		return {"success": false, "message": "找不到要取消的行动"}
	
	# 撤销行动计数
	_unrecord_action(removed_action)
	
	# 如果行动包含卡牌，返回手牌
	if removed_action.card:
		var hand_manager = hand_managers.get(HUMAN_PLAYER_ID)
		if hand_manager:
			print("取消行动：尝试返回卡牌 ", removed_action.card.card_name, " 到手牌")
			print("取消行动：当前手牌数量: ", hand_manager.hand_cards.size(), " 手牌上限: ", HandCardManager.MAX_HAND_SIZE)
			var added = hand_manager.add_card(removed_action.card)
			if added:
				print("取消行动：成功返回卡牌到手牌，当前手牌数量: ", hand_manager.hand_cards.size())
			else:
				# 这种情况理论上不应该发生，因为我们已经检查过了
				print("警告：取消行动时卡牌无法返回手牌（手牌可能已满）")
	
	return {"success": true, "message": "行动已取消"}

# 检查是否所有玩家都已提交
func _check_all_submitted():
	var all_submitted = true
	for player_id in range(PLAYER_COUNT):
		if not actions_submitted.get(player_id, false):
			all_submitted = false
			break
	
	if all_submitted:
		all_actions_submitted.emit()
		# 结算行动（异步执行，需要等待完成）
		await _resolve_round()

# 结算回合
func _resolve_round():
	# 结算所有行动
	action_resolver.resolve_all_actions()
	
	# 确保所有地形变化请求都已处理（包括延迟添加的请求）
	# 这很重要：如果地形变化请求在行动结算后仍然存在，需要立即处理
	# 这样下一个回合开始时，地形已经是正确的状态
	if terrain_manager and terrain_manager.terrain_change_requests.size() > 0:
		print("GameManager: 回合结算后仍有 ", terrain_manager.terrain_change_requests.size(), " 个地形变化请求，立即处理")
		terrain_manager.resolve_terrain_changes()
	
	# 争夺赏金
	contest_point_manager.contest_bounty(all_sprites)
	_update_bounty_status_ui()
	
	# 检查公共争夺点
	contest_point_manager.check_contest_points(all_sprites, current_round)
	
	# 持有赏金的玩家获得能量
	for sprite in all_sprites:
		if sprite.is_alive and sprite.has_bounty:
			energy_manager.on_bounty_held(sprite.owner_player_id)
	
	# 同步状态
	state_sync.sync_all_sprites(all_sprites)
	
	# 回合结束后，更新所有精灵的位置（确保地形高度变化后精灵位置正确）
	# 使用 await get_tree().process_frame 确保地形变化信号已处理完成
	if sprite_renderer:
		# 等待一帧，确保所有地形变化信号都已发出
		await get_tree().process_frame
		# 再等待一帧，确保所有 call_deferred 的调用都已执行（地形变化信号处理）
		await get_tree().process_frame
		# 再等待一帧，确保地形渲染器也已更新
		await get_tree().process_frame
		_update_all_sprite_positions_after_round()
	
	# 检查胜利/失败条件
	_check_victory_conditions()
	
	# 回合结束
	end_round()

# 更新所有精灵位置（在回合结算后，已确保地形变化完成）
func _update_all_sprite_positions_after_round():
	if sprite_renderer:
		sprite_renderer.update_all_sprite_positions()

# 检查胜利条件
func _check_victory_conditions():
	# 检查胜利
	victory_manager.check_victory_condition(all_sprites)
	
	# 检查失败（2人对战）
	for player_id in range(PLAYER_COUNT):
		var player_sprites = sprite_deploy.get_player_sprites(player_id)
		if not _should_check_defeat_for_player(player_id, player_sprites):
			continue
		victory_manager.check_defeat_condition(player_id, player_sprites)
	
	if victory_manager.is_game_ended():
		current_phase = GamePhase.ENDED
		phase_changed.emit(current_phase)

# 结束回合
func end_round():
	if status_effect_manager:
		status_effect_manager.advance_round()
	round_ended.emit(current_round)
	
	# 从玩家自己的套牌中抽卡
	for player_id in range(PLAYER_COUNT):
		var remaining_deck = player_remaining_decks.get(player_id, [])
		if remaining_deck.size() > 0:
			# 从剩余套牌中抽取第一张
			var card = remaining_deck[0]
			remaining_deck.remove_at(0)
			player_remaining_decks[player_id] = remaining_deck
			
			var hand = hand_managers[player_id]
			var _discarded = hand.draw_card_with_discard(card)
			# 如果返回了需要弃置的卡牌，可以在这里处理
		else:
			# 套牌用尽，可以在这里处理（例如洗牌重新开始，或者不再抽卡）
			print("玩家 ", player_id, " 的套牌已用尽")
	
	# 下一回合
	current_round += 1
	if current_phase == GamePhase.PLAYING:
		start_round()

# 获取玩家剩余套牌（用于争夺点奖励）
func _get_player_remaining_deck(player_id: int) -> Array[Card]:
	return player_remaining_decks.get(player_id, [])

# 从玩家剩余套牌中抽取卡牌（用于争夺点奖励）
func draw_card_from_player_deck(player_id: int) -> Card:
	var remaining_deck = player_remaining_decks.get(player_id, [])
	if remaining_deck.size() > 0:
		var card = remaining_deck[0]
		remaining_deck.remove_at(0)
		player_remaining_decks[player_id] = remaining_deck
		return card
	return null

# 信号处理
func _on_sprite_died(sprite: Sprite):
	if sprite.has_bounty:
		contest_point_manager.lose_bounty()
		_update_bounty_status_ui()
	if status_effect_manager:
		status_effect_manager.clear_statuses(sprite)
	if sprite_renderer:
		sprite_renderer.remove_sprite(sprite)
	if sprite_deploy:
		sprite_deploy.remove_sprite(sprite)
	all_sprites.erase(sprite)
	# 精灵死亡后更新视野
	_on_sprite_vision_changed(sprite, sprite.hex_position, sprite.hex_position)

func _on_bounty_generated(_hex: Vector2i):
	_update_bounty_status_ui()

func _on_sprite_bounty_acquired(_sprite: Sprite):
	pass

func _on_bounty_acquired(_sprite: Sprite):
	_update_bounty_status_ui()

func _on_bounty_lost(_sprite: Sprite):
	_update_bounty_status_ui()

func _update_bounty_status_ui():
	if not contest_point_manager or not main_ui:
		return
	var status = contest_point_manager.bounty_status
	var status_text = "赏金状态：未触发"
	match status:
		ContestPointManager.BountyStatus.NONE:
			status_text = "赏金状态：未触发"
		ContestPointManager.BountyStatus.PENDING:
			var pending_round_num = contest_point_manager.get_pending_round()
			if pending_round_num > 0:
				status_text = "赏金状态：已触发，预计第" + str(pending_round_num) + "回合生成"
			else:
				status_text = "赏金状态：已触发，等待生成"
		ContestPointManager.BountyStatus.GENERATED:
			var spawn_hex = contest_point_manager.get_active_bounty_hex()
			if spawn_hex != Vector2i(-1, -1):
				status_text = "赏金状态：已出现于 " + str(spawn_hex)
			else:
				status_text = "赏金状态：已出现"
		ContestPointManager.BountyStatus.HELD:
			var holder = contest_point_manager.bounty_holder
			var holder_pos = contest_point_manager.get_bounty_holder_position()
			if holder:
				status_text = "赏金状态：玩家" + str(holder.owner_player_id) + " 持有，位置 " + str(holder_pos)
			else:
				status_text = "赏金状态：被持有"
		ContestPointManager.BountyStatus.DROPPED:
			var drop_hex = contest_point_manager.get_active_bounty_hex()
			if drop_hex != Vector2i(-1, -1):
				status_text = "赏金状态：掉落在 " + str(drop_hex)
			else:
				status_text = "赏金状态：已掉落"
	main_ui.update_bounty_status(status_text)

func _on_game_ended(_state: VictoryManager.GameState, _winner_id: int):
	if _state == VictoryManager.GameState.VICTORY:
		_show_victory_screen(_winner_id)

func _show_victory_screen(winner_id: int):
	if victory_screen and is_instance_valid(victory_screen):
		victory_screen.queue_free()
	
	if not VICTORY_SCREEN_SCENE:
		return
	
	victory_screen = VICTORY_SCREEN_SCENE.instantiate()
	
	var parent = main_ui if main_ui else get_node_or_null("UI")
	if parent:
		parent.add_child(victory_screen)
	else:
		add_child(victory_screen)
	
	if victory_screen and victory_screen.has_method("set_result"):
		victory_screen.set_result(winner_id)

# 视野变化处理（精灵移动或死亡时调用）
func _on_sprite_vision_changed(sprite: Sprite, _from: Vector2i, _to: Vector2i):
	if not fog_of_war_manager:
		return

	if sprite and sprite.has_bounty:
		_update_bounty_status_ui()
	
	var player_id = sprite.owner_player_id
	if player_id < 0:
		return
	
	# 获取该玩家的所有精灵
	var player_sprites = sprite_deploy.get_player_sprites(player_id)
	if not player_sprites:
		# 如果玩家没有精灵了，清空视野
		fog_of_war_manager.clear_player_vision(player_id)
		return
	
	# 更新该玩家的视野
	fog_of_war_manager.update_player_vision(player_id, player_sprites, game_map)

# 更新所有玩家的视野
func update_all_players_vision():
	if not fog_of_war_manager:
		return
	
	for player_id in range(PLAYER_COUNT):
		var player_sprites = sprite_deploy.get_player_sprites(player_id)
		fog_of_war_manager.update_player_vision(player_id, player_sprites, game_map)

# 设置UI
func _setup_ui():
	var ui_node = get_node_or_null("UI")
	main_ui = ui_node as MainUI
	if ui_node and ui_node.has_method("set_game_manager"):
		ui_node.set_game_manager(self)
	_update_bounty_status_ui()

# 设置地图渲染
func _setup_map_rendering():
	# 获取3D世界节点
	var world_node = get_node_or_null("UI/MapViewport/SubViewport/World")
	if not world_node:
		push_error("无法找到3D世界节点")
		return
	
	# 等待地图完全初始化
	await get_tree().process_frame
	await get_tree().process_frame  # 多等一帧确保地图配置加载完成
	
	# 将GameMap添加到世界节点
	if game_map and game_map.get_parent() != world_node:
		if game_map.get_parent():
			game_map.get_parent().remove_child(game_map)
		world_node.add_child(game_map)
	
	# 等待GameMap完全初始化
	await get_tree().process_frame
	
	# 创建地形渲染器
	terrain_renderer = TerrainRenderer.new(game_map)
	world_node.add_child(terrain_renderer)
	
	# 连接迷雾系统到地形渲染器
	if fog_of_war_manager:
		terrain_renderer.set_fog_manager(fog_of_war_manager, HUMAN_PLAYER_ID)
		print("GameManager: 战争迷雾系统已连接到地形渲染器")
	
	# 创建精灵渲染器
	sprite_renderer = SpriteRenderer.new()
	sprite_renderer.game_map = game_map  # 传递地图引用
	sprite_renderer.all_sprites = all_sprites  # 传递所有精灵列表
	world_node.add_child(sprite_renderer)
	
	# 创建赏金可视化管理器
	bounty_visual_manager = BountyVisualManager.new()
	world_node.add_child(bounty_visual_manager)
	bounty_visual_manager.setup(game_map, contest_point_manager, sprite_renderer)
	
	# 连接迷雾系统到精灵渲染器
	if fog_of_war_manager:
		sprite_renderer.set_fog_manager(fog_of_war_manager, HUMAN_PLAYER_ID)
		print("GameManager: 战争迷雾系统已连接到精灵渲染器")
	
	set_fog_enabled(fog_enabled_state)
	
	# 连接精灵部署信号到渲染器
	sprite_deploy.sprite_deployed.connect(_on_sprite_deployed.bind(sprite_renderer))
	
	# 连接地形变化信号到精灵渲染器（当地形高度变化时，更新精灵位置）
	if game_map and sprite_renderer:
		game_map.terrain_changed.connect(_on_terrain_changed_for_sprites)
		print("GameManager: 地形变化信号已连接到精灵位置更新")
	
	print("地图渲染设置完成，地形数量: ", game_map.terrain_tiles.size())

func get_required_human_deploy_count() -> int:
	return max(1, human_deploy_count)

func is_training_mode_enabled() -> bool:
	return training_mode

func _deploy_training_enemies():
	if training_enemy_layout.is_empty():
		return
	var spawned: Array[Sprite] = []
	for enemy_def in training_enemy_layout:
		if not enemy_def is Dictionary:
			continue
		var sprite_id: String = enemy_def.get("sprite_id", "")
		var coord_dict = enemy_def.get("hex_coord", {})
		if sprite_id.is_empty() or not coord_dict is Dictionary:
			continue
		var coord = Vector2i(coord_dict.get("q", 0), coord_dict.get("r", 0))
		var player_id = int(enemy_def.get("player_id", 1))
		var sprite = sprite_deploy.deploy_custom_sprite(player_id, sprite_id, coord)
		if sprite:
			spawned.append(sprite)
	if spawned.is_empty():
		return
	all_sprites.append_array(spawned)
	_connect_sprite_signals(spawned)
	update_all_players_vision()
	training_enemy_layout.clear()

func set_fog_enabled(enabled: bool):
	fog_enabled_state = enabled
	if terrain_renderer:
		terrain_renderer.set_fog_enabled(enabled)
	if sprite_renderer:
		sprite_renderer.set_fog_enabled(enabled)

func is_fog_enabled() -> bool:
	return fog_enabled_state

func _refresh_training_enemy_player_ids():
	training_enemy_player_ids.clear()
	for enemy_def in training_enemy_layout:
		if not enemy_def is Dictionary:
			continue
		var pid = int(enemy_def.get("player_id", 1))
		if pid not in training_enemy_player_ids:
			training_enemy_player_ids.append(pid)

func _should_check_defeat_for_player(player_id: int, player_sprites: Array[Sprite]) -> bool:
	if player_id == HUMAN_PLAYER_ID:
		return true
	if not player_sprites.is_empty():
		return true
	if game_map and game_map.spawn_points_by_player.has(player_id):
		return true
	if player_id in training_enemy_player_ids:
		return true
	return false

func _auto_submit_inactive_players():
	if not training_mode:
		return
	for player_id in range(PLAYER_COUNT):
		if player_id == HUMAN_PLAYER_ID:
			continue
		actions_submitted[player_id] = true

# 设置视口适配
func _setup_viewport_adaptation():
	var container = get_node_or_null("UI/MapViewport") as SubViewportContainer
	var sub_viewport = get_node_or_null("UI/MapViewport/SubViewport") as SubViewport
	
	if not container or not sub_viewport:
		push_error("无法找到视口容器或SubViewport")
		return
	
	# 当 stretch = true 时，SubViewport 的尺寸应该保持固定（如 1920x1080）
	# 容器会自动缩放显示，不需要手动同步尺寸
	# 监听主视口尺寸变化，用于调试或后续处理
	var main_viewport = get_viewport()
	if main_viewport and not main_viewport.size_changed.is_connected(_on_main_viewport_resized):
		main_viewport.size_changed.connect(_on_main_viewport_resized)
	
	print("视口适配已设置 - SubViewport尺寸: ", sub_viewport.size, " 容器拉伸: ", container.stretch)

# 处理地形变化（更新精灵位置）
func _on_terrain_changed_for_sprites(hex_coord: Vector2i, _terrain: TerrainTile):
	if not sprite_renderer:
		return
	
	# 更新该位置的所有精灵的位置（地形高度可能已改变）
	for sprite in all_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			# 延迟一帧更新，确保地形变化已完成
			call_deferred("_update_sprite_position_after_terrain_change", sprite)
	
	# 地形高度变化会影响视野阻挡，需要重新计算所有玩家的视野
	# 延迟一帧更新，确保地形变化已完成
	call_deferred("update_all_players_vision")

# 延迟更新精灵位置（在地形变化后）
func _update_sprite_position_after_terrain_change(sprite: Sprite):
	if sprite_renderer and sprite.is_alive:
		sprite_renderer._update_sprite_position(sprite)

# 处理主视口尺寸变化（用于调试）
func _on_main_viewport_resized():
	var container = get_node_or_null("UI/MapViewport") as SubViewportContainer
	var sub_viewport = get_node_or_null("UI/MapViewport/SubViewport") as SubViewport
	
	if container and sub_viewport:
		var container_rect = container.get_rect()
		print("主视口尺寸变化 - 容器尺寸: ", container_rect.size, " SubViewport尺寸: ", sub_viewport.size)

# 将全局鼠标坐标转换为SubViewport内部坐标
func _get_viewport_local_pos(global_mouse_pos: Vector2) -> Vector2:
	var container = get_node_or_null("UI/MapViewport") as SubViewportContainer
	var sub_viewport = get_node_or_null("UI/MapViewport/SubViewport") as SubViewport
	
	if not container or not sub_viewport:
		return Vector2.ZERO
	
	# 1. 将全局鼠标坐标转换为容器局部坐标
	var container_rect = container.get_global_rect()
	var local_in_container = global_mouse_pos - container_rect.position
	
	# 2. 计算容器到SubViewport的缩放比例（启用stretch_aspect=KEEP时，宽高比一致）
	var container_size = container_rect.size
	var viewport_size = Vector2(sub_viewport.size)
	
	if viewport_size.x == 0 or viewport_size.y == 0:
		return Vector2.ZERO
	
	# 计算缩放比例（取宽高比的最小值，保持宽高比）
	var scale_x = container_size.x / viewport_size.x
	var scale_y = container_size.y / viewport_size.y
	var scale = min(scale_x, scale_y)
	
	if scale == 0:
		return Vector2.ZERO
	
	# 3. 计算居中偏移（如果容器比缩放后的视口大）
	var scaled_viewport_size = viewport_size * scale
	var offset = (container_size - scaled_viewport_size) / 2
	
	# 4. 转换为SubViewport内部坐标（修正偏移和缩放）
	var viewport_pos = (local_in_container - offset) / scale
	
	# 限制在视口范围内
	return viewport_pos.clamped(Vector2.ZERO, viewport_size)
