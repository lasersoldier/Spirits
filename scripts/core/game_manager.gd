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
const PLAYER_COUNT: int = 2  # 1人类 + 1AI

# 人类玩家ID（固定为0）
const HUMAN_PLAYER_ID: int = 0

# 回合计时（秒）
const HUMAN_TURN_TIME: float = 30.0
const AI_TURN_TIME: float = 1.0

# 当前回合剩余时间
var turn_time_remaining: float = 0.0

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
var public_card_pool: PublicCardPool
var hand_managers: Dictionary = {}  # key: player_id, value: HandCardManager
var energy_manager: EnergyManager
var terrain_manager: TerrainManager
var card_interface: CardSpriteInterface
var action_resolver: ActionResolver
var contest_point_manager: ContestPointManager
var victory_manager: VictoryManager
var ai_players: Dictionary = {}  # key: player_id, value: AIPlayer
var state_sync: SpriteStateSyncInterface

# 所有精灵列表
var all_sprites: Array[Sprite] = []

# 渲染器
var terrain_renderer: TerrainRenderer
var sprite_renderer: SpriteRenderer

# 玩家卡组
var player_decks: Dictionary = {}  # key: player_id, value: Array[Card]

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
	_setup_map_rendering()
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
	
	# 初始化卡牌接口
	card_interface = CardSpriteInterface.new(card_library)
	
	# 初始化行动结算器
	action_resolver = ActionResolver.new(game_map, terrain_manager, card_interface, energy_manager)
	
	# 初始化公共卡池
	public_card_pool = PublicCardPool.new()
	
	# 初始化争夺点管理器
	contest_point_manager = ContestPointManager.new(game_map, energy_manager, public_card_pool)
	
	# 初始化胜利管理器
	victory_manager = VictoryManager.new(game_map, contest_point_manager)
	
	# 初始化状态同步
	state_sync = SpriteStateSyncInterface.new()
	
	# 连接信号
	_connect_signals()

func _connect_signals():
	# 连接精灵信号
	# 这些信号会在精灵创建后连接
	
	# 连接争夺点信号
	contest_point_manager.bounty_acquired.connect(_on_bounty_acquired)
	contest_point_manager.bounty_lost.connect(_on_bounty_lost)
	
	# 连接胜利管理器信号
	victory_manager.game_ended.connect(_on_game_ended)

# 开始游戏
func start_game():
	# 构建所有玩家的卡组
	_build_all_decks()
	
	# 初始化公共卡池
	public_card_pool.initialize_pool(player_decks)
	
	# 分发起手卡牌（在发出phase_changed信号之前，确保手牌已准备好）
	_deal_starting_hands()
	
	# 设置阶段并发出信号（此时手牌已准备好，UI可以立即显示）
	current_phase = GamePhase.DEPLOYMENT
	phase_changed.emit(current_phase)

# 构建所有玩家的卡组
func _build_all_decks():
	# 人类玩家：需要手动构建（这里先使用默认构建）
	# 实际应该通过UI让玩家选择
	var human_deck = _build_default_human_deck()
	player_decks[HUMAN_PLAYER_ID] = human_deck
	
	# AI玩家：按难度自动生成（只有1个AI）
	var ai_id = 1
	var difficulty = "normal"  # 可以配置
	var deck = deck_builder.build_ai_deck(difficulty, ai_id)
	player_decks[ai_id] = deck

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

# 分发起手卡牌
func _deal_starting_hands():
	for player_id in range(PLAYER_COUNT):
		var hand_manager = HandCardManager.new(player_id)
		hand_managers[player_id] = hand_manager
		
		var deck = player_decks[player_id]
		# 分发前5张作为起手
		for i in range(min(5, deck.size())):
			hand_manager.add_card(deck[i])

