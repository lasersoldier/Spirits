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

# 取消使用按钮
var cancel_card_button: Button = null

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
	dragging_card_ui = card_ui
	dragging_card = card
	print("开始拖动卡牌: ", card.card_name)
	# 创建箭头指示器
	_create_arrow_indicator()
	# 开始处理拖动更新
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
	if not card_use_state.active:
		return
	
	print("取消使用卡牌: ", card_use_state.card.card_name if card_use_state.card else "未知")
	# 退出卡牌使用阶段（不消耗卡牌，卡牌保留在手牌中）
	_exit_card_use_phase()

# 创建箭头指示器
func _create_arrow_indicator():
	if not dragging_card_ui or not card_arrow_container:
		return
	
	# 创建箭头线条
	arrow_line = Line2D.new()
	arrow_line.width = 3.0
	arrow_line.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 橙色
	arrow_line.antialiased = true
	card_arrow_container.add_child(arrow_line)

# 清除箭头指示器
func _clear_arrow_indicator():
	if arrow_line:
		arrow_line.queue_free()
		arrow_line = null

# 当前高亮的六边形坐标
var highlighted_hex_coord: Vector2i = Vector2i(-1, -1)

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

# 更新卡牌拖动状态
func _update_card_drag():
	if not dragging_card_ui or not arrow_line:
		return
	
	# 获取卡牌中心位置
	var card_global = dragging_card_ui.get_global_rect()
	var card_center = card_global.get_center()
	
	# 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 更新箭头线条
	arrow_line.clear_points()
	arrow_line.add_point(card_center)
	arrow_line.add_point(mouse_pos)
	
	# 检测鼠标下的六边形
	var hex_coord = _get_hex_at_screen_position(mouse_pos)
	if hex_coord != Vector2i(-1, -1):
		# 高亮该六边形
		_highlight_card_target_hex(hex_coord)

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
