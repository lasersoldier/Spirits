class_name DeployUI
extends Control

# 部署界面UI
var sprite_selection_panel: Panel
var selected_sprites_container: HBoxContainer
var confirm_button: Button
var cancel_button: Button
var instruction_label: Label

# 选中的精灵ID列表（最多3个）
var selected_sprite_ids: Array[String] = []
# 待部署的精灵和位置配对
var deployment_queue: Array[Dictionary] = []  # [{sprite_id: String, position: Vector2i}, ...]

# 游戏管理器引用
var game_manager: GameManager
var sprite_deploy: SpriteDeployInterface
var game_map: GameMap
var terrain_renderer: TerrainRenderer  # 地形渲染器引用，用于高亮

# 当前部署状态
enum DeployState {
	SELECTING_SPRITES,  # 选择精灵阶段
	SELECTING_POSITIONS  # 选择位置阶段
}
var current_state: DeployState = DeployState.SELECTING_SPRITES

signal deployment_complete(selected_ids: Array[String], positions: Array[Vector2i])
signal deployment_cancelled()

func _ready():
	_create_ui()

func _create_ui():
	# 获取屏幕尺寸
	var screen_size = get_viewport().get_visible_rect().size
	
	# 创建主面板（使用全局缩放）
	# 占屏幕上半部分，左右留空（居中，宽度为屏幕的70%）
	var main_panel = Panel.new()
	var panel_width = screen_size.x * 0.7
	var panel_height = screen_size.y * 0.5  # 占屏幕上半部分
	main_panel.size = UIScaleManager.scale_vec2(Vector2(panel_width, panel_height))
	# 居中显示，左右留空
	main_panel.position = UIScaleManager.scale_vec2(Vector2((screen_size.x - panel_width) / 2, 20))
	UIScaleManager.apply_scale_to_panel(main_panel)
	add_child(main_panel)
	
	# 创建垂直布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(vbox)
	
	# 标题（使用全局缩放）
	var title_label = Label.new()
	title_label.text = "精灵部署"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(title_label, 24)
	vbox.add_child(title_label)
	
	# 说明文字（使用全局缩放）
	instruction_label = Label.new()
	instruction_label.text = "请选择3只精灵（从4只基础精灵中选择）"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIScaleManager.apply_scale_to_label(instruction_label, 18)
	vbox.add_child(instruction_label)
	
	# 精灵选择区域（使用全局缩放）
	var sprite_selection_label = Label.new()
	sprite_selection_label.text = "可选精灵："
	UIScaleManager.apply_scale_to_label(sprite_selection_label, 18)
	vbox.add_child(sprite_selection_label)
	
	var sprite_grid = GridContainer.new()
	sprite_grid.columns = 2
	vbox.add_child(sprite_grid)
	
	# 显示4只基础精灵供选择
	var sprite_library = SpriteLibrary.new()
	var base_sprites = sprite_library.get_base_sprites()
	
	for sprite_data in base_sprites:
		var sprite_id = sprite_data.get("id", "")
		var sprite_name = sprite_data.get("name", "")
		var sprite_attr = sprite_data.get("attribute", "")
		
		# 创建精灵卡片（使用全局缩放）
		var sprite_card = Panel.new()
		sprite_card.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(400, 150))
		UIScaleManager.apply_scale_to_panel(sprite_card)
		sprite_grid.add_child(sprite_card)
		
		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite_card.add_child(card_vbox)
		
		# 精灵名称（使用全局缩放）
		var name_label = Label.new()
		name_label.text = sprite_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIScaleManager.apply_scale_to_label(name_label, 20)
		card_vbox.add_child(name_label)
		
		# 属性（使用全局缩放）
		var attr_label = Label.new()
		attr_label.text = "属性: " + sprite_attr
		attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIScaleManager.apply_scale_to_label(attr_label, 16)
		card_vbox.add_child(attr_label)
		
		# 选择按钮（使用全局缩放）
		var select_button = Button.new()
		select_button.text = "选择"
		UIScaleManager.apply_scale_to_button(select_button, 16)
		select_button.pressed.connect(_on_sprite_selected.bind(sprite_id, sprite_card))
		card_vbox.add_child(select_button)
	
	# 已选精灵显示区域（使用全局缩放）
	var selected_label = Label.new()
	selected_label.text = "已选精灵（0/3）："
	UIScaleManager.apply_scale_to_label(selected_label, 18)
	vbox.add_child(selected_label)
	
	selected_sprites_container = HBoxContainer.new()
	vbox.add_child(selected_sprites_container)
	
	# 按钮区域
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	confirm_button = Button.new()
	confirm_button.text = "确认选择"
	confirm_button.disabled = true
	UIScaleManager.apply_scale_to_button(confirm_button, 18)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	button_container.add_child(confirm_button)
	
	cancel_button = Button.new()
	cancel_button.text = "取消"
	UIScaleManager.apply_scale_to_button(cancel_button, 18)
	cancel_button.pressed.connect(_on_cancel)
	button_container.add_child(cancel_button)