# 部署阶段：人类玩家部署
func deploy_human_player(selected_sprite_ids: Array[String], deploy_positions: Array[Vector2i]):
	var sprites = sprite_deploy.deploy_human_player(HUMAN_PLAYER_ID, selected_sprite_ids, deploy_positions)
	all_sprites.append_array(sprites)
	_connect_sprite_signals(sprites)

# 部署阶段：AI玩家部署
func deploy_ai_players():
	for ai_id in range(1, PLAYER_COUNT):
		var sprites = sprite_deploy.deploy_ai_player(ai_id)
		all_sprites.append_array(sprites)
		_connect_sprite_signals(sprites)
		
		# 创建AI玩家
		var difficulty = AIPlayer.Difficulty.NORMAL
		var ai_player = AIPlayer.new(ai_id, difficulty, game_map, sprites, hand_managers[ai_id], energy_manager, contest_point_manager)
		ai_players[ai_id] = ai_player

# 连接精灵信号
func _connect_sprite_signals(sprites: Array[Sprite]):
	for sprite in sprites:
		sprite.sprite_died.connect(_on_sprite_died.bind(sprite))
		sprite.bounty_acquired.connect(_on_sprite_bounty_acquired.bind(sprite))

# 处理精灵部署事件（渲染精灵）
func _on_sprite_deployed(sprite: Sprite, _player_id: int, _position: Vector2i, renderer: SpriteRenderer):
	if renderer:
		renderer.render_sprite(sprite)
		print("精灵已渲染: ", sprite.sprite_id, " 位置: ", sprite.hex_position)

# 开始游戏回合
func start_playing_phase():
	current_phase = GamePhase.PLAYING
	phase_changed.emit(current_phase)
	
	current_round = 1
	start_round()

# 开始回合
func start_round():
	round_started.emit(current_round)
	
	# 重置行动提交状态
	actions_submitted.clear()
	for player_id in range(PLAYER_COUNT):
		actions_submitted[player_id] = false
	
	# 初始化回合
	_initialize_round()
	
	# 开始回合计时
	turn_time_remaining = HUMAN_TURN_TIME
	_start_turn_timer()
	
	# AI自动生成行动
	_generate_ai_actions()

# 初始化回合
func _initialize_round():
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
	contest_point_manager.check_bounty_generation(entering_sprites)
	
	# 更新地形效果持续时间
	terrain_manager.update_terrain_durations()
	
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
				if not actions_submitted.get(HUMAN_PLAYER_ID, false):
					submit_human_actions([])  # 空行动

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
func add_human_action(action: ActionResolver.Action):
	if actions_submitted.get(HUMAN_PLAYER_ID, false):
		return  # 已经提交过了
	
	# 检查行动限制（每回合每个精灵只能进行一次移动和一次攻击）
	if not _can_add_action(action):
		print("无法添加行动：该精灵本回合已经执行过此类型的行动")
		return
	
	# 添加行动到结算器
	action_resolver.add_action(action.player_id, action.action_type, action.sprite, action.target, action.card, action.data)
	
	# 更新行动计数
	_record_action(action)
	
	# 发出信号通知UI更新预览
	action_added.emit(action)

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
	
	# 检查是否所有玩家都已提交
	_check_all_submitted()

# 检查是否可以添加行动（限制每回合每个精灵只能进行一次移动和一次攻击）
func _can_add_action(action: ActionResolver.Action) -> bool:
	if not action.sprite:
		return true  # 没有精灵的行动（如地形变化）不受限制
	
	var sprite_id = action.sprite.sprite_id
	var counts = sprite_action_counts.get(sprite_id, {"move": 0, "attack": 0})
	
	# 基本行动（弃牌行动）不受限制，卡牌行动受限制
	var is_basic_action = action.data.get("is_basic_action", false)
	if is_basic_action:
		return true  # 基本行动不受限制
	
	# 检查行动类型
	match action.action_type:
		ActionResolver.ActionType.MOVE:
			if counts.move >= 1:
				return false
		ActionResolver.ActionType.ATTACK:
			if counts.attack >= 1:
				return false
		_:
			# 其他类型的行动不受限制
			pass
	
	return true

