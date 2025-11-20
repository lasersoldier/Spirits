@tool
extends Control

# UI节点引用
var category_option: OptionButton
var entry_list: ItemList
var detail_panel: VBoxContainer
var detail_title: Label
var detail_content: RichTextLabel

# 数据
var encyclopedia_data: Dictionary = {}
var sprite_data: Dictionary = {}
var card_data: Dictionary = {}
var current_category: String = "attributes"

# 分类映射
var category_names = {
	"attributes": "精灵属性",
	"traits": "精灵特质",
	"card_effects": "卡牌效果",
	"game_mechanics": "游戏机制",
	"sprites": "精灵信息",
	"cards": "卡牌信息"
}

func _ready():
	# 获取UI节点引用
	category_option = $HSplitContainer/LeftPanel/CategoryOption
	entry_list = $HSplitContainer/LeftPanel/EntryList
	detail_panel = $HSplitContainer/RightPanel/DetailPanel
	detail_title = $HSplitContainer/RightPanel/DetailPanel/VBoxContainer/TitleLabel
	detail_content = $HSplitContainer/RightPanel/DetailPanel/VBoxContainer/ContentLabel
	
	# 连接信号
	category_option.item_selected.connect(_on_category_selected)
	entry_list.item_selected.connect(_on_entry_selected)
	
	# 加载数据
	_load_data()
	
	# 初始化UI
	_initialize_categories()
	_refresh_entry_list()

