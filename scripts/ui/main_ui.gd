class_name MainUI
extends Control

# UI节点引用
@onready var map_viewport: SubViewportContainer
@onready var sprite_status_panel: Panel
@onready var hand_card_area: HBoxContainer
@onready var energy_label: Label
@onready var bounty_label: Label
@onready var turn_timer_label: Label

# 游戏管理器引用
var game_manager: GameManager

# 部署UI
var deploy_ui: DeployUI = null

# 地图点击处理器
var map_click_handler: MapClickHandler = null

# 已连接手牌信号的玩家ID集合
var connected_hand_players: Array[int] = []

# 当前拖动的卡牌
var dragging_card_ui: CardUI = null
var dragging_card: Card = null

# 箭头指示器
var arrow_line: Line2D = null
var card_arrow_container: Control = null

# 卡牌使用阶段
var card_use_state: Dictionary = {
	"active": false,
	"card": null,
	"source_sprite": null,
	"target_type": "",  # "attack", "terrain", "support"
	"highlighted_sprites": [],  # 高亮的精灵
	"highlighted_hexes": []  # 高亮的六边形
}

# 弃牌行动阶段
var discard_action_state: Dictionary = {
	"active": false,
	"card": null,
	"action_type": "",  # "attack" 或 "move"
	"source_sprite": null,
	"target_sprite": null,  # 攻击目标精灵或拖拽到的精灵
	"highlighted_sprites": [],  # 可攻击的精灵或己方精灵
	"highlighted_hexes": []  # 可移动的位置
}

# 右键拖拽状态
var right_dragging_card: Card = null
var right_dragging_card_ui: CardUI = null  # 右键拖拽的卡牌UI

# 取消使用按钮
var cancel_card_button: Button = null

# 基本行动选择按钮
var basic_action_buttons: Dictionary = {}  # "attack" 和 "move" 按钮

func _ready():
	# 初始化UI节点
	map_viewport = get_node_or_null("MapViewport") as SubViewportContainer
	sprite_status_panel = get_node_or_null("SpriteStatusPanel") as Panel
	hand_card_area = get_node_or_null("HandCardArea") as HBoxContainer
	energy_label = get_node_or_null("EnergyLabel") as Label
	bounty_label = get_node_or_null("BountyLabel") as Label
	turn_timer_label = get_node_or_null("TurnTimerLabel") as Label
	
	# 创建箭头容器（覆盖整个屏幕）
	card_arrow_container = Control.new()
	card_arrow_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_arrow_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_arrow_container)
	
	# 创建取消使用按钮（初始隐藏）
	cancel_card_button = Button.new()
	cancel_card_button.text = "取消使用"
	cancel_card_button.visible = false
	cancel_card_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	cancel_card_button.position = UIScaleManager.scale_vec2(Vector2(20, 20))
	cancel_card_button.size = UIScaleManager.scale_vec2(Vector2(150, 50))
	UIScaleManager.apply_scale_to_button(cancel_card_button, 18)
	cancel_card_button.pressed.connect(_on_cancel_card_use)
	add_child(cancel_card_button)
	
	# 设置处理输入
	set_process_input(true)

# 处理输入（取消卡牌使用）
func _input(event: InputEvent):
	# 处理取消卡牌使用（右键或ESC键）
	if card_use_state.active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_card_use_phase()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_exit_card_use_phase()
			get_viewport().set_input_as_handled()
			return

# 设置游戏管理器引用
func set_game_manager(gm: GameManager):
	game_manager = gm
	_connect_signals()

func _connect_signals():
	if not game_manager:
		return
	
	game_manager.round_started.connect(_on_round_started)
	game_manager.phase_changed.connect(_on_phase_changed)
	game_manager.all_actions_submitted.connect(_on_all_actions_submitted)
	
	# 连接手牌更新信号（如果手牌管理器已创建）
	_connect_hand_signals()

# 连接手牌更新信号
func _connect_hand_signals():
	if not game_manager:
		return
	
	# 连接所有玩家的手牌更新信号
	for player_id in game_manager.hand_managers.keys():
		# 避免重复连接
		if player_id in connected_hand_players:
			continue
		
		var hand_manager = game_manager.hand_managers[player_id]
		if hand_manager:
			# 连接信号
			hand_manager.hand_updated.connect(_on_hand_updated.bind(player_id))
			connected_hand_players.append(player_id)

# 更新精灵状态面板
func update_sprite_status(_sprites: Array[Sprite]):
	# 更新显示所有精灵的血量、存活状态等
	pass

# 更新手牌栏
func update_hand_cards(cards: Array[Card]):
	# 清空现有手牌显示
	for child in hand_card_area.get_children():
		child.queue_free()
	
	# 设置手牌区域的对齐方式为居中
	hand_card_area.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 创建卡牌UI
	for card in cards:
		var card_ui = _create_card_ui(card)
		hand_card_area.add_child(card_ui)

# 创建卡牌UI（使用全局缩放）
func _create_card_ui(card: Card) -> Control:
	var card_ui = CardUI.new()
	card_ui.set_card(card)
	# 基础尺寸，会自动缩放
	card_ui.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(120, 180))
	UIScaleManager.apply_scale_to_panel(card_ui)
	
	# 连接拖动信号
	card_ui.card_drag_started.connect(_on_card_drag_started)
	card_ui.card_drag_ended.connect(_on_card_drag_ended)
	
	# 连接右键拖拽信号（弃牌行动）
	card_ui.card_right_drag_started.connect(_on_card_right_drag_started)
	card_ui.card_right_drag_ended.connect(_on_card_right_drag_ended)
	
	# 卡牌名称（使用全局缩放字体）
	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.position = UIScaleManager.scale_vec2(Vector2(10, 10))
	UIScaleManager.apply_scale_to_label(name_label, 16)
	card_ui.add_child(name_label)
	
	# 属性标识（右上角小圆圈，使用全局缩放）
	var attr_container = HBoxContainer.new()
	attr_container.position = UIScaleManager.scale_vec2(Vector2(90, 10))
	for attr in card.attributes:
		var attr_circle = ColorRect.new()
		attr_circle.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(15, 15))
		attr_circle.color = _get_attribute_color(attr)
		attr_container.add_child(attr_circle)
	card_ui.add_child(attr_container)
	
	# 能量消耗（使用全局缩放字体和位置）
	var cost_label = Label.new()
	cost_label.text = str(card.energy_cost)
	cost_label.position = UIScaleManager.scale_vec2(Vector2(10, 150))
	UIScaleManager.apply_scale_to_label(cost_label, 18)
	card_ui.add_child(cost_label)
	
	return card_ui