# 记录行动（更新计数）
func _record_action(action: ActionResolver.Action):
	if not action.sprite:
		return  # 没有精灵的行动不记录
	
	var sprite_id = action.sprite.sprite_id
	var counts = sprite_action_counts.get(sprite_id, {"move": 0, "attack": 0})
	
	# 基本行动（弃牌行动）不计数，卡牌行动计数
	var is_basic_action = action.data.get("is_basic_action", false)
	if is_basic_action:
		return  # 基本行动不计数
	
	# 更新计数
	match action.action_type:
		ActionResolver.ActionType.MOVE:
			counts.move += 1
		ActionResolver.ActionType.ATTACK:
			counts.attack += 1
	
	sprite_action_counts[sprite_id] = counts

# 检查是否所有玩家都已提交
func _check_all_submitted():
	var all_submitted = true
	for player_id in range(PLAYER_COUNT):
		if not actions_submitted.get(player_id, false):
			all_submitted = false
			break
	
	if all_submitted:
		all_actions_submitted.emit()
		# 结算行动
		_resolve_round()

# 结算回合
func _resolve_round():
	# 结算所有行动
	action_resolver.resolve_all_actions()
	
	# 争夺赏金
	contest_point_manager.contest_bounty(all_sprites)
	
	# 检查公共争夺点
	contest_point_manager.check_contest_points(all_sprites, current_round)
	
	# 持有赏金的玩家获得能量
	for sprite in all_sprites:
		if sprite.is_alive and sprite.has_bounty:
			energy_manager.on_bounty_held(sprite.owner_player_id)
	
	# 同步状态
	state_sync.sync_all_sprites(all_sprites)
	
	# 检查胜利/失败条件
	_check_victory_conditions()
	
	# 回合结束
	end_round()

# 检查胜利条件
func _check_victory_conditions():
	# 检查胜利
	victory_manager.check_victory_condition(all_sprites)
	
	# 检查失败（2人对战）
	for player_id in range(PLAYER_COUNT):
		var player_sprites = sprite_deploy.get_player_sprites(player_id)
		victory_manager.check_defeat_condition(player_id, player_sprites)
	
	if victory_manager.is_game_ended():
		current_phase = GamePhase.ENDED
		phase_changed.emit(current_phase)

# 结束回合
func end_round():
	round_ended.emit(current_round)
	
	# 从公共卡池抽卡
	for player_id in range(PLAYER_COUNT):
		var card = public_card_pool.draw_card(player_id)
		if card:
			var hand = hand_managers[player_id]
			var _discarded = hand.draw_card_with_discard(card)
			# 如果返回了需要弃置的卡牌，可以在这里处理
	
	# 下一回合
	current_round += 1
	if current_phase == GamePhase.PLAYING:
		start_round()

# 信号处理
func _on_sprite_died(sprite: Sprite):
	if sprite.has_bounty:
		contest_point_manager.lose_bounty()

func _on_sprite_bounty_acquired(_sprite: Sprite):
	pass

func _on_bounty_acquired(_sprite: Sprite):
	pass

func _on_bounty_lost(_sprite: Sprite):
	pass

func _on_game_ended(_state: VictoryManager.GameState, _winner_id: int):
	pass

# 设置UI
func _setup_ui():
	var ui_node = get_node_or_null("UI")
	if ui_node and ui_node.has_method("set_game_manager"):
		ui_node.set_game_manager(self)

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
	
	# 创建精灵渲染器
	sprite_renderer = SpriteRenderer.new()
	sprite_renderer.game_map = game_map  # 传递地图引用
	world_node.add_child(sprite_renderer)
	
	# 连接精灵部署信号到渲染器
	sprite_deploy.sprite_deployed.connect(_on_sprite_deployed.bind(sprite_renderer))
	
	print("地图渲染设置完成，地形数量: ", game_map.terrain_tiles.size())

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
