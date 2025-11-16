class_name MainUI
extends Control

# UI节点引用
@onready var map_viewport: SubViewportContainer
@onready var sprite_status_panel: Panel
@onready var hand_card_ui: HandCardUI
@onready var energy_label: Label
@onready var bounty_label: Label
@onready var turn_timer_label: Label

# 游戏管理器引用
var game_manager: GameManager

# 部署UI
var deploy_ui: DeployUI = null

# 地图点击处理器
var map_click_handler: MapClickHandler = null

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

# 精灵资料卡
var sprite_info_card: SpriteInfoCard = null

# 重叠精灵选择系统
var last_clicked_position: Vector2i = Vector2i(-1, -1)
var last_clicked_sprites: Array[Sprite] = []
var last_selected_sprite_index: int = 0

# 动作预览UI
var action_preview_panel: Panel = null
var action_preview_list: VBoxContainer = null
var action_preview_items: Array[Control] = []

# 回合结束按钮
var end_turn_button: Button = null

# 提示信息标签
var message_label: Label = null
var message_timer: Timer = null

# 精灵切换选择面板
var sprite_selection_panel: Panel = null
var sprite_selection_buttons: Array[Button] = []
var sprite_selection_vbox: VBoxContainer = null
var current_overlapping_hex: Vector2i = Vector2i(-1, -1)
var current_overlapping_sprites: Array[Sprite] = []
var pending_card: Card = null  # 等待选择精灵的卡牌
var pending_card_is_right_drag: bool = false  # 是否是右键拖拽

func _ready():
	# 初始化UI节点
	map_viewport = get_node_or_null("MapViewport") as SubViewportContainer
	sprite_status_panel = get_node_or_null("SpriteStatusPanel") as Panel
	hand_card_ui = get_node_or_null("HandCardArea") as HandCardUI
	energy_label = get_node_or_null("EnergyLabel") as Label
	bounty_label = get_node_or_null("BountyLabel") as Label
	turn_timer_label = get_node_or_null("TurnTimerLabel") as Label
	
	# 连接手牌UI的信号
	if hand_card_ui:
		hand_card_ui.card_drag_started.connect(_on_card_drag_started)
		hand_card_ui.card_drag_ended.connect(_on_card_drag_ended)
		hand_card_ui.card_right_drag_started.connect(_on_card_right_drag_started)
		hand_card_ui.card_right_drag_ended.connect(_on_card_right_drag_ended)
	
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
	
	# 创建精灵资料卡
	sprite_info_card = SpriteInfoCard.new()
	sprite_info_card.visible = false
	sprite_info_card.game_manager = null  # 稍后在set_game_manager中设置
	add_child(sprite_info_card)
	print("精灵资料卡已创建并添加到UI")
	
	# 创建回合结束按钮
	_create_end_turn_button()
	
	# 创建提示信息标签
	_create_message_label()
	
	# 创建精灵切换选择面板
	_create_sprite_selection_panel()
	
	# 设置处理输入
	set_process_input(true)

# 处理输入（取消卡牌使用、显示精灵资料卡）
func _input(event: InputEvent):
	# 处理鼠标中键点击（显示精灵资料卡）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_handle_middle_click()
		# 不返回，让资料卡也能处理点击外部关闭
		return
	
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
	# 传递游戏管理器引用给资料卡
	if sprite_info_card:
		sprite_info_card.game_manager = gm
	# 传递游戏管理器引用给手牌UI
	if hand_card_ui:
		hand_card_ui.set_game_manager(gm)
	
	# 连接战争迷雾系统
	if game_manager and game_manager.fog_of_war_manager:
		if game_manager.terrain_renderer:
			game_manager.terrain_renderer.set_fog_manager(game_manager.fog_of_war_manager, GameManager.HUMAN_PLAYER_ID)
			print("MainUI: 战争迷雾系统已连接到地形渲染器")
		if game_manager.sprite_renderer:
			game_manager.sprite_renderer.set_fog_manager(game_manager.fog_of_war_manager, GameManager.HUMAN_PLAYER_ID)
			print("MainUI: 战争迷雾系统已连接到精灵渲染器")
	
	_connect_signals()

func _connect_signals():
	if not game_manager:
		return
	
	game_manager.round_started.connect(_on_round_started)
	game_manager.phase_changed.connect(_on_phase_changed)
	game_manager.all_actions_submitted.connect(_on_all_actions_submitted)
	game_manager.action_added.connect(_on_action_added)

# 更新精灵状态面板
func update_sprite_status(_sprites: Array[Sprite]):
	# 更新显示所有精灵的血量、存活状态等
	pass

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
	# 清除预览
	_clear_action_preview()
	# 启用回合结束按钮（新回合开始）
	if end_turn_button:
		# 使用 call_deferred 确保在下一帧启用按钮
		call_deferred("_enable_end_turn_button", _round)