# 获取属性颜色
func _get_attribute_color(attr: String) -> Color:
	match attr:
		"fire":
			return Color.RED
		"wind":
			return Color.CYAN
		"water":
			return Color.BLUE
		"rock":
			return Color.GRAY
		_:
			return Color.WHITE

# 更新能量显示
func update_energy(_player_id: int, energy: int):
	if energy_label:
		energy_label.text = "能量: " + str(energy) + "/5"

# 更新赏金状态
func update_bounty_status(has_bounty: bool, holder_pos: Vector2i):
	if bounty_label:
		if has_bounty:
			bounty_label.text = "赏金持有中 - 位置: " + str(holder_pos)
		else:
			bounty_label.text = "赏金未持有"

# 更新回合倒计时
func update_turn_timer(time_remaining: float):
	if turn_timer_label:
		turn_timer_label.text = "剩余时间: " + str(int(time_remaining)) + "秒"

# 信号处理
func _on_round_started(_round: int):
	pass

func _on_phase_changed(new_phase: GameManager.GamePhase):
	match new_phase:
		GameManager.GamePhase.DEPLOYMENT:
			# 显示部署界面
			_show_deploy_ui()
			# 部署阶段也显示手牌（用于选择精灵时参考）
			_connect_hand_signals()
			_refresh_hand_cards()
		GameManager.GamePhase.PLAYING:
			# 隐藏部署界面，显示游戏界面
			_hide_deploy_ui()
			# 确保手牌信号已连接（手牌管理器在start_game时创建）
			_connect_hand_signals()
			# 进入游戏阶段时显示手牌
			_refresh_hand_cards()
		GameManager.GamePhase.ENDED:
			# 显示结算界面
			_hide_deploy_ui()

# 刷新手牌显示
func _refresh_hand_cards():
	if not game_manager:
		return
	
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		update_hand_cards(hand_manager.hand_cards)

func _show_deploy_ui():
	if deploy_ui:
		return  # 已经显示
	
	deploy_ui = DeployUI.new()
	deploy_ui.game_manager = game_manager
	deploy_ui.sprite_deploy = game_manager.sprite_deploy
	deploy_ui.game_map = game_manager.game_map
	# 传递地形渲染器引用（从game_manager获取）
	if game_manager.terrain_renderer:
		deploy_ui.terrain_renderer = game_manager.terrain_renderer
	deploy_ui.deployment_complete.connect(_on_deployment_complete)
	deploy_ui.deployment_cancelled.connect(_on_deployment_cancelled)
	add_child(deploy_ui)
	
	# 设置地图点击处理器
	_setup_map_click_handler()

func _hide_deploy_ui():
	if deploy_ui:
		deploy_ui.queue_free()
		deploy_ui = null
	
	if map_click_handler:
		map_click_handler.queue_free()
		map_click_handler = null

func _setup_map_click_handler():
	if not game_manager or not game_manager.game_map:
		return
	
	# 获取SubViewport和Camera3D
	var sub_viewport = map_viewport.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return
	
	map_click_handler = MapClickHandler.new(game_manager.game_map, camera, sub_viewport)
	map_click_handler.hex_clicked.connect(_on_hex_clicked)
	add_child(map_click_handler)

func _on_hex_clicked(hex_coord: Vector2i):
	# 如果处于弃牌行动阶段，处理基本行动目标选择
	if discard_action_state.active:
		_handle_discard_action_target_selection(hex_coord)
		return
	
	# 如果处于卡牌使用阶段，处理卡牌目标选择
	if card_use_state.active:
		_handle_card_target_selection(hex_coord)
		return
	
	# 否则处理部署UI
	if deploy_ui:
		deploy_ui.handle_map_click(hex_coord)

func _on_deployment_complete(selected_ids: Array[String], positions: Array[Vector2i]):
	if game_manager:
		game_manager.deploy_human_player(selected_ids, positions)
		# 部署完成后，部署AI玩家并开始游戏
		game_manager.deploy_ai_players()
		game_manager.start_playing_phase()

func _on_deployment_cancelled():
	print("部署已取消")

func _on_all_actions_submitted():
	pass

# 手牌更新处理
func _on_hand_updated(player_id: int, _hand_size: int):
	# 只更新人类玩家的手牌显示
	if player_id == GameManager.HUMAN_PLAYER_ID:
		var hand_manager = game_manager.hand_managers.get(player_id)
		if hand_manager:
			update_hand_cards(hand_manager.hand_cards)

# 卡牌拖动开始
func _on_card_drag_started(card_ui: CardUI, card: Card):
	# 如果正在右键拖拽，先清除右键箭头
	if right_dragging_card:
		_clear_arrow_indicator()
		right_dragging_card = null
	
	dragging_card_ui = card_ui
	dragging_card = card
	print("开始拖动卡牌: ", card.card_name)
	# 创建箭头指示器
	_create_arrow_indicator()
	if arrow_line:
		arrow_line.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 橙色表示正常使用
	# 开始处理拖动更新
	set_process(true)

