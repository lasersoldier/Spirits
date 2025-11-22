@tool
extends EditorScript

# Theme辅助脚本
# 用于在编辑器中创建和配置全局Theme资源

# 运行此脚本来创建Theme资源
func _run():
	var theme = Theme.new()
	
	# 设置默认字体大小
	theme.default_font_size = 16
	
	# 创建按钮样式
	_create_button_styles(theme)
	
	# 保存Theme资源
	var path = "res://resources/themes/main_theme.tres"
	var dir = DirAccess.open("res://resources")
	if not dir.dir_exists("themes"):
		dir.make_dir("themes")
	
	ResourceSaver.save(theme, path)
	print("Theme已创建: ", path)

func _create_button_styles(theme: Theme):
	# 正常状态 - 无背景+发光边框
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.15, 0.3)
	normal_style.border_color = Color(1.0, 0.65, 0.0, 0.4)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	theme.set_stylebox("normal", "Button", normal_style)
	
	# 悬停状态 - 高亮边框
	var hover_style = normal_style.duplicate()
	hover_style.border_color = Color(1.0, 0.65, 0.0, 0.8)
	hover_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	theme.set_stylebox("hover", "Button", hover_style)
	
	# 按下状态
	var pressed_style = normal_style.duplicate()
	pressed_style.border_color = Color(1.0, 0.8, 0.4, 1.0)
	pressed_style.bg_color = Color(0.2, 0.2, 0.25, 0.6)
	theme.set_stylebox("pressed", "Button", pressed_style)
	
	# 禁用状态
	var disabled_style = normal_style.duplicate()
	disabled_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	disabled_style.bg_color = Color(0.1, 0.1, 0.1, 0.2)
	theme.set_stylebox("disabled", "Button", disabled_style)
	
	# 设置按钮字体颜色
	theme.set_color("font_color", "Button", Color(1.0, 0.95, 0.8, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 0.9, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.9, 0.7, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5, 0.5))