func _load_data():
	# 加载词条数据
	var file = FileAccess.open("res://resources/data/encyclopedia_data.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			encyclopedia_data = json.get_data()
		else:
			push_error("Failed to parse encyclopedia_data.json: " + json.get_error_message())
	
	# 加载精灵数据
	file = FileAccess.open("res://resources/data/sprite_data.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			sprite_data = json.get_data()
		else:
			push_error("Failed to parse sprite_data.json: " + json.get_error_message())
	
	# 加载卡牌数据
	file = FileAccess.open("res://resources/data/card_data.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			card_data = json.get_data()
		else:
			push_error("Failed to parse card_data.json: " + json.get_error_message())

func _initialize_categories():
	category_option.clear()
	for key in category_names.keys():
		category_option.add_item(category_names[key])
	category_option.selected = 0
	current_category = category_names.keys()[0]

func _on_category_selected(index: int):
	current_category = category_names.keys()[index]
	_refresh_entry_list()
	# 清空详情
	detail_title.text = ""
	detail_content.text = ""

func _refresh_entry_list():
	entry_list.clear()
	
	if current_category == "sprites":
		# 显示所有精灵
		if sprite_data.has("sprites"):
			for sprite in sprite_data.sprites:
				var display_name = sprite.get("name", sprite.get("id", "未知"))
				entry_list.add_item(display_name)
	elif current_category == "cards":
		# 显示所有卡牌
		if card_data.has("cards"):
			for card in card_data.cards:
				var display_name = card.get("name", card.get("id", "未知"))
				entry_list.add_item(display_name)
	else:
		# 显示词条列表
		if encyclopedia_data.has(current_category):
			for entry in encyclopedia_data[current_category]:
				var display_name = entry.get("name", entry.get("id", "未知"))
				entry_list.add_item(display_name)

func _on_entry_selected(index: int):
	if index < 0:
		return
	
	var entry_name = entry_list.get_item_text(index)
	_show_entry_details(entry_name)

func _show_entry_details(entry_name: String):
	if current_category == "sprites":
		_show_sprite_details(entry_name)
	elif current_category == "cards":
		_show_card_details(entry_name)
	else:
		_show_encyclopedia_entry_details(entry_name)

func _show_sprite_details(sprite_name: String):
	# 查找精灵数据
	var sprite_info = null
	if sprite_data.has("sprites"):
		for sprite in sprite_data.sprites:
			if sprite.get("name", "") == sprite_name or sprite.get("id", "") == sprite_name:
				sprite_info = sprite
				break
	
	if not sprite_info:
		detail_title.text = "未找到精灵"
		detail_content.text = ""
		return
	
	# 显示精灵详细信息
	detail_title.text = sprite_info.get("name", "未知精灵")
	
	var content_text = ""
	content_text += "[b]ID:[/b] " + sprite_info.get("id", "未知") + "\n\n"
	
	# 属性
	var attribute = sprite_info.get("attribute", "")
	if attribute:
		var attr_name = _get_attribute_name(attribute)
		content_text += "[b]属性:[/b] " + attr_name + "\n\n"
	
	# 基础属性
	content_text += "[b]基础属性:[/b]\n"
	content_text += "  生命值: " + str(sprite_info.get("base_hp", 0)) + "\n"
	content_text += "  移动力: " + str(sprite_info.get("base_movement", 0)) + "\n"
	content_text += "  视野范围: " + str(sprite_info.get("vision_range", 0)) + "\n"
	content_text += "  攻击范围: " + str(sprite_info.get("attack_range", 0)) + "\n"
	content_text += "  施法范围: " + str(sprite_info.get("cast_range", 0)) + "\n\n"
	
	# 攻击高度限制
	var height_limit = sprite_info.get("attack_height_limit", "none")
	if height_limit != "none":
		content_text += "[b]攻击高度限制:[/b] " + _get_height_limit_text(height_limit) + "\n\n"
	
	# 特殊机制
	var mechanisms = sprite_info.get("special_mechanisms", [])
	if mechanisms.size() > 0:
		content_text += "[b]特殊机制:[/b]\n"
		for mechanism in mechanisms:
			var mechanism_name = _get_trait_name(mechanism)
			content_text += "  • " + mechanism_name + "\n"
		content_text += "\n"
	
	# 模型路径
	var model_path = sprite_info.get("model_path", "")
	if model_path:
		content_text += "[b]模型路径:[/b] " + model_path + "\n"
	
	detail_content.text = content_text

func _show_encyclopedia_entry_details(entry_name: String):
	# 查找词条数据
	var entry_info = null
	if encyclopedia_data.has(current_category):
		for entry in encyclopedia_data[current_category]:
			if entry.get("name", "") == entry_name:
				entry_info = entry
				break
	
	if not entry_info:
		detail_title.text = "未找到词条"
		detail_content.text = ""
		return
	
	# 显示词条详细信息
	detail_title.text = entry_info.get("name", "未知词条")
	
	var content_text = ""
	
	# 描述
	var description = entry_info.get("description", "")
	if description:
		content_text += "[b]描述:[/b]\n" + description + "\n\n"
	
	# 根据分类显示不同内容
	if current_category == "attributes":
		# 属性特色
		var features = entry_info.get("features", [])
		if features.size() > 0:
			content_text += "[b]特色:[/b]\n"
			for feature in features:
				content_text += "  • " + feature + "\n"
			content_text += "\n"
		
		# 列出具有该属性的精灵
		var sprites_with_attr = _get_sprites_with_attribute(entry_info.get("id", ""))
		if sprites_with_attr.size() > 0:
			content_text += "[b]具有该属性的精灵:[/b]\n"
			for sprite_name in sprites_with_attr:
				content_text += "  • " + sprite_name + "\n"
	
	elif current_category == "traits":
		# 列出具有该特质的精灵
		var sprite_ids = entry_info.get("sprites", [])
		if sprite_ids.size() > 0:
			content_text += "[b]具有该特质的精灵:[/b]\n"
			for sprite_id in sprite_ids:
				var sprite_name = _get_sprite_name_by_id(sprite_id)
				content_text += "  • " + sprite_name + " (" + sprite_id + ")\n"
	
	elif current_category == "card_effects":
		# 参数说明
		var parameters = entry_info.get("parameters", {})
		if parameters.size() > 0:
			content_text += "[b]参数说明:[/b]\n"
			for param_name in parameters.keys():
				content_text += "  • [b]" + param_name + ":[/b] " + str(parameters[param_name]) + "\n"
			content_text += "\n"
		
		# 列出使用该效果的卡牌
		var card_ids = entry_info.get("cards", [])
		if card_ids.size() > 0:
			content_text += "[b]使用该效果的卡牌:[/b]\n"
			for card_id in card_ids:
				var card_name = _get_card_name_by_id(card_id)
				content_text += "  • " + card_name + " (" + card_id + ")\n"
	
	elif current_category == "game_mechanics":
		# 游戏机制特色
		var features = entry_info.get("features", [])
		if features.size() > 0:
			content_text += "[b]机制特点:[/b]\n"
			for feature in features:
				content_text += "  • " + feature + "\n"
			content_text += "\n"
	
	detail_content.text = content_text

func _get_attribute_name(attr_id: String) -> String:
	if encyclopedia_data.has("attributes"):
		for attr in encyclopedia_data.attributes:
			if attr.get("id", "") == attr_id:
				return attr.get("name", attr_id)
	return attr_id

func _get_trait_name(trait_id: String) -> String:
	if encyclopedia_data.has("traits"):
		for trait_entry in encyclopedia_data.traits:
			if trait_entry.get("id", "") == trait_id:
				return trait_entry.get("name", trait_id)
	return trait_id

func _get_height_limit_text(limit: String) -> String:
	match limit:
		"same_or_high_to_low":
			return "相同或从高到低"
		"same_or_low_to_high":
			return "相同或从低到高"
		"same_only":
			return "仅相同高度"
		_:
			return "无限制"

func _get_sprites_with_attribute(attr_id: String) -> Array[String]:
	var result: Array[String] = []
	if sprite_data.has("sprites"):
		for sprite in sprite_data.sprites:
			if sprite.get("attribute", "") == attr_id:
				result.append(sprite.get("name", sprite.get("id", "未知")))
	return result

func _get_sprite_name_by_id(sprite_id: String) -> String:
	if sprite_data.has("sprites"):
		for sprite in sprite_data.sprites:
			if sprite.get("id", "") == sprite_id:
				return sprite.get("name", sprite_id)
	return sprite_id

func _get_card_name_by_id(card_id: String) -> String:
	if card_data.has("cards"):
		for card in card_data.cards:
			if card.get("id", "") == card_id:
				return card.get("name", card_id)
	return card_id

func _show_card_details(card_name: String):
	# 查找卡牌数据
	var card_info = null
	if card_data.has("cards"):
		for card in card_data.cards:
			if card.get("name", "") == card_name or card.get("id", "") == card_name:
				card_info = card
				break
	
	if not card_info:
		detail_title.text = "未找到卡牌"
		detail_content.text = ""
		return
	
	# 显示卡牌详细信息
	detail_title.text = card_info.get("name", "未知卡牌")
	
	var content_text = ""
	content_text += "[b]ID:[/b] " + card_info.get("id", "未知") + "\n\n"
	
	# 属性
	var attributes = card_info.get("attributes", [])
	if attributes.size() > 0:
		content_text += "[b]属性:[/b] "
		var attr_names: Array[String] = []
		for attr_id in attributes:
			var attr_name = _get_attribute_name(attr_id)
			attr_names.append(attr_name)
		content_text += "、".join(attr_names) + "\n\n"
	
	# 能量消耗
	var energy_cost = card_info.get("energy_cost", 0)
	content_text += "[b]能量消耗:[/b] " + str(energy_cost) + "\n\n"
	
	# 卡牌类型
	var card_type = card_info.get("type", "")
	if card_type:
		var type_name = ""
		match card_type:
			"attack":
				type_name = "攻击"
			"terrain":
				type_name = "地形"
			"support":
				type_name = "支援"
			_:
				type_name = card_type
		content_text += "[b]卡牌类型:[/b] " + type_name + "\n\n"
	
	# 效果描述
	var effect_description = card_info.get("effect", "")
	if effect_description:
		content_text += "[b]效果描述:[/b]\n" + effect_description + "\n\n"
	
	# 目标类型
	var target_type = card_info.get("target_type", "")
	if target_type:
		var target_name = ""
		match target_type:
			"enemy_sprite":
				target_name = "敌方精灵"
			"adjacent_tile":
				target_name = "相邻地形"
			"self":
				target_name = "自身"
			_:
				target_name = target_type
		content_text += "[b]目标类型:[/b] " + target_name + "\n\n"
	
	# 范围要求
	var range_requirement = card_info.get("range_requirement", "")
	if range_requirement:
		var range_name = ""
		match range_requirement:
			"within_attack_range":
				range_name = "攻击范围内"
			"adjacent":
				range_name = "相邻1格"
			"adjacent_2_tiles":
				range_name = "相邻2格"
			"adjacent_3_tiles":
				range_name = "相邻3格"
			"line_2_tiles":
				range_name = "直线2格"
			"none":
				range_name = "无范围要求"
			_:
				range_name = range_requirement
		content_text += "[b]范围要求:[/b] " + range_name + "\n\n"
	
	# 双属性卡牌范围
	if attributes.size() == 2:
		var dual_range = card_info.get("dual_attribute_range", 1)
		if dual_range > 0:
			content_text += "[b]双属性范围:[/b] " + str(dual_range) + "格\n\n"
	
	# 效果列表
	var effects = card_info.get("effects", [])
	if effects.size() > 0:
		content_text += "[b]效果列表:[/b]\n"
		for i in range(effects.size()):
			var effect = effects[i]
			var effect_tag = effect.get("tag", "")
			var effect_name = _get_effect_name(effect_tag)
			content_text += "  " + str(i + 1) + ". " + effect_name + " (" + effect_tag + ")\n"
			
			# 显示效果参数
			for param_name in effect.keys():
				if param_name == "tag":
					continue
				var param_value = effect[param_name]
				content_text += "     • " + param_name + ": " + str(param_value) + "\n"
		content_text += "\n"
	
	detail_content.text = content_text

func _get_effect_name(effect_tag: String) -> String:
	if encyclopedia_data.has("card_effects"):
		for effect_entry in encyclopedia_data.card_effects:
			if effect_entry.get("tag", "") == effect_tag:
				return effect_entry.get("name", effect_tag)
	return effect_tag