# 右键拖拽开始（弃牌行动）
func _on_card_right_drag_started(card_ui: CardUI, card: Card):
	# 检查是否在游戏阶段
	if not game_manager or game_manager.current_phase != GameManager.GamePhase.PLAYING:
		print("只能在游戏阶段使用弃牌行动")
		return
	
	# 如果正在左键拖拽，先清除左键箭头
	if dragging_card_ui:
		_clear_arrow_indicator()
		dragging_card_ui = null
		dragging_card = null
	
	right_dragging_card = card
	right_dragging_card_ui = card_ui
	print("开始右键拖拽弃牌: ", card.card_name)
	# 创建箭头指示器（使用不同颜色表示弃牌）
	_create_arrow_indicator()
	if arrow_line:
		arrow_line.default_color = Color(0.8, 0.2, 0.2, 0.8)  # 红色表示弃牌
	set_process(true)

# 卡牌拖动结束
func _on_card_drag_ended(_card_ui: CardUI, card: Card, drop_position: Vector2):
	# 清除箭头
	_clear_arrow_indicator()
	
	# 如果已经在卡牌使用阶段，不清除高亮（保持高亮状态），也不处理拖动结束
	if card_use_state.active:
		dragging_card_ui = null
		dragging_card = null
		set_process(false)
		print("已在卡牌使用阶段，忽略拖动结束")
		return
	
	# 清除拖动时的高亮
	_clear_card_target_highlight()
	
	dragging_card_ui = null
	dragging_card = null
	set_process(false)
	
	print("结束拖动卡牌: ", card.card_name, " 位置: ", drop_position)
	
	# 检查是否拖动到有效的地图位置
	if not game_manager or not game_manager.game_map:
		return
	
	var target_hex = _get_hex_at_screen_position(drop_position)
	if target_hex == Vector2i(-1, -1):
		print("未拖动到有效的地图位置")
		return
	
	# 查找该位置的精灵
	var target_sprite = null
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == target_hex:
			target_sprite = sprite
			break
	
	if target_sprite:
		# 拖动到精灵上，检查是否可以使用
		_try_use_card_on_sprite(card, target_sprite)
	else:
		print("该位置没有精灵")

# 右键拖拽结束（弃牌行动）
func _on_card_right_drag_ended(_card_ui: CardUI, card: Card, drop_position: Vector2):
	# 清除箭头和高亮
	_clear_arrow_indicator()
	_clear_right_drag_highlight()
	
	if not right_dragging_card or right_dragging_card != card:
		right_dragging_card = null
		right_dragging_card_ui = null
		set_process(false)
		return
	
	right_dragging_card = null
	right_dragging_card_ui = null
	set_process(false)
	
	print("结束右键拖拽弃牌: ", card.card_name, " 位置: ", drop_position)
	
	# 检查是否在游戏阶段
	if not game_manager or game_manager.current_phase != GameManager.GamePhase.PLAYING:
		print("只能在游戏阶段使用弃牌行动")
		return
	
	# 检查是否拖动到有效的地图位置
	if not game_manager.game_map:
		return
	
	var target_hex = _get_hex_at_screen_position(drop_position)
	if target_hex == Vector2i(-1, -1):
		print("未拖动到有效的地图位置")
		return
	
	# 查找该位置的精灵
	var target_sprite = null
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == target_hex:
			target_sprite = sprite
			break
	
	if not target_sprite:
		print("该位置没有精灵，无法执行弃牌行动")
		return
	
	# 判断拖到的精灵是己方还是敌方
	if target_sprite.owner_player_id == GameManager.HUMAN_PLAYER_ID:
		# 拖到己方精灵 → 该精灵就是执行者，直接弹出移动/攻击选择
		_enter_discard_action_selection_phase(card, target_sprite, target_sprite)
	else:
		# 拖到敌方精灵 → 需要先选择己方精灵作为执行者
		_enter_discard_action_selection_phase(card, null, target_sprite)