func _on_sprite_selected(sprite_id: String, _sprite_card: Panel):
	if current_state != DeployState.SELECTING_SPRITES:
		return
	
	if selected_sprite_ids.has(sprite_id):
		# 取消选择
		selected_sprite_ids.erase(sprite_id)
		_update_selected_display()
	else:
		# 选择精灵（最多3个）
		if selected_sprite_ids.size() < 3:
			selected_sprite_ids.append(sprite_id)
			_update_selected_display()
		else:
			print("最多只能选择3只精灵")
	
	# 更新确认按钮状态
	confirm_button.disabled = selected_sprite_ids.size() != 3

func _update_selected_display():
	# 清空已选显示
	for child in selected_sprites_container.get_children():
		child.queue_free()
	
	# 更新标签
	var selected_label = selected_sprites_container.get_parent().get_child(selected_sprites_container.get_index() - 1) as Label
	if selected_label:
		selected_label.text = "已选精灵（" + str(selected_sprite_ids.size()) + "/3）："
	
	# 显示已选精灵
	var sprite_library = SpriteLibrary.new()
	for sprite_id in selected_sprite_ids:
		var sprite_data = sprite_library.get_sprite_data(sprite_id)
		if sprite_data.is_empty():
			continue
		
		var sprite_name = sprite_data.get("name", "")
		var sprite_attr = sprite_data.get("attribute", "")
		
		var selected_card = Panel.new()
		selected_card.custom_minimum_size = UIScaleManager.scale_vec2(Vector2(250, 120))
		UIScaleManager.apply_scale_to_panel(selected_card)
		selected_sprites_container.add_child(selected_card)
		
		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selected_card.add_child(card_vbox)
		
		var name_label = Label.new()
		name_label.text = sprite_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIScaleManager.apply_scale_to_label(name_label, 18)
		card_vbox.add_child(name_label)
		
		var attr_label = Label.new()
		attr_label.text = sprite_attr
		attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIScaleManager.apply_scale_to_label(attr_label, 16)
		card_vbox.add_child(attr_label)

func _on_confirm_selection():
	if selected_sprite_ids.size() != 3:
		return
	
	# 进入选择位置阶段
	current_state = DeployState.SELECTING_POSITIONS
	instruction_label.text = "请在地图上点击3个起始格子进行部署（按选择顺序）"
	confirm_button.text = "完成部署"
	confirm_button.disabled = true
	
	# 高亮显示可部署位置
	_highlight_deploy_positions()

func _highlight_deploy_positions():
	if not game_map:
		return
	
	# 获取玩家的部署位置
	var deploy_positions = game_map.get_deploy_positions(0)
	print("可部署位置: ", deploy_positions)
	
	# 在地图上高亮显示这些位置
	if not terrain_renderer and game_manager:
		# 从game_manager获取terrain_renderer
		terrain_renderer = game_manager.terrain_renderer
	
	if terrain_renderer:
		print("开始高亮显示 ", deploy_positions.size(), " 个可部署位置")
		terrain_renderer.highlight_deploy_positions(deploy_positions)
	else:
		print("警告: 无法找到地形渲染器，无法显示高亮")

func _on_cancel():
	# 清除高亮
	if terrain_renderer:
		terrain_renderer.clear_highlights()
	deployment_cancelled.emit()
	queue_free()

