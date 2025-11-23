class_name ManaCurve
extends Control

@onready var curve_container: HBoxContainer = $CurveContainer

var curve_bars: Array[ProgressBar] = []
var curve_labels: Array[Label] = []

func _ready():
	_create_curve_bars()

func _create_curve_bars():
	if not curve_container:
		return
	
	# 清空现有
	for child in curve_container.get_children():
		child.queue_free()
	curve_bars.clear()
	curve_labels.clear()
	
	# 创建费用柱状图：1费、2费、3费、4费、5+费
	var cost_ranges = [
		{"label": "1", "min": 1, "max": 1},
		{"label": "2", "min": 2, "max": 2},
		{"label": "3", "min": 3, "max": 3},
		{"label": "4", "min": 4, "max": 4},
		{"label": "5+", "min": 5, "max": 999}
	]
	
	for cost_info in cost_ranges:
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(50, 0)
		curve_container.add_child(vbox)
		
		# 标签
		var label = Label.new()
		label.text = cost_info.label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		vbox.add_child(label)
		curve_labels.append(label)
		
		# 进度条（垂直）
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(40, 100)
		progress_bar.max_value = 10  # 最大显示10张
		progress_bar.value = 0
		progress_bar.show_percentage = false
		progress_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		
		# 设置样式
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		style_bg.corner_radius_top_left = 4
		style_bg.corner_radius_top_right = 4
		style_bg.corner_radius_bottom_left = 4
		style_bg.corner_radius_bottom_right = 4
		progress_bar.add_theme_stylebox_override("background", style_bg)
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(0.3, 0.6, 1.0, 0.9)
		style_fill.corner_radius_top_left = 4
		style_fill.corner_radius_top_right = 4
		style_fill.corner_radius_bottom_left = 4
		style_fill.corner_radius_bottom_right = 4
		progress_bar.add_theme_stylebox_override("fill", style_fill)
		
		vbox.add_child(progress_bar)
		curve_bars.append(progress_bar)

func update_curve(deck_data: Array):
	if not curve_container or curve_bars.is_empty():
		return
	
	# 统计各费用数量
	var cost_counts = [0, 0, 0, 0, 0]  # 1费、2费、3费、4费、5+费
	
	for entry in deck_data:
		var count = entry.get("count", 0)
		var cost = entry.get("energy_cost", 1)  # 数据中应该有 energy_cost
		
		if cost >= 1 and cost <= 4:
			cost_counts[cost - 1] += count
		elif cost >= 5:
			cost_counts[4] += count
	
	# 更新进度条（带动画）
	for i in range(curve_bars.size()):
		var target_value = cost_counts[i]
		var tween = create_tween()
		tween.tween_property(curve_bars[i], "value", target_value, 0.3)