# 获取指定屏幕位置的精灵
func _get_sprite_at_position(screen_pos: Vector2) -> Sprite:
	if not game_manager:
		return null
	
	# 检查是否在地图视口内
	var map_container = map_viewport
	if not map_container:
		return null
	
	var container_rect = map_container.get_global_rect()
	if not container_rect.has_point(screen_pos):
		return null
	
	# 将屏幕坐标转换为地图坐标
	# 这里需要类似map_click_handler的逻辑
	var sub_viewport = map_container.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return null
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return null
	
	# 计算视口坐标
	var local_pos = screen_pos - container_rect.position
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	var viewport_pos: Vector2
	if map_container.stretch:
		var scale = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale
		var scaled_height = viewport_size.y * scale
		var offset_x = (container_size.x - scaled_width) / 2.0
		var offset_y = (container_size.y - scaled_height) / 2.0
		viewport_pos.x = (local_pos.x - offset_x) / scale
		viewport_pos.y = (local_pos.y - offset_y) / scale
	else:
		var offset_x = (container_size.x - viewport_size.x) / 2.0
		var offset_y = (container_size.y - viewport_size.y) / 2.0
		viewport_pos.x = local_pos.x - offset_x
		viewport_pos.y = local_pos.y - offset_y
	
	viewport_pos.x = clamp(viewport_pos.x, 0, viewport_size.x)
	viewport_pos.y = clamp(viewport_pos.y, 0, viewport_size.y)
	
	# 计算射线与地面的交点
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	var denom = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		return null
	
	var t = (plane_point - from).dot(plane_normal) / denom
	if t < 0:
		return null
	
	var world_pos = from + ray_dir * t
	var hex_coord = HexGrid.world_to_hex(world_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
	
	# 查找该位置的精灵
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			return sprite
	
	return null

# 尝试在精灵上使用卡牌
func _try_use_card_on_sprite(card: Card, target_sprite: Sprite):
	if not game_manager:
		return
	
	# 检查是否是己方精灵
	if target_sprite.owner_player_id != GameManager.HUMAN_PLAYER_ID:
		print("不能对敌方精灵使用卡牌")
		return
	
	# 检查卡牌是否可以使用（不需要能量，能量只用于租用精灵）
	var card_interface = game_manager.card_interface
	var all_friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	
	var check_result = card_interface.can_use_card_on_sprite(card, target_sprite, all_friendly_sprites, game_manager.game_map)
	
	if check_result.can_use:
		print("可以使用卡牌 ", card.card_name, " 在精灵 ", target_sprite.sprite_name)
		# 进入卡牌使用阶段，高亮可用的目标
		_enter_card_use_phase(card, target_sprite)
	else:
		print("不能使用卡牌: ", check_result.reason)

# 进入卡牌使用阶段
func _enter_card_use_phase(card: Card, source_sprite: Sprite):
	if not game_manager:
		return
	
	# 设置卡牌使用状态
	card_use_state.active = true
	card_use_state.card = card
	card_use_state.source_sprite = source_sprite
	card_use_state.target_type = card.card_type
	
	# 显示取消按钮
	if cancel_card_button:
		cancel_card_button.visible = true
	
	# 清除之前的高亮
	_clear_card_use_highlights()
	
	var card_interface = game_manager.card_interface
	
	match card.card_type:
		"attack":
			# 攻击卡牌：高亮可攻击的精灵（即使没有目标也进入阶段）
			var targets = card_interface.get_attackable_targets(card, source_sprite, game_manager.all_sprites, game_manager.game_map)
			if targets.size() > 0:
				_highlight_attack_targets(targets)
			else:
				print("没有可攻击的目标，但进入卡牌使用阶段")
			card_use_state.highlighted_sprites = targets
		
		"terrain":
			# 地形卡牌：高亮可放置地形的六边形（即使没有位置也进入阶段）
			var positions = card_interface.get_terrain_placement_positions(card, source_sprite, game_manager.game_map)
			if positions.size() > 0:
				_highlight_terrain_positions(positions)
			else:
				print("没有可放置地形的位置，但进入卡牌使用阶段")
			card_use_state.highlighted_hexes = positions
		
		"support":
			# 辅助卡牌：高亮自己这个精灵
			_highlight_support_target(source_sprite)
			card_use_state.highlighted_sprites = [source_sprite]
	
	print("进入卡牌使用阶段: ", card.card_name, " 类型: ", card.card_type)

# 清除卡牌使用高亮
func _clear_card_use_highlights():
	# 清除精灵高亮（通过sprite_renderer，如果有的话）
	# 清除六边形高亮
	if game_manager and game_manager.terrain_renderer:
		game_manager.terrain_renderer.clear_selected_highlights()
	
	card_use_state.highlighted_sprites.clear()
	card_use_state.highlighted_hexes.clear()

# 高亮攻击目标精灵
func _highlight_attack_targets(targets: Array[Sprite]):
	if not game_manager:
		return
	
	print("开始高亮攻击目标，目标数量: ", targets.size())
	
	# 使用terrain_renderer高亮精灵位置
	if game_manager.terrain_renderer:
		for target in targets:
			# 高亮精灵所在位置（使用红色高亮）
			game_manager.terrain_renderer.highlight_selected_position(target.hex_position)
			print("高亮目标精灵: ", target.sprite_name, " 位置: ", target.hex_position)
	else:
		print("警告: terrain_renderer 不存在，无法高亮")
	
	print("完成高亮，共高亮了 ", targets.size(), " 个可攻击目标")

# 高亮地形放置位置
func _highlight_terrain_positions(positions: Array[Vector2i]):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	# 高亮所有可放置地形的六边形
	for pos in positions:
		game_manager.terrain_renderer.highlight_selected_position(pos)
	
	print("高亮了 ", positions.size(), " 个可放置地形的位置")

# 高亮辅助目标（自己）
func _highlight_support_target(sprite: Sprite):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	# 高亮自己这个精灵的位置
	game_manager.terrain_renderer.highlight_selected_position(sprite.hex_position)
	
	print("高亮了辅助目标: ", sprite.sprite_name)

# 处理卡牌目标选择（在卡牌使用阶段点击地图时）
func _handle_card_target_selection(hex_coord: Vector2i):
	if not card_use_state.active or not game_manager:
		return
	
	var card = card_use_state.card
	var source_sprite = card_use_state.source_sprite
	
	if not card or not source_sprite:
		return
	
	match card_use_state.target_type:
		"attack":
			# 攻击卡牌：检查点击的是否是高亮的精灵
			for target in card_use_state.highlighted_sprites:
				if target.hex_position == hex_coord:
					# 确认使用卡牌
					_confirm_card_use(card, source_sprite, target)
					return
			print("未点击有效的攻击目标")
		
		"terrain":
			# 地形卡牌：检查点击的是否是高亮的六边形
			if hex_coord in card_use_state.highlighted_hexes:
				# 确认使用卡牌
				_confirm_card_use(card, source_sprite, hex_coord)
				return
			print("未点击有效的地形放置位置")
		
		"support":
			# 辅助卡牌：检查点击的是否是自己
			if source_sprite.hex_position == hex_coord:
				# 确认使用卡牌
				_confirm_card_use(card, source_sprite, source_sprite)
				return
			print("未点击自己的精灵")

# 确认使用卡牌
func _confirm_card_use(card: Card, source_sprite: Sprite, target: Variant):
	if not game_manager:
		return
	
	print("确认使用卡牌: ", card.card_name, " 目标: ", target)
	
	# 应用卡牌效果
	var card_interface = game_manager.card_interface
	var result = card_interface.apply_card_effect(
		card,
		source_sprite,
		target,
		game_manager.game_map,
		game_manager.terrain_manager
	)
	
	if result.success:
		print("卡牌使用成功: ", result.message)
		# 从手牌中移除卡牌
		var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
		if hand_manager:
			hand_manager.remove_card(card, "used")
		# 退出卡牌使用阶段
		_exit_card_use_phase()
	else:
		print("卡牌使用失败")
		# 使用失败也退出阶段
		_exit_card_use_phase()

# 退出卡牌使用阶段
func _exit_card_use_phase():
	# 清除高亮
	_clear_card_use_highlights()
	
	# 隐藏取消按钮
	if cancel_card_button:
		cancel_card_button.visible = false
	
	# 重置状态
	card_use_state.active = false
	card_use_state.card = null
	card_use_state.source_sprite = null
	card_use_state.target_type = ""
	
	print("退出卡牌使用阶段")

# 取消卡牌使用（返还卡牌）
func _on_cancel_card_use():
	# 如果处于弃牌行动阶段，取消弃牌
	if discard_action_state.active:
		print("取消弃牌: ", discard_action_state.card.card_name if discard_action_state.card else "未知")
		_exit_discard_action_phase()
		return
	
	# 如果处于卡牌使用阶段，取消使用
	if card_use_state.active:
		print("取消使用卡牌: ", card_use_state.card.card_name if card_use_state.card else "未知")
		# 退出卡牌使用阶段（不消耗卡牌，卡牌保留在手牌中）
		_exit_card_use_phase()

# 创建箭头指示器
func _create_arrow_indicator():
	if not card_arrow_container:
		return
	
	# 如果箭头已存在，先清除
	if arrow_line:
		_clear_arrow_indicator()
	
	# 创建箭头线条
	arrow_line = Line2D.new()
	arrow_line.width = 3.0
	# 颜色会在调用处设置（左键橙色，右键红色）
	arrow_line.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 默认橙色
	arrow_line.antialiased = true
	card_arrow_container.add_child(arrow_line)

# 清除箭头指示器
func _clear_arrow_indicator():
	if arrow_line:
		arrow_line.queue_free()
		arrow_line = null

# 当前高亮的六边形坐标
var highlighted_hex_coord: Vector2i = Vector2i(-1, -1)

# 右键拖拽时的高亮状态
var right_drag_highlight_state: Dictionary = {
	"last_hex": Vector2i(-1, -1),
	"highlighted_sprites": [],
	"highlighted_hexes": []
}

# 清除卡牌目标高亮
func _clear_card_target_highlight():
	if highlighted_hex_coord != Vector2i(-1, -1) and game_manager and game_manager.terrain_renderer:
		# 清除之前的高亮
		game_manager.terrain_renderer.clear_selected_highlights()
		highlighted_hex_coord = Vector2i(-1, -1)

# 高亮卡牌目标六边形
func _highlight_card_target_hex(hex_coord: Vector2i):
	if highlighted_hex_coord == hex_coord:
		return  # 已经高亮了
	
	# 清除之前的高亮
	_clear_card_target_highlight()
	
	# 高亮新的六边形
	if game_manager and game_manager.terrain_renderer:
		# 使用terrain_renderer的highlight_selected_position方法（红色高亮）
		game_manager.terrain_renderer.highlight_selected_position(hex_coord)
		highlighted_hex_coord = hex_coord

# 处理拖动更新（在_process中调用）
func _process(_delta):
	if dragging_card_ui and dragging_card:
		_update_card_drag()
	elif right_dragging_card_ui and right_dragging_card:
		_update_card_drag()  # 右键拖拽也更新箭头

# 更新卡牌拖动状态
func _update_card_drag():
	if not arrow_line:
		return
	
	# 获取起始位置（卡牌中心）
	var start_pos: Vector2
	if dragging_card_ui:
		var card_global = dragging_card_ui.get_global_rect()
		start_pos = card_global.get_center()
	elif right_dragging_card_ui:
		var card_global = right_dragging_card_ui.get_global_rect()
		start_pos = card_global.get_center()
	else:
		return  # 没有有效的拖拽状态
	
	# 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 更新箭头线条
	arrow_line.clear_points()
	arrow_line.add_point(start_pos)
	arrow_line.add_point(mouse_pos)
	
	# 左键拖拽：高亮目标
	if dragging_card_ui and dragging_card:
		# 检测鼠标下的六边形
		var hex_coord = _get_hex_at_screen_position(mouse_pos)
		if hex_coord != Vector2i(-1, -1):
			# 高亮该六边形
			_highlight_card_target_hex(hex_coord)
	
	# 右键拖拽：根据鼠标下的精灵类型显示不同反馈
	elif right_dragging_card_ui and right_dragging_card:
		_update_right_drag_feedback(mouse_pos)

# 获取屏幕位置对应的六边形坐标
func _get_hex_at_screen_position(screen_pos: Vector2) -> Vector2i:
	if not game_manager or not game_manager.game_map:
		return Vector2i(-1, -1)
	
	# 检查是否在地图视口内
	var map_container = map_viewport
	if not map_container:
		return Vector2i(-1, -1)
	
	var container_rect = map_container.get_global_rect()
	if not container_rect.has_point(screen_pos):
		return Vector2i(-1, -1)
	
	# 将屏幕坐标转换为地图坐标（复用_get_sprite_at_position的逻辑）
	var sub_viewport = map_container.get_node_or_null("SubViewport") as SubViewport
	if not sub_viewport:
		return Vector2i(-1, -1)
	
	var camera = sub_viewport.get_node_or_null("World/Camera3D") as Camera3D
	if not camera:
		return Vector2i(-1, -1)
	
	# 计算视口坐标
	var local_pos = screen_pos - container_rect.position
	var viewport_size = Vector2(sub_viewport.size)
	var container_size = container_rect.size
	
	var viewport_pos: Vector2
	if map_container.stretch:
		var scale_factor = min(container_size.x / viewport_size.x, container_size.y / viewport_size.y)
		var scaled_width = viewport_size.x * scale_factor
		var scaled_height = viewport_size.y * scale_factor
		var offset_x = (container_size.x - scaled_width) / 2.0
		var offset_y = (container_size.y - scaled_height) / 2.0
		viewport_pos.x = (local_pos.x - offset_x) / scale_factor
		viewport_pos.y = (local_pos.y - offset_y) / scale_factor
	else:
		var offset_x = (container_size.x - viewport_size.x) / 2.0
		var offset_y = (container_size.y - viewport_size.y) / 2.0
		viewport_pos.x = local_pos.x - offset_x
		viewport_pos.y = local_pos.y - offset_y
	
	viewport_pos.x = clamp(viewport_pos.x, 0, viewport_size.x)
	viewport_pos.y = clamp(viewport_pos.y, 0, viewport_size.y)
	
	# 计算射线与地面的交点
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	var denom = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		return Vector2i(-1, -1)
	
	var t = (plane_point - from).dot(plane_normal) / denom
	if t < 0:
		return Vector2i(-1, -1)
	
	var world_pos = from + ray_dir * t
	var hex_coord = HexGrid.world_to_hex(world_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
	
	# 检查坐标是否有效
	if game_manager.game_map._is_valid_hex(hex_coord):
		return hex_coord
	
	return Vector2i(-1, -1)

# 更新右键拖拽反馈（实时显示移动或攻击提示）
func _update_right_drag_feedback(mouse_pos: Vector2):
	if not game_manager or not game_manager.game_map:
		return
	
	var hex_coord = _get_hex_at_screen_position(mouse_pos)
	if hex_coord == Vector2i(-1, -1):
		# 清除高亮
		_clear_right_drag_highlight()
		return
	
	# 如果还是同一个位置，不需要更新
	if hex_coord == right_drag_highlight_state.last_hex:
		return
	
	right_drag_highlight_state.last_hex = hex_coord
	
	# 查找该位置的精灵
	var target_sprite = null
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			target_sprite = sprite
			break
	
	if not target_sprite:
		# 没有精灵，清除高亮
		_clear_right_drag_highlight()
		return
	
	# 清除之前的高亮
	_clear_right_drag_highlight()
	
	if not game_manager.terrain_renderer:
		return
	
	# 拖到任意精灵上，都只高亮该精灵（不自动判断移动或攻击）
	# 箭头保持红色，表示弃牌行动
	if arrow_line:
		arrow_line.default_color = Color(0.8, 0.2, 0.2, 0.8)  # 红色表示弃牌
	
	# 高亮拖拽到的精灵位置
	game_manager.terrain_renderer.highlight_selected_position(hex_coord)


# 清除右键拖拽高亮
func _clear_right_drag_highlight():
	if game_manager and game_manager.terrain_renderer:
		game_manager.terrain_renderer.clear_selected_highlights()
	
	right_drag_highlight_state.highlighted_sprites.clear()
	right_drag_highlight_state.highlighted_hexes.clear()
	right_drag_highlight_state.last_hex = Vector2i(-1, -1)

# ========== 弃牌行动相关函数 ==========

# 进入弃牌行动选择阶段（拖到精灵后选择移动或攻击）
# source_sprite: 执行行动的精灵（如果为null，需要先选择）
# target_sprite: 拖拽到的精灵（可能是执行者，也可能是攻击目标）
func _enter_discard_action_selection_phase(card: Card, source_sprite: Sprite, target_sprite: Sprite):
	if not game_manager:
		return
	
	# 设置弃牌行动状态
	discard_action_state.active = true
	discard_action_state.card = card
	discard_action_state.action_type = ""  # 还未选择
	discard_action_state.source_sprite = source_sprite  # 如果拖到己方精灵，直接设为执行者
	discard_action_state.target_sprite = target_sprite  # 保存拖拽到的精灵
	
	# 显示取消按钮
	if cancel_card_button:
		cancel_card_button.visible = true
		cancel_card_button.text = "取消弃牌"
	
	# 如果还没有执行者（拖到敌方精灵），先选择己方精灵
	if not source_sprite:
		print("进入弃牌行动选择阶段: ", card.card_name, " 拖到敌方精灵: ", target_sprite.sprite_name, " 请先选择己方精灵")
		_highlight_friendly_sprites()
	else:
		# 如果已有执行者（拖到己方精灵），直接显示移动/攻击选择按钮
		print("进入弃牌行动选择阶段: ", card.card_name, " 执行者: ", source_sprite.sprite_name)
		_show_basic_action_buttons()

# 进入弃牌行动阶段
func _enter_discard_action_phase(card: Card):
	if not game_manager:
		return
	
	# 检查是否在游戏阶段
	if game_manager.current_phase != GameManager.GamePhase.PLAYING:
		print("只能在游戏阶段使用弃牌行动")
		return
	
	# 设置弃牌行动状态
	discard_action_state.active = true
	discard_action_state.card = card
	discard_action_state.action_type = ""
	discard_action_state.source_sprite = null
	
	# 显示基本行动选择按钮
	_show_basic_action_buttons()
	
	# 显示取消按钮
	if cancel_card_button:
		cancel_card_button.visible = true
		cancel_card_button.text = "取消弃牌"
	
	print("进入弃牌行动阶段: ", card.card_name)

# 显示基本行动选择按钮
func _show_basic_action_buttons():
	# 清除之前的按钮
	_hide_basic_action_buttons()
	
	# 创建攻击按钮
	var attack_button = Button.new()
	attack_button.text = "攻击"
	attack_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	attack_button.position = Vector2(-150, -100)
	attack_button.size = Vector2(120, 50)
	UIScaleManager.apply_scale_to_button(attack_button, 18)
	attack_button.pressed.connect(_on_select_basic_attack)
	add_child(attack_button)
	basic_action_buttons["attack"] = attack_button
	
	# 创建移动按钮
	var move_button = Button.new()
	move_button.text = "移动"
	move_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	move_button.position = Vector2(30, -100)
	move_button.size = Vector2(120, 50)
	UIScaleManager.apply_scale_to_button(move_button, 18)
	move_button.pressed.connect(_on_select_basic_move)
	add_child(move_button)
	basic_action_buttons["move"] = move_button

# 隐藏基本行动选择按钮
func _hide_basic_action_buttons():
	for button in basic_action_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	basic_action_buttons.clear()

# 选择基本攻击行动
func _on_select_basic_attack():
	if not discard_action_state.active or not game_manager:
		return
	
	discard_action_state.action_type = "attack"
	
	# 隐藏行动选择按钮
	_hide_basic_action_buttons()
	
	var source_sprite = discard_action_state.source_sprite
	if not source_sprite:
		# 如果还没有执行者，先选择己方精灵
		print("请选择一个己方精灵，然后选择攻击目标")
		_highlight_friendly_sprites()
		return
	
	# 如果已有执行者，直接高亮该精灵攻击范围内的敌人
	print("高亮 ", source_sprite.sprite_name, " 的攻击目标")
	_highlight_attack_targets_for_discard_action(source_sprite)

# 选择基本移动行动
func _on_select_basic_move():
	if not discard_action_state.active or not game_manager:
		return
	
	discard_action_state.action_type = "move"
	
	# 隐藏行动选择按钮
	_hide_basic_action_buttons()
	
	var source_sprite = discard_action_state.source_sprite
	if not source_sprite:
		# 如果还没有执行者，先选择己方精灵
		print("请选择一个己方精灵进行移动")
		_highlight_friendly_sprites()
		return
	
	# 如果已有执行者，直接高亮该精灵的可移动位置
	print("高亮 ", source_sprite.sprite_name, " 的可移动位置")
	_highlight_move_targets_for_discard_action(source_sprite)

# 高亮所有己方精灵（用于选择攻击者或移动者）
func _highlight_friendly_sprites():
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	_clear_discard_action_highlights()
	
	var friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	for sprite in friendly_sprites:
		if sprite.is_alive:
			game_manager.terrain_renderer.highlight_selected_position(sprite.hex_position)
			discard_action_state.highlighted_sprites.append(sprite)
	
	print("高亮了 ", friendly_sprites.size(), " 个己方精灵（用于选择攻击者/移动者）")

# 高亮可攻击指定目标的己方精灵（用于选择攻击者）
func _highlight_attackable_friendly_sprites(target_sprite: Sprite):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	_clear_discard_action_highlights()
	
	# 获取目标精灵的玩家ID（确保只选择能攻击该目标的己方精灵）
	var target_player_id = target_sprite.owner_player_id
	
	var friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	for sprite in friendly_sprites:
		# 确保是己方精灵且能攻击目标
		if sprite.is_alive and sprite.owner_player_id == GameManager.HUMAN_PLAYER_ID:
			# 检查是否在攻击范围内（不同阵营才能攻击）
			if target_player_id != GameManager.HUMAN_PLAYER_ID and sprite.is_in_attack_range(target_sprite.hex_position):
				game_manager.terrain_renderer.highlight_selected_position(sprite.hex_position)
				discard_action_state.highlighted_sprites.append(sprite)
	
	print("高亮了 ", discard_action_state.highlighted_sprites.size(), " 个可攻击 ", target_sprite.sprite_name, " 的己方精灵（攻击者选择）")

# 处理弃牌行动目标选择
func _handle_discard_action_target_selection(hex_coord: Vector2i):
	if not discard_action_state.active or not game_manager:
		return
	
	var action_type = discard_action_state.action_type
	var source_sprite = discard_action_state.source_sprite
	
	# 如果还没有选择行动类型，说明还在选择执行者阶段
	if action_type == "":
		# 选择己方精灵作为执行者
		_select_source_sprite_for_discard_action(hex_coord)
		return
	
	if action_type == "attack":
		# 攻击行动
		if not source_sprite:
			# 还未选择己方精灵，选择精灵
			_select_source_sprite_for_discard_attack(hex_coord)
		else:
			# 已经选择了精灵，选择攻击目标
			_select_attack_target_for_discard_action(hex_coord)
	elif action_type == "move":
		# 移动行动
		if not source_sprite:
			# 还未选择己方精灵，选择精灵
			_select_source_sprite_for_discard_move(hex_coord)
		else:
			# 已经选择了精灵，选择移动目标
			_select_move_target_for_discard_action(hex_coord)

# 为弃牌行动选择己方精灵作为执行者（当拖到敌方精灵时）
func _select_source_sprite_for_discard_action(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵
	var friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	var selected_sprite = null
	
	for sprite in friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			selected_sprite = sprite
			break
	
	if not selected_sprite:
		print("该位置没有己方精灵")
		return
	
	# 设置执行者
	discard_action_state.source_sprite = selected_sprite
	print("选择了执行者: ", selected_sprite.sprite_name)
	
	# 显示移动/攻击选择按钮
	_show_basic_action_buttons()

# 为弃牌攻击选择己方精灵
func _select_source_sprite_for_discard_attack(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵
	var friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	var selected_sprite = null
	
	for sprite in friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			selected_sprite = sprite
			break
	
	if not selected_sprite:
		print("该位置没有己方精灵")
		return
	
	var target_sprite = discard_action_state.target_sprite
	if not target_sprite:
		print("错误：没有攻击目标")
		return
	
	# 选择己方精灵后，高亮该精灵攻击范围内的所有敌人
	discard_action_state.source_sprite = selected_sprite
	print("选择了攻击精灵: ", selected_sprite.sprite_name, " 请选择攻击目标")
	# 高亮可攻击的目标（所有在攻击范围内的敌人）
	_highlight_attack_targets_for_discard_action(selected_sprite)

# 为弃牌移动选择己方精灵
func _select_source_sprite_for_discard_move(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵
	var friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	var selected_sprite = null
	
	for sprite in friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			selected_sprite = sprite
			break
	
	if not selected_sprite:
		print("该位置没有己方精灵")
		return
	
	discard_action_state.source_sprite = selected_sprite
	print("选择了移动精灵: ", selected_sprite.sprite_name)
	
	# 高亮可移动位置
	_highlight_move_targets_for_discard_action(selected_sprite)

# 高亮攻击目标（弃牌行动）- 高亮攻击范围内的所有敌人
func _highlight_attack_targets_for_discard_action(source_sprite: Sprite):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	_clear_discard_action_highlights()
	
	# 获取攻击者所属玩家ID（确保只攻击敌方）
	var attacker_player_id = source_sprite.owner_player_id
	
	# 获取攻击范围内的所有敌方精灵
	var attack_range = source_sprite.attack_range
	var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, attack_range)
	
	print("攻击者: ", source_sprite.sprite_name, " 玩家ID: ", attacker_player_id, " 攻击范围: ", attack_range)
	
	for sprite in game_manager.all_sprites:
		# 确保只高亮敌方精灵：不同阵营且存活
		if not sprite.is_alive:
			continue
		
		# 严格检查阵营：必须是不同玩家
		if sprite.owner_player_id == attacker_player_id:
			continue  # 跳过同阵营精灵
		
		# 检查是否在攻击范围内
		if sprite.hex_position in range_hexes:
			# 检查高度限制
			var attacker_terrain = game_manager.game_map.get_terrain(source_sprite.hex_position)
			var target_terrain = game_manager.game_map.get_terrain(sprite.hex_position)
			var attacker_level = attacker_terrain.height_level if attacker_terrain else 1
			var target_level = target_terrain.height_level if target_terrain else 1
			
			if game_manager.terrain_manager.can_attack_height(attacker_level, target_level, source_sprite.attack_height_limit):
				game_manager.terrain_renderer.highlight_selected_position(sprite.hex_position)
				discard_action_state.highlighted_sprites.append(sprite)
				print("  高亮敌人: ", sprite.sprite_name, " 玩家ID: ", sprite.owner_player_id, " 位置: ", sprite.hex_position)
	
	print("高亮了 ", discard_action_state.highlighted_sprites.size(), " 个可攻击的敌人（攻击者: ", source_sprite.sprite_name, " 玩家ID: ", attacker_player_id, ")")

# 高亮移动目标（弃牌行动）
func _highlight_move_targets_for_discard_action(source_sprite: Sprite):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	_clear_discard_action_highlights()
	
	# 获取移动范围内的所有可移动位置
	var movement = source_sprite.remaining_movement
	var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, movement)
	
	for hex_pos in range_hexes:
		if game_manager.terrain_manager.can_move_to(source_sprite, hex_pos):
			game_manager.terrain_renderer.highlight_selected_position(hex_pos)
			discard_action_state.highlighted_hexes.append(hex_pos)
	
	print("高亮了 ", discard_action_state.highlighted_hexes.size(), " 个可移动位置")

# 选择攻击目标（弃牌行动）
func _select_attack_target_for_discard_action(hex_coord: Vector2i):
	if not discard_action_state.source_sprite:
		return
	
	# 查找该位置的敌方精灵
	var target_sprite = null
	for sprite in discard_action_state.highlighted_sprites:
		if sprite.hex_position == hex_coord:
			target_sprite = sprite
			break
	
	if not target_sprite:
		print("未选择有效的攻击目标")
		return
	
	# 提交弃牌攻击行动
	_submit_discard_attack_action(target_sprite)

# 选择移动目标（弃牌行动）
func _select_move_target_for_discard_action(hex_coord: Vector2i):
	if not discard_action_state.source_sprite:
		return
	
	# 检查是否是可移动的位置
	if hex_coord not in discard_action_state.highlighted_hexes:
		print("无法移动到该位置")
		return
	
	# 提交弃牌移动行动
	_submit_discard_move_action(hex_coord)

# 提交弃牌攻击行动
func _submit_discard_attack_action(target_sprite: Sprite):
	if not game_manager or not discard_action_state.card or not discard_action_state.source_sprite:
		return
	
	# 从手牌中移除卡牌
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		hand_manager.remove_card(discard_action_state.card, "discarded")
	
	# 添加基本攻击行动
	var action = ActionResolver.Action.new(
		GameManager.HUMAN_PLAYER_ID,
		ActionResolver.ActionType.ATTACK,
		discard_action_state.source_sprite,
		target_sprite,
		null,  # 基本行动不使用卡牌
		{"is_basic_action": true}  # 标记为基本行动
	)
	game_manager.action_resolver.add_action(
		action.player_id,
		action.action_type,
		action.sprite,
		action.target,
		action.card,
		action.data
	)
	
	print("提交弃牌攻击行动: ", discard_action_state.source_sprite.sprite_name, " -> ", target_sprite.sprite_name)
	
	# 退出弃牌行动阶段
	_exit_discard_action_phase()

# 提交弃牌移动行动
func _submit_discard_move_action(target_pos: Vector2i):
	if not game_manager or not discard_action_state.card or not discard_action_state.source_sprite:
		return
	
	# 从手牌中移除卡牌
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		hand_manager.remove_card(discard_action_state.card, "discarded")
	
	# 添加基本移动行动
	var action = ActionResolver.Action.new(
		GameManager.HUMAN_PLAYER_ID,
		ActionResolver.ActionType.MOVE,
		discard_action_state.source_sprite,
		target_pos,
		null,  # 基本行动不使用卡牌
		{"is_basic_action": true}  # 标记为基本行动
	)
	game_manager.action_resolver.add_action(
		action.player_id,
		action.action_type,
		action.sprite,
		action.target,
		action.card,
		action.data
	)
	
	print("提交弃牌移动行动: ", discard_action_state.source_sprite.sprite_name, " -> ", target_pos)
	
	# 退出弃牌行动阶段
	_exit_discard_action_phase()

# 退出弃牌行动阶段
func _exit_discard_action_phase():
	# 清除高亮
	_clear_discard_action_highlights()
	
	# 隐藏按钮
	_hide_basic_action_buttons()
	if cancel_card_button:
		cancel_card_button.visible = false
		cancel_card_button.text = "取消使用"
	
	# 重置状态
	discard_action_state.active = false
	discard_action_state.card = null
	discard_action_state.action_type = ""
	discard_action_state.source_sprite = null
	discard_action_state.target_sprite = null
	
	print("退出弃牌行动阶段")

# 清除弃牌行动高亮
func _clear_discard_action_highlights():
	if game_manager and game_manager.terrain_renderer:
		game_manager.terrain_renderer.clear_selected_highlights()
	
	discard_action_state.highlighted_sprites.clear()
	discard_action_state.highlighted_hexes.clear()