func _on_phase_changed(new_phase: GameManager.GamePhase):
	match new_phase:
		GameManager.GamePhase.DEPLOYMENT:
			# 显示部署界面
			_show_deploy_ui()
			# 部署阶段也显示手牌（用于选择精灵时参考）
			if hand_card_ui:
				# 确保信号已连接（手牌管理器在_deal_starting_hands时创建）
				hand_card_ui._connect_hand_signals()
				hand_card_ui.refresh_hand_cards()
			# 确保地图点击处理器已设置（用于部署）
			_setup_map_click_handler()
			# 隐藏回合结束按钮
			if end_turn_button:
				end_turn_button.visible = false
		GameManager.GamePhase.PLAYING:
			# 隐藏部署界面，显示游戏界面
			_hide_deploy_ui()
			# 进入游戏阶段时显示手牌
			if hand_card_ui:
				# 确保信号已连接（手牌管理器在_deal_starting_hands时创建）
				hand_card_ui._connect_hand_signals()
				hand_card_ui.refresh_hand_cards()
			# 确保地图点击处理器已设置（用于游戏操作，如移动、攻击等）
			_setup_map_click_handler()
			# 显示回合结束按钮
			if end_turn_button:
				end_turn_button.visible = true
				end_turn_button.disabled = false
		GameManager.GamePhase.ENDED:
			# 显示结算界面
			_hide_deploy_ui()
			# 游戏结束时可以保留地图点击处理器（或者销毁，根据需要）
			# 隐藏回合结束按钮
			if end_turn_button:
				end_turn_button.visible = false

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
	
	# 注意：地图点击处理器在阶段变化时设置，不在这里设置
	# 这样可以确保在部署阶段和游戏阶段都存在

func _hide_deploy_ui():
	if deploy_ui:
		deploy_ui.queue_free()
		deploy_ui = null
	
	# 注意：不要在这里销毁地图点击处理器
	# 因为游戏阶段也需要使用地图点击处理器
	# 地图点击处理器会在阶段变化时重新设置（如果需要）

func _setup_map_click_handler():
	# 如果已经存在，不需要重复创建
	if map_click_handler:
		return
	
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
	print("地图点击处理器已设置")

func _on_hex_clicked(hex_coord: Vector2i):
	print("=== 地图点击事件 ===")
	print("点击六边形: ", hex_coord)
	print("弃牌状态 active: ", discard_action_state.active)
	print("弃牌状态 action_type: ", discard_action_state.action_type)
	print("弃牌状态 source_sprite: ", discard_action_state.source_sprite.sprite_name if discard_action_state.source_sprite else "无")
	print("卡牌使用状态 active: ", card_use_state.active)
	
	# 如果处于弃牌行动阶段，处理基本行动目标选择
	if discard_action_state.active:
		print("处理弃牌行动目标选择")
		_handle_discard_action_target_selection(hex_coord)
		return
	
	# 如果处于卡牌使用阶段，处理卡牌目标选择
	if card_use_state.active:
		print("处理卡牌目标选择")
		_handle_card_target_selection(hex_coord)
		return
	
	# 否则处理部署UI
	if deploy_ui:
		print("处理部署UI")
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
	# 清除预览
	_clear_action_preview()
	# 注意：不在这里启用按钮，应该在 _on_round_started() 中启用
	# 因为此时结算可能还没完成，新回合还没开始

