class_name CardEffectShortener
extends RefCounted

# 效果解释字典
const EFFECT_EXPLANATIONS: Dictionary = {
	"抬高": "将地形高度提升指定等级",
	"降低": "将地形高度降低指定等级",
	"击退": "将精灵朝与施法者反方向击退指定距离",
	"提速": "增加精灵的移动范围",
	"回复": "恢复目标的生命值",
	"伤害": "对目标造成伤害",
	"持续": "效果持续指定回合数",
	"范围": "影响指定半径范围内的目标",
	"地形": "改变地形类型",
	"增益": "为目标添加增益状态",
	"减益": "为目标添加减益状态",
	"易伤": "使目标受到的所有伤害增加"
}

# 将效果数组转换为简称描述
static func get_short_description(effects: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	
	for effect in effects:
		var tag = effect.get("tag", "")
		var short_desc = _convert_effect_to_short(effect, tag)
		if not short_desc.is_empty():
			parts.append(short_desc)
	
	return " ".join(parts)

# 转换单个效果为简称
static func _convert_effect_to_short(effect: Dictionary, tag: String) -> String:
	match tag:
		"damage":
			var amount = effect.get("amount", 0)
			var knockback = effect.get("knockback", {})
			var result = "【伤害" + str(amount) + "】"
			if not knockback.is_empty():
				var distance = knockback.get("distance", 1)
				result += "【击退" + str(distance) + "】"
			return result
		
		"heal":
			var amount = effect.get("amount", 0)
			return "【回复" + str(amount) + "】"
		
		"terrain_change":
			var height_delta = effect.get("height_delta", 0)
			var terrain_type = effect.get("terrain_type", "")
			var result: Array[String] = []
			
			if height_delta != 0:
				if height_delta > 0:
					result.append("【抬高" + str(height_delta) + "】")
				else:
					result.append("【降低" + str(abs(height_delta)) + "】")
			
			if terrain_type != "" and terrain_type != "normal":
				result.append("【地形:" + terrain_type + "】")
			
			return " ".join(result)
		
		"apply_status":
			var modifiers = effect.get("modifiers", {})
			var duration = effect.get("duration", 0)
			var result: Array[String] = []
			
			if modifiers.has("movement_range_bonus"):
				var bonus = modifiers.get("movement_range_bonus", 0)
				if bonus > 0:
					result.append("【提速" + str(bonus) + "】")
			
			if duration > 0:
				result.append("【持续" + str(duration) + "】")
			
			return " ".join(result)
		
		"area_damage", "persistent_area_damage":
			var radius = effect.get("radius", 0)
			var damage = effect.get("damage", 0)
			var duration = effect.get("duration", 0)
			var knockback = effect.get("knockback", {})
			var result: Array[String] = []
			
			if radius > 0:
				result.append("【范围" + str(radius) + "】")
			if damage > 0:
				result.append("【伤害" + str(damage) + "】")
			if not knockback.is_empty():
				var distance = knockback.get("distance", 1)
				result.append("【击退" + str(distance) + "】")
			if duration > 0:
				result.append("【持续" + str(duration) + "】")
			
			return " ".join(result)
		
		"area_status":
			var radius = effect.get("radius", 0)
			var status = effect.get("status", {})
			var duration = status.get("duration", 0)
			var modifiers = status.get("modifiers", {})
			var result: Array[String] = []
			
			if radius > 0:
				result.append("【范围" + str(radius) + "】")
			if duration > 0:
				result.append("【持续" + str(duration) + "】")
			# 检查是否有增益/减益
			if modifiers.has("damage_taken_bonus") or modifiers.has("vulnerable"):
				result.append("【易伤】")
			elif modifiers.has("movement_range_bonus"):
				var bonus = modifiers.get("movement_range_bonus", 0)
				result.append("【提速" + str(bonus) + "】")
			
			return " ".join(result)
		
		_:
			return ""

# 获取效果解释
static func get_explanation(short_code: String) -> String:
	# 解析简称代码，如 "【抬高1】" -> "抬高"
	var code = short_code.replace("【", "").replace("】", "")
	var parts = code.split(":")
	var base_code = parts[0]
	
	# 提取数字和基础代码
	var base_name = ""
	var param_value = ""
	
	# 尝试匹配基础名称（按长度从长到短排序，优先匹配更长的名称）
	var sorted_keys = EFFECT_EXPLANATIONS.keys()
	sorted_keys.sort_custom(func(a, b): return a.length() > b.length())
	
	for key in sorted_keys:
		if base_code.begins_with(key):
			base_name = key
			# 提取参数值（数字部分）
			if base_code.length() > key.length():
				param_value = base_code.substr(key.length())
			break
	
	if base_name != "":
		var explanation = EFFECT_EXPLANATIONS.get(base_name, "")
		# 如果有参数值，添加到解释中
		if param_value != "":
			# 根据基础名称添加参数说明
			match base_name:
				"抬高", "降低":
					explanation = explanation.replace("指定等级", param_value + "级")
				"击退":
					explanation = explanation.replace("指定距离", param_value + "格")
				"提速":
					explanation = explanation.replace("移动范围", "移动范围+" + param_value)
				"回复":
					explanation = explanation.replace("目标的生命值", param_value + "点生命值")
				"伤害":
					explanation = explanation.replace("对目标造成伤害", "对目标造成" + param_value + "点伤害")
				"持续":
					explanation = explanation.replace("指定回合数", param_value + "回合")
				"范围":
					explanation = explanation.replace("指定半径", param_value + "格半径")
		
		# 如果有冒号分隔的参数（如地形类型）
		if parts.size() > 1:
			explanation += " (" + parts[1] + ")"
		
		return explanation
	
	return ""

# 从简称描述中提取所有使用的简称
static func extract_short_codes(description: String) -> Array[String]:
	var codes: Array[String] = []
	var regex = RegEx.new()
	regex.compile("【[^】]+】")
	
	var results = regex.search_all(description)
	for result in results:
		codes.append(result.get_string())
	
	return codes