# 处理地图点击（由外部调用）
func handle_map_click(hex_coord: Vector2i):
	if current_state != DeployState.SELECTING_POSITIONS:
		return
	
	if not game_map:
		return
	
	# 检查是否是有效的部署位置
	var deploy_positions = game_map.get_deploy_positions(0)
	if hex_coord not in deploy_positions:
		print("无效的部署位置")
		return
	
	# 检查是否已经选择过这个位置（如果已选择，则取消选择）
	for i in range(deployment_queue.size()):
		var item = deployment_queue[i]
		if item.get("position") == hex_coord:
			# 取消选择这个位置
			deployment_queue.remove_at(i)
			print("已取消选择位置 ", hex_coord)
			
			# 清除红色高亮和预览
			if terrain_renderer:
				terrain_renderer.clear_selected_highlights()
				terrain_renderer.clear_preview(hex_coord)
			
			# 重新显示所有已选择位置的高亮和预览
			_update_selected_highlights()
			
			# 更新说明文字
			var remaining_count = selected_sprite_ids.size() - deployment_queue.size()
			if remaining_count > 0:
				instruction_label.text = "已选择 " + str(deployment_queue.size()) + "/3 个位置，还需选择 " + str(remaining_count) + " 个"
			else:
				instruction_label.text = "请在地图上点击3个起始格子进行部署（按选择顺序）"
			confirm_button.disabled = true
			return
	
	# 找到下一个未分配的精灵
	var assigned_sprite_ids: Array[String] = []
	for item in deployment_queue:
		assigned_sprite_ids.append(item.get("sprite_id"))
	
	var sprite_id: String = ""
	for candidate_id in selected_sprite_ids:
		if candidate_id not in assigned_sprite_ids:
			sprite_id = candidate_id
			break
	
	if sprite_id.is_empty():
		print("所有精灵已选择位置")
		return
	deployment_queue.append({
		"sprite_id": sprite_id,
		"position": hex_coord
	})
	
	print("已选择位置 ", hex_coord, " 用于部署 ", sprite_id)
	
	# 显示红色高亮和精灵预览
	if terrain_renderer:
		terrain_renderer.highlight_selected_position(hex_coord)
		
		# 获取精灵属性用于预览
		var sprite_library = SpriteLibrary.new()
		var sprite_data = sprite_library.get_sprite_data(sprite_id)
		var sprite_attribute = sprite_data.get("attribute", "")
		terrain_renderer.show_sprite_preview(hex_coord, sprite_id, sprite_attribute)
	
	# 更新说明文字
	var remaining_count = selected_sprite_ids.size() - deployment_queue.size()
	if remaining_count > 0:
		instruction_label.text = "已选择 " + str(deployment_queue.size()) + "/3 个位置，还需选择 " + str(remaining_count) + " 个（点击已选择位置可取消）"
	else:
		instruction_label.text = "已选择所有位置，点击确认完成部署（点击已选择位置可取消）"
		confirm_button.disabled = false

# 更新已选择位置的高亮和预览
func _update_selected_highlights():
	if not terrain_renderer:
		return
	
	# 清除所有已选择位置高亮和预览
	terrain_renderer.clear_selected_highlights()
	terrain_renderer.clear_previews()
	
	# 重新显示所有已选择位置
	var sprite_library = SpriteLibrary.new()
	for item in deployment_queue:
		var deploy_position = item.get("position")
		var sprite_id = item.get("sprite_id")
		
		# 显示红色高亮
		terrain_renderer.highlight_selected_position(deploy_position)
		
		# 显示精灵预览
		var sprite_data = sprite_library.get_sprite_data(sprite_id)
		var sprite_attribute = sprite_data.get("attribute", "")
		terrain_renderer.show_sprite_preview(deploy_position, sprite_id, sprite_attribute)

func _on_confirm_deployment():
	if deployment_queue.size() != 3:
		return
	
	# 提取精灵ID和位置
	var sprite_ids: Array[String] = []
	var positions: Array[Vector2i] = []
	
	for item in deployment_queue:
		sprite_ids.append(item.get("sprite_id"))
		positions.append(item.get("position"))
	
	# 清除高亮
	if terrain_renderer:
		terrain_renderer.clear_highlights()
	
	# 发送完成信号
	deployment_complete.emit(sprite_ids, positions)
	queue_free()

func _on_confirm_button_pressed():
	if current_state == DeployState.SELECTING_SPRITES:
		_on_confirm_selection()
	elif current_state == DeployState.SELECTING_POSITIONS:
		_on_confirm_deployment()