func _on_action_added(_action: ActionResolver.Action):
	# 当行动添加到队列时，更新预览
	_update_action_preview()

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
	
	# 查找该位置的所有精灵
	var sprites_at_position: Array[Sprite] = []
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == target_hex:
			sprites_at_position.append(sprite)
	
	if sprites_at_position.is_empty():
		print("该位置没有精灵")
		return
	
	# 如果只有一个精灵，直接使用
	if sprites_at_position.size() == 1:
		_try_use_card_on_sprite(card, sprites_at_position[0])
	else:
		# 多个精灵，显示选择面板
		_show_sprite_selection_panel(target_hex, sprites_at_position, card, false)

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
	
	# 如果已经在弃牌行动阶段且已经选择了行动类型，忽略新的拖拽（防止重置状态）
	if discard_action_state.active and discard_action_state.action_type != "":
		print("已在弃牌行动阶段且已选择行动类型，忽略新的拖拽操作")
		return
	
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
	
	# 查找该位置的所有精灵
	var sprites_at_position: Array[Sprite] = []
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == target_hex:
			sprites_at_position.append(sprite)
	
	if sprites_at_position.is_empty():
		print("该位置没有精灵，无法执行弃牌行动")
		return
	
	# 如果只有一个精灵，直接使用
	if sprites_at_position.size() == 1:
		_apply_right_drag_to_sprite(card, sprites_at_position[0])
	else:
		# 多个精灵，显示选择面板
		_show_sprite_selection_panel(target_hex, sprites_at_position, card, true)

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
	
	# 生成射线
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	var plane_normal = Vector3(0, 1, 0)
	var denom = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		return null
	
	# 首先尝试检测射线与地形顶部平面的交点（优先检测精灵所在的地形高度）
	var best_hex_coord: Vector2i = Vector2i(-1, -1)
	var best_t: float = INF
	
	# 检测所有地形高度平面（1级到3级）
	for level in range(1, 4):  # 1, 2, 3
		var terrain_height = _get_terrain_height_for_level(level)
		var plane_point = Vector3(0, terrain_height, 0)
		var t = (plane_point - from).dot(plane_normal) / denom
		
		if t >= 0 and t < best_t:  # 射线与这个高度的平面相交，且比之前的更近
			var intersection_pos = from + ray_dir * t
			# 将交点投影到地面（Y=0）来计算六边形坐标
			var ground_pos = Vector3(intersection_pos.x, 0, intersection_pos.z)
			var hex_coord = HexGrid.world_to_hex(ground_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
			
			# 检查该坐标是否有地形，且地形高度是否匹配
			if game_manager.game_map.is_valid_hex_with_terrain(hex_coord):
				var terrain = game_manager.game_map.get_terrain(hex_coord)
				if terrain and terrain.height_level == level:
					# 找到匹配的地形，记录这个结果（选择最近的）
					best_t = t
					best_hex_coord = hex_coord
	
	# 如果没有找到匹配的地形顶部，回退到地面检测
	if best_hex_coord == Vector2i(-1, -1):
		var ground_plane_point = Vector3(0, 0, 0)
		var ground_t = (ground_plane_point - from).dot(plane_normal) / denom
		
		if ground_t >= 0:
			var ground_pos = from + ray_dir * ground_t
			best_hex_coord = HexGrid.world_to_hex(ground_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
	
	if best_hex_coord == Vector2i(-1, -1):
		return null
	
	# 使用统一的循环切换逻辑
	return _get_sprite_at_hex(best_hex_coord)

# 根据六边形坐标获取精灵（使用循环切换逻辑，用于拖动等场景）
func _get_sprite_at_hex(hex_coord: Vector2i, increment_selection: bool = true) -> Sprite:
	if hex_coord == Vector2i(-1, -1):
		return null
	
	# 查找该位置的所有精灵
	var sprites_at_position: Array[Sprite] = []
	for sprite in game_manager.all_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			sprites_at_position.append(sprite)
	
	if sprites_at_position.is_empty():
		# 没有精灵，重置状态
		last_clicked_position = Vector2i(-1, -1)
		last_clicked_sprites.clear()
		last_selected_sprite_index = 0
		return null
	
	# 如果点击的是新位置，重置索引并优先选择己方精灵
	if hex_coord != last_clicked_position:
		last_clicked_position = hex_coord
		last_clicked_sprites = sprites_at_position
		last_selected_sprite_index = 0
		
		# 优先返回己方精灵
		for i in range(sprites_at_position.size()):
			if sprites_at_position[i].owner_player_id == GameManager.HUMAN_PLAYER_ID:
				last_selected_sprite_index = i
				break
	elif increment_selection:
		# 同一位置，循环切换到下一个精灵
		last_selected_sprite_index = (last_selected_sprite_index + 1) % sprites_at_position.size()
	
	# 如果只有一个精灵，直接返回
	if sprites_at_position.size() == 1:
		return sprites_at_position[0]
	
	# 多个精灵，返回当前索引的精灵
	var selected_sprite = sprites_at_position[last_selected_sprite_index]
	if sprites_at_position.size() > 1 and increment_selection:
		print("该位置有 ", sprites_at_position.size(), " 个精灵，当前选择: ", selected_sprite.sprite_name, " (玩家", selected_sprite.owner_player_id, ") [", last_selected_sprite_index + 1, "/", sprites_at_position.size(), "]")
	return selected_sprite

# 处理鼠标中键点击（显示精灵资料卡）
func _handle_middle_click():
	if not game_manager:
		return
	
	# 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 查找该位置的精灵（使用循环切换逻辑）
	var sprite = _get_sprite_at_position(mouse_pos)
	
	if sprite:
		# 显示精灵资料卡
		if sprite_info_card:
			sprite_info_card.show_sprite_info(sprite)
			sprite_info_card.tracked_sprite = sprite  # 设置跟踪的精灵
			print("显示精灵资料卡: ", sprite.sprite_name)
	else:
		# 如果没有精灵，隐藏资料卡
		if sprite_info_card and sprite_info_card.visible:
			sprite_info_card.hide_info()
			print("隐藏精灵资料卡")

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
	
	# 确定行动类型
	var action_type: ActionResolver.ActionType
	match card.card_type:
		"attack":
			action_type = ActionResolver.ActionType.ATTACK
		"terrain":
			action_type = ActionResolver.ActionType.TERRAIN
		"support":
			action_type = ActionResolver.ActionType.EFFECT
		_:
			print("未知的卡牌类型: ", card.card_type)
			_exit_card_use_phase()
			return
	
	# 创建行动并添加到队列（不立即执行）
	var action = ActionResolver.Action.new(
		GameManager.HUMAN_PLAYER_ID,
		action_type,
		source_sprite,
		target,
		card,
		{}
	)
	
	# 添加到行动队列
	var result = game_manager.add_human_action(action)
	
	# 检查行动是否成功添加（如果被限制，行动不会被添加）
	if not result.success:
		_show_message(result.message)
		# 不消耗卡牌，直接退出
		_exit_card_use_phase()
		return
	
	# 从手牌中移除卡牌（已添加到队列，可以移除）
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		hand_manager.remove_card(card, "used")
	
	# 显示预览
	_update_action_preview()
	
	# 退出卡牌使用阶段
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
	
	# 生成射线
	var from = camera.project_ray_origin(viewport_pos)
	var ray_dir = camera.project_ray_normal(viewport_pos)
	var plane_normal = Vector3(0, 1, 0)
	var denom = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		return Vector2i(-1, -1)
	
	# 首先尝试检测射线与地形顶部平面的交点
	# 遍历所有可能的地形高度（1级到3级），找到距离摄像机最近的匹配地形
	var best_hex_coord: Vector2i = Vector2i(-1, -1)
	var best_t: float = INF
	
	# 检测所有地形高度平面
	for level in range(1, 4):  # 1, 2, 3
		var terrain_height = _get_terrain_height_for_level(level)
		var plane_point = Vector3(0, terrain_height, 0)
		var t = (plane_point - from).dot(plane_normal) / denom
		
		if t >= 0 and t < best_t:  # 射线与这个高度的平面相交，且比之前的更近
			var intersection_pos = from + ray_dir * t
			# 将交点投影到地面（Y=0）来计算六边形坐标
			var ground_pos = Vector3(intersection_pos.x, 0, intersection_pos.z)
			var hex_coord = HexGrid.world_to_hex(ground_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
			
			# 检查该坐标是否有地形，且地形高度是否匹配
			if game_manager.game_map._is_valid_hex(hex_coord):
				var terrain = game_manager.game_map.get_terrain(hex_coord)
				if terrain and terrain.height_level == level:
					# 找到匹配的地形，记录这个结果（选择最近的）
					best_t = t
					best_hex_coord = hex_coord
	
	# 如果找到了匹配的地形顶部，使用它
	if best_hex_coord != Vector2i(-1, -1):
		return best_hex_coord
	
	# 如果没有找到匹配的地形顶部，回退到地面检测
	var ground_plane_point = Vector3(0, 0, 0)
	var ground_t = (ground_plane_point - from).dot(plane_normal) / denom
	
	if ground_t < 0:
		return Vector2i(-1, -1)
	
	var ground_pos = from + ray_dir * ground_t
	var hex_coord = HexGrid.world_to_hex(ground_pos, game_manager.game_map.hex_size, game_manager.game_map.map_height)
	
	if game_manager.game_map._is_valid_hex(hex_coord):
		return hex_coord
	
	return Vector2i(-1, -1)

# 获取地形高度（与TerrainRenderer和MapClickHandler保持一致）
func _get_terrain_height_for_level(level: int) -> float:
	match level:
		1:
			return 3.0  # 1级地形高度
		2:
			return 6.0  # 2级地形高度
		3:
			return 12.0  # 3级地形高度
		_:
			return 3.0

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
	print("进入弃牌行动选择阶段: ", card.card_name if card else "未知")
	print("之前的 active 状态: ", discard_action_state.active)
	print("之前的 action_type: ", discard_action_state.action_type)
	
	if not game_manager:
		return
	
	# 如果已经在弃牌行动阶段且已经选择了行动类型，不要重置
	if discard_action_state.active and discard_action_state.action_type != "":
		print("警告：已在弃牌行动阶段且已选择行动类型，保持当前状态")
		# 只更新卡牌，保持 action_type 和执行者
		discard_action_state.card = card
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
	attack_button.mouse_filter = Control.MOUSE_FILTER_STOP  # 只拦截按钮区域内的点击
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
	move_button.mouse_filter = Control.MOUSE_FILTER_STOP  # 只拦截按钮区域内的点击
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
	print("点击移动按钮")
	print("当前弃牌状态 active: ", discard_action_state.active)
	print("当前 action_type: ", discard_action_state.action_type)
	
	if not discard_action_state.active or not game_manager:
		print("错误：弃牌状态未激活或游戏管理器不存在")
		return
	
	discard_action_state.action_type = "move"
	print("设置 action_type = move，当前 active: ", discard_action_state.active)
	
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
	print("高亮前 active: ", discard_action_state.active)
	_highlight_move_targets_for_discard_action(source_sprite)
	print("高亮后 active: ", discard_action_state.active)

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
	print("处理弃牌行动目标选择: ", hex_coord)
	print("弃牌状态 - active: ", discard_action_state.active, " action_type: ", discard_action_state.action_type, " source_sprite: ", discard_action_state.source_sprite.sprite_name if discard_action_state.source_sprite else "无")
	
	if not discard_action_state.active or not game_manager:
		print("弃牌状态未激活或游戏管理器不存在")
		return
	
	var action_type = discard_action_state.action_type
	var source_sprite = discard_action_state.source_sprite
	
	# 如果还没有选择行动类型，说明还在选择执行者阶段
	if action_type == "":
		# 选择己方精灵作为执行者
		print("选择执行者阶段")
		_select_source_sprite_for_discard_action(hex_coord)
		return
	
	if action_type == "attack":
		# 攻击行动
		print("攻击行动类型")
		if not source_sprite:
			# 还未选择己方精灵，选择精灵
			_select_source_sprite_for_discard_attack(hex_coord)
		else:
			# 已经选择了精灵，选择攻击目标
			_select_attack_target_for_discard_action(hex_coord)
	elif action_type == "move":
		# 移动行动
		print("移动行动类型，source_sprite: ", source_sprite.sprite_name if source_sprite else "无")
		if not source_sprite:
			# 还未选择己方精灵，选择精灵
			print("选择移动精灵")
			_select_source_sprite_for_discard_move(hex_coord)
		else:
			# 已经选择了精灵，选择移动目标
			print("选择移动目标位置")
			_select_move_target_for_discard_action(hex_coord)
	else:
		print("未知行动类型: ", action_type)

# 为弃牌行动选择己方精灵作为执行者（当拖到敌方精灵时）
func _select_source_sprite_for_discard_action(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵（使用循环切换逻辑，但只考虑己方精灵）
	var friendly_sprites_at_position: Array[Sprite] = []
	var all_friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	
	for sprite in all_friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			friendly_sprites_at_position.append(sprite)
	
	if friendly_sprites_at_position.is_empty():
		print("该位置没有己方精灵")
		return
	
	# 如果点击的是新位置，重置索引
	if hex_coord != last_clicked_position:
		last_clicked_position = hex_coord
		last_clicked_sprites = friendly_sprites_at_position
		last_selected_sprite_index = 0
	else:
		# 同一位置，循环切换到下一个己方精灵
		last_selected_sprite_index = (last_selected_sprite_index + 1) % friendly_sprites_at_position.size()
	
	var selected_sprite = friendly_sprites_at_position[last_selected_sprite_index]
	if friendly_sprites_at_position.size() > 1:
		print("该位置有 ", friendly_sprites_at_position.size(), " 个己方精灵，当前选择: ", selected_sprite.sprite_name, " [", last_selected_sprite_index + 1, "/", friendly_sprites_at_position.size(), "]")
	
	# 设置执行者
	discard_action_state.source_sprite = selected_sprite
	print("选择了执行者: ", selected_sprite.sprite_name)
	
	# 显示移动/攻击选择按钮
	_show_basic_action_buttons()

# 为弃牌攻击选择己方精灵
func _select_source_sprite_for_discard_attack(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵（使用循环切换逻辑，但只考虑己方精灵）
	var friendly_sprites_at_position: Array[Sprite] = []
	var all_friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	
	for sprite in all_friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			friendly_sprites_at_position.append(sprite)
	
	if friendly_sprites_at_position.is_empty():
		print("该位置没有己方精灵")
		return
	
	var target_sprite = discard_action_state.target_sprite
	if not target_sprite:
		print("错误：没有攻击目标")
		return
	
	# 如果点击的是新位置，重置索引
	if hex_coord != last_clicked_position:
		last_clicked_position = hex_coord
		last_clicked_sprites = friendly_sprites_at_position
		last_selected_sprite_index = 0
	else:
		# 同一位置，循环切换到下一个己方精灵
		last_selected_sprite_index = (last_selected_sprite_index + 1) % friendly_sprites_at_position.size()
	
	var selected_sprite = friendly_sprites_at_position[last_selected_sprite_index]
	if friendly_sprites_at_position.size() > 1:
		print("该位置有 ", friendly_sprites_at_position.size(), " 个己方精灵，当前选择: ", selected_sprite.sprite_name, " [", last_selected_sprite_index + 1, "/", friendly_sprites_at_position.size(), "]")
	
	# 选择己方精灵后，高亮该精灵攻击范围内的所有敌人
	discard_action_state.source_sprite = selected_sprite
	print("选择了攻击精灵: ", selected_sprite.sprite_name, " 请选择攻击目标")
	# 高亮可攻击的目标（所有在攻击范围内的敌人）
	_highlight_attack_targets_for_discard_action(selected_sprite)

# 为弃牌移动选择己方精灵
func _select_source_sprite_for_discard_move(hex_coord: Vector2i):
	if not game_manager:
		return
	
	# 查找该位置的己方精灵（使用循环切换逻辑，但只考虑己方精灵）
	var friendly_sprites_at_position: Array[Sprite] = []
	var all_friendly_sprites = game_manager.sprite_deploy.get_player_sprites(GameManager.HUMAN_PLAYER_ID)
	
	for sprite in all_friendly_sprites:
		if sprite.is_alive and sprite.hex_position == hex_coord:
			friendly_sprites_at_position.append(sprite)
	
	if friendly_sprites_at_position.is_empty():
		print("该位置没有己方精灵")
		return
	
	# 如果点击的是新位置，重置索引
	if hex_coord != last_clicked_position:
		last_clicked_position = hex_coord
		last_clicked_sprites = friendly_sprites_at_position
		last_selected_sprite_index = 0
	else:
		# 同一位置，循环切换到下一个己方精灵
		last_selected_sprite_index = (last_selected_sprite_index + 1) % friendly_sprites_at_position.size()
	
	var selected_sprite = friendly_sprites_at_position[last_selected_sprite_index]
	if friendly_sprites_at_position.size() > 1:
		print("该位置有 ", friendly_sprites_at_position.size(), " 个己方精灵，当前选择: ", selected_sprite.sprite_name, " [", last_selected_sprite_index + 1, "/", friendly_sprites_at_position.size(), "]")
	
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
	print("开始高亮移动目标")
	print("当前 active: ", discard_action_state.active)
	
	if not game_manager or not game_manager.terrain_renderer:
		print("错误：游戏管理器或地形渲染器不存在")
		return
	
	_clear_discard_action_highlights()
	
	# 获取移动范围内的所有可移动位置
	# 基本行动（弃牌行动）不消耗移动力，使用基础移动力范围
	var movement = source_sprite.base_movement  # 使用基础移动力，而不是剩余移动力
	print("精灵移动力: ", source_sprite.remaining_movement, "/", source_sprite.base_movement, " 当前位置: ", source_sprite.hex_position)
	print("基本行动（弃牌）使用基础移动力范围: ", movement, "（不消耗移动力）")
	
	var range_hexes = HexGrid.get_hexes_in_range(source_sprite.hex_position, movement)
	print("移动范围内共有 ", range_hexes.size(), " 个六边形")
	
	var valid_positions = 0
	for hex_pos in range_hexes:
		# 跳过当前位置（原地停留不算移动）
		if hex_pos == source_sprite.hex_position:
			continue
		
		# 计算移动距离
		var distance = HexGrid.hex_distance(source_sprite.hex_position, hex_pos)
		
		# 检查移动力是否足够（考虑地形效果）
		if game_manager.terrain_manager.can_move_to(source_sprite, hex_pos):
			# 这里只做基本检查，实际移动时会再次检查移动力
			game_manager.terrain_renderer.highlight_selected_position(hex_pos)
			discard_action_state.highlighted_hexes.append(hex_pos)
			valid_positions += 1
			if valid_positions <= 5:  # 只打印前5个
				print("  高亮可移动位置: ", hex_pos, " 距离: ", distance)
	
	print("高亮了 ", discard_action_state.highlighted_hexes.size(), " 个可移动位置（基础移动力: ", movement, "，当前移动力: ", source_sprite.remaining_movement, "/", source_sprite.base_movement, "）")
	print("提示：基本行动（弃牌）不消耗移动力，可以在同一回合内多次移动")
	print("高亮完成后 active: ", discard_action_state.active)

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
	print("选择移动目标: ", hex_coord)
	print("当前执行者: ", discard_action_state.source_sprite.sprite_name if discard_action_state.source_sprite else "无")
	print("高亮位置数量: ", discard_action_state.highlighted_hexes.size())
	
	if not discard_action_state.source_sprite:
		print("错误：没有执行者")
		return
	
	var source_sprite = discard_action_state.source_sprite
	
	# 基本行动（弃牌行动）不消耗移动力，所以不需要检查剩余移动力
	# 但是移动距离不能超过基础移动力范围
	
	# 检查是否是可移动的位置（使用循环比较以确保类型匹配）
	var is_valid_target = false
	for highlighted_hex in discard_action_state.highlighted_hexes:
		if highlighted_hex == hex_coord:
			is_valid_target = true
			break
	
	# 如果点击的是当前位置，不允许原地停留（基本行动不消耗移动力，但原地停留没有意义）
	if hex_coord == source_sprite.hex_position:
		print("警告：点击了当前位置，原地停留没有意义")
		return
	
	if not is_valid_target:
		print("无法移动到该位置: ", hex_coord, " 不在可移动位置列表中")
		print("剩余移动力: ", source_sprite.remaining_movement, "/", source_sprite.base_movement)
		# 打印前几个高亮位置用于调试
		if discard_action_state.highlighted_hexes.size() > 0:
			print("可移动位置示例: ", discard_action_state.highlighted_hexes[0])
		return
	
	# 提交弃牌移动行动
	print("提交移动到: ", hex_coord, "（剩余移动力: ", source_sprite.remaining_movement, "/", source_sprite.base_movement, "）")
	_submit_discard_move_action(hex_coord)

# 提交弃牌攻击行动
func _submit_discard_attack_action(target_sprite: Sprite):
	if not game_manager or not discard_action_state.card or not discard_action_state.source_sprite:
		return
	
	# 创建基本攻击行动并添加到队列（不立即执行）
	var source_sprite = discard_action_state.source_sprite
	var action = ActionResolver.Action.new(
		GameManager.HUMAN_PLAYER_ID,
		ActionResolver.ActionType.ATTACK,
		source_sprite,
		target_sprite,
		null,  # 基本行动不使用卡牌
		{"is_basic_action": true}  # 标记为基本行动
	)
	
	# 先检查行动是否成功添加（在移除卡牌之前）
	var result = game_manager.add_human_action(action)
	
	# 检查行动是否成功添加
	if not result.success:
		_show_message(result.message)
		# 行动失败，不消耗卡牌，直接退出
		_exit_discard_action_phase()
		return
	
	# 行动成功，从手牌中移除卡牌
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		print("弃牌行动：从手牌中移除卡牌 ", discard_action_state.card.card_name, " 移除前手牌数量: ", hand_manager.hand_cards.size())
		hand_manager.remove_card(discard_action_state.card, "discarded")
		print("弃牌行动：移除后手牌数量: ", hand_manager.hand_cards.size())
	else:
		print("错误：无法获取手牌管理器")
	
	# 显示预览
	_update_action_preview()
	
	print("基本攻击行动已添加到队列: ", source_sprite.sprite_name, " -> ", target_sprite.sprite_name)
	
	# 退出弃牌行动阶段
	_exit_discard_action_phase()

# 创建提示信息标签
func _create_message_label():
	message_label = Label.new()
	message_label.text = ""
	message_label.visible = false
	# 手动设置锚点实现顶部居中
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 0.0
	message_label.anchor_bottom = 0.0
	message_label.offset_left = -200  # 宽度的一半，实现居中
	message_label.offset_right = 200  # 宽度的一半
	message_label.offset_top = 20
	message_label.offset_bottom = 80
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(message_label, 20)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 4)
	add_child(message_label)
	
	# 创建定时器
	message_timer = Timer.new()
	message_timer.wait_time = 3.0
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timer_timeout)
	add_child(message_timer)

# 创建精灵切换选择面板
func _create_sprite_selection_panel():
	sprite_selection_panel = Panel.new()
	sprite_selection_panel.visible = false
	sprite_selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	sprite_selection_panel.custom_minimum_size = Vector2(300, 200)
	
	# 创建标题标签
	var title_label = Label.new()
	title_label.text = "选择目标精灵"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(title_label, 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 创建垂直布局容器
	sprite_selection_vbox = VBoxContainer.new()
	sprite_selection_vbox.add_child(title_label)
	
	# 创建取消按钮
	var cancel_button = Button.new()
	cancel_button.text = "取消"
	UIScaleManager.apply_scale_to_button(cancel_button, 16)
	cancel_button.pressed.connect(_hide_sprite_selection_panel)
	sprite_selection_vbox.add_child(cancel_button)
	
	sprite_selection_panel.add_child(sprite_selection_vbox)
	add_child(sprite_selection_panel)

# 显示精灵切换选择面板
func _show_sprite_selection_panel(hex_coord: Vector2i, sprites: Array[Sprite], card: Card, is_right_drag: bool = false):
	if not sprite_selection_panel or sprites.size() <= 1:
		return
	
	current_overlapping_hex = hex_coord
	current_overlapping_sprites = sprites
	pending_card = card
	pending_card_is_right_drag = is_right_drag
	
	# 清除旧按钮
	for button in sprite_selection_buttons:
		if is_instance_valid(button):
			button.queue_free()
	sprite_selection_buttons.clear()
	
	# 移除旧按钮（保留标题和取消按钮）
	for i in range(sprite_selection_vbox.get_child_count() - 1, 0, -1):
		var child = sprite_selection_vbox.get_child(i)
		if child is Button and child.text != "取消":
			sprite_selection_vbox.remove_child(child)
			child.queue_free()
	
	# 创建选择按钮
	for sprite in sprites:
		var button = Button.new()
		var button_text = sprite.sprite_name
		if sprite.owner_player_id != GameManager.HUMAN_PLAYER_ID:
			button_text += " (敌方玩家" + str(sprite.owner_player_id) + ")"
		else:
			button_text += " (己方)"
		button.text = button_text
		UIScaleManager.apply_scale_to_button(button, 16)
		button.pressed.connect(_on_sprite_selection_button_pressed.bind(sprite))
		sprite_selection_vbox.add_child(button)
		sprite_selection_buttons.append(button)
	
	# 显示面板
	sprite_selection_panel.visible = true
	print("显示精灵选择面板，共 ", sprites.size(), " 个精灵")

# 隐藏精灵切换选择面板
func _hide_sprite_selection_panel():
	if sprite_selection_panel:
		sprite_selection_panel.visible = false
	current_overlapping_hex = Vector2i(-1, -1)
	current_overlapping_sprites.clear()
	pending_card = null
	pending_card_is_right_drag = false

# 处理精灵选择按钮点击
func _on_sprite_selection_button_pressed(sprite: Sprite):
	if not pending_card:
		_hide_sprite_selection_panel()
		return
	
	var card = pending_card
	var is_right_drag = pending_card_is_right_drag
	
	_hide_sprite_selection_panel()
	
	# 根据拖拽类型应用卡牌效果
	if is_right_drag:
		# 右键拖拽（弃牌行动）
		_apply_right_drag_to_sprite(card, sprite)
	else:
		# 左键拖拽（正常使用卡牌）
		_try_use_card_on_sprite(card, sprite)

# 应用右键拖拽到精灵（弃牌行动）
func _apply_right_drag_to_sprite(card: Card, target_sprite: Sprite):
	if not game_manager:
		return
	
	# 判断拖到的精灵是己方还是敌方
	if target_sprite.owner_player_id == GameManager.HUMAN_PLAYER_ID:
		# 拖到己方精灵 → 该精灵就是执行者，直接弹出移动/攻击选择
		_enter_discard_action_selection_phase(card, target_sprite, target_sprite)
	else:
		# 拖到敌方精灵 → 需要先选择己方精灵作为执行者
		_enter_discard_action_selection_phase(card, null, target_sprite)

# 显示提示信息
func _show_message(text: String):
	if not message_label:
		print(text)  # 如果没有标签，就打印到控制台
		return
	
	message_label.text = text
	message_label.visible = true
	
	# 重新启动定时器
	if message_timer:
		message_timer.stop()
		message_timer.start()

# 隐藏提示信息
func _on_message_timer_timeout():
	if message_label:
		message_label.visible = false
		message_label.text = ""

# 提交弃牌移动行动
func _submit_discard_move_action(target_pos: Vector2i):
	if not game_manager or not discard_action_state.card or not discard_action_state.source_sprite:
		return
	
	# 创建基本移动行动并添加到队列（不立即执行）
	var source_sprite = discard_action_state.source_sprite
	var action = ActionResolver.Action.new(
		GameManager.HUMAN_PLAYER_ID,
		ActionResolver.ActionType.MOVE,
		source_sprite,
		target_pos,
		null,  # 基本行动不使用卡牌
		{"is_basic_action": true}  # 标记为基本行动
	)
	
	# 先检查行动是否成功添加（在移除卡牌之前）
	var result = game_manager.add_human_action(action)
	
	# 检查行动是否成功添加
	if not result.success:
		_show_message(result.message)
		# 行动失败，不消耗卡牌，直接退出
		_exit_discard_action_phase()
		return
	
	# 行动成功，从手牌中移除卡牌
	var hand_manager = game_manager.hand_managers.get(GameManager.HUMAN_PLAYER_ID)
	if hand_manager:
		print("弃牌行动：从手牌中移除卡牌 ", discard_action_state.card.card_name, " 移除前手牌数量: ", hand_manager.hand_cards.size())
		hand_manager.remove_card(discard_action_state.card, "discarded")
		print("弃牌行动：移除后手牌数量: ", hand_manager.hand_cards.size())
	else:
		print("错误：无法获取手牌管理器")
	
	# 显示预览
	_update_action_preview()
	
	print("基本移动行动已添加到队列: ", source_sprite.sprite_name, " -> ", target_pos)
	print("提示：可以使用更多弃牌行动继续移动，只要距离在基础移动力范围内")
	
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

# ========== 动作预览系统 ==========

# 更新动作预览
func _update_action_preview():
	if not game_manager or not game_manager.action_resolver:
		return
	
	# 创建预览面板（如果不存在）
	if not action_preview_panel:
		_create_action_preview_panel()
	
	# 清除现有预览项
	_clear_action_preview_items()
	
	# 获取所有行动的预览
	var previews = game_manager.action_resolver.get_all_action_previews()
	
	if previews.size() == 0:
		# 没有行动，隐藏面板
		if action_preview_panel:
			action_preview_panel.visible = false
		return
	
	# 显示面板
	if action_preview_panel:
		action_preview_panel.visible = true
	
	# 按结算顺序分组显示
	var effect_previews: Array[Dictionary] = []
	var terrain_previews: Array[Dictionary] = []
	var attack_previews: Array[Dictionary] = []
	var move_previews: Array[Dictionary] = []
	
	for preview in previews:
		match preview.action.action_type:
			ActionResolver.ActionType.EFFECT:
				effect_previews.append(preview)
			ActionResolver.ActionType.TERRAIN:
				terrain_previews.append(preview)
			ActionResolver.ActionType.ATTACK:
				attack_previews.append(preview)
			ActionResolver.ActionType.MOVE:
				move_previews.append(preview)
	
	# 按顺序添加预览项
	for preview in effect_previews:
		_add_preview_item(preview)
	for preview in terrain_previews:
		_add_preview_item(preview)
	for preview in attack_previews:
		_add_preview_item(preview)
	for preview in move_previews:
		_add_preview_item(preview)
	
	# 在地图上高亮显示动作目标
	_highlight_action_targets_on_map(previews)

# 创建动作预览面板
func _create_action_preview_panel():
	action_preview_panel = Panel.new()
	action_preview_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	action_preview_panel.position = UIScaleManager.scale_vec2(Vector2(-320, 20))
	action_preview_panel.size = UIScaleManager.scale_vec2(Vector2(300, 400))
	action_preview_panel.visible = false
	
	# 添加标题
	var title_label = Label.new()
	title_label.text = "动作预览"
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label.position = UIScaleManager.scale_vec2(Vector2(10, 10))
	title_label.size = UIScaleManager.scale_vec2(Vector2(280, 30))
	UIScaleManager.apply_scale_to_label(title_label, 20)
	action_preview_panel.add_child(title_label)
	
	# 添加滚动容器
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.position = UIScaleManager.scale_vec2(Vector2(10, 50))
	scroll_container.size = UIScaleManager.scale_vec2(Vector2(280, 340))
	action_preview_panel.add_child(scroll_container)
	
	# 添加列表容器
	action_preview_list = VBoxContainer.new()
	action_preview_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_child(action_preview_list)
	
	add_child(action_preview_panel)

# 添加预览项
func _add_preview_item(preview: Dictionary):
	if not action_preview_list:
		return
	
	var item_panel = Panel.new()
	item_panel.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(260, 60))
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.position = UIScaleManager.scale_vec2(Vector2(5, 5))
	vbox.size = UIScaleManager.scale_vec2(Vector2(250, 50))
	item_panel.add_child(vbox)
	
	# 类型和精灵名称
	var type_label = Label.new()
	type_label.text = preview.type + " - " + preview.sprite_name
	UIScaleManager.apply_scale_to_label(type_label, 16)
	vbox.add_child(type_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = preview.description
	if preview.target_description != "":
		desc_label.text += " (" + preview.target_description + ")"
	UIScaleManager.apply_scale_to_label(desc_label, 14)
	vbox.add_child(desc_label)
	
	action_preview_list.add_child(item_panel)
	action_preview_items.append(item_panel)

# 清除预览项
func _clear_action_preview_items():
	for item in action_preview_items:
		if is_instance_valid(item):
			item.queue_free()
	action_preview_items.clear()
	
	if action_preview_list:
		for child in action_preview_list.get_children():
			child.queue_free()

# 清除动作预览
func _clear_action_preview():
	_clear_action_preview_items()
	if action_preview_panel:
		action_preview_panel.visible = false
	
	# 清除地图上的高亮
	if game_manager and game_manager.terrain_renderer:
		game_manager.terrain_renderer.clear_selected_highlights()

# 在地图上高亮显示动作目标
func _highlight_action_targets_on_map(previews: Array[Dictionary]):
	if not game_manager or not game_manager.terrain_renderer:
		return
	
	# 清除之前的高亮
	game_manager.terrain_renderer.clear_selected_highlights()
	
	# 高亮所有动作目标
	for preview in previews:
		var action = preview.action
		if not action:
			continue
		
		match action.action_type:
			ActionResolver.ActionType.ATTACK:
				if action.target is Sprite:
					var target = action.target as Sprite
					game_manager.terrain_renderer.highlight_selected_position(target.hex_position)
			
			ActionResolver.ActionType.MOVE:
				if action.target is Vector2i:
					var target_pos = action.target as Vector2i
					game_manager.terrain_renderer.highlight_selected_position(target_pos)
			
			ActionResolver.ActionType.TERRAIN:
				if action.target is Vector2i:
					var target_pos = action.target as Vector2i
					game_manager.terrain_renderer.highlight_selected_position(target_pos)
			
			ActionResolver.ActionType.EFFECT:
				if action.target is Sprite:
					var target = action.target as Sprite
					game_manager.terrain_renderer.highlight_selected_position(target.hex_position)

# ========== 回合结束按钮 ==========

# 创建回合结束按钮
func _create_end_turn_button():
	end_turn_button = Button.new()
	end_turn_button.text = "回合结束"
	end_turn_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	end_turn_button.position = UIScaleManager.scale_vec2(Vector2(-170, -60))
	end_turn_button.size = UIScaleManager.scale_vec2(Vector2(150, 50))
	UIScaleManager.apply_scale_to_button(end_turn_button, 18)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	end_turn_button.visible = false  # 初始隐藏，在游戏阶段显示
	add_child(end_turn_button)

# 回合结束按钮按下
func _on_end_turn_button_pressed():
	if not game_manager:
		return
	
	# 检查是否已经提交
	if game_manager.actions_submitted.get(GameManager.HUMAN_PLAYER_ID, false):
		print("已经提交过行动了")
		return
	
	print("点击回合结束按钮，提交回合")
	# 提交回合
	game_manager.submit_human_turn()
	
	# 禁用按钮
	if end_turn_button:
		end_turn_button.disabled = true
		print("回合结束按钮已禁用")

# 启用回合结束按钮（延迟调用，确保在正确的时机启用）
func _enable_end_turn_button(round_num: int):
	if end_turn_button:
		end_turn_button.disabled = false
		end_turn_button.visible = true
		print("回合开始，启用回合结束按钮 - 回合: ", round_num)
