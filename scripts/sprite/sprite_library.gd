class_name SpriteLibrary
extends RefCounted

# 精灵数据字典（key: 精灵ID）
var sprite_data: Dictionary = {}

func _init():
	_load_sprite_data()

func _load_sprite_data():
	var config_file = FileAccess.open("res://resources/data/sprite_data.json", FileAccess.READ)
	if not config_file:
		push_error("无法加载精灵数据配置文件")
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("精灵数据JSON解析失败")
		return
	
	var config = json.data
	var sprites_config = config.get("sprites", [])
	
	for sprite_config in sprites_config:
		var sprite_id = sprite_config.get("id", "")
		if sprite_id != "":
			sprite_data[sprite_id] = sprite_config

# 根据ID获取精灵数据
func get_sprite_data(sprite_id: String) -> Dictionary:
	return sprite_data.get(sprite_id, {})

# 获取所有精灵ID列表
func get_all_sprite_ids() -> Array[String]:
	return sprite_data.keys()

# 根据属性获取精灵列表
func get_sprites_by_attribute(attribute: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for sprite_id in sprite_data.keys():
		var data = sprite_data[sprite_id]
		if data.get("attribute", "") == attribute:
			results.append(data)
	return results

# 获取所有基础精灵（4只）
func get_base_sprites() -> Array[Dictionary]:
	return [
		get_sprite_data("F01"),
		get_sprite_data("W01"),
		get_sprite_data("S01"),
		get_sprite_data("R01")
	]

