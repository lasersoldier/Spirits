@tool
extends EditorPlugin

var encyclopedia_panel: Control

func _enter_tree():
	# 加载面板场景
	var panel_scene = preload("res://addons/encyclopedia/ui/encyclopedia_panel.tscn")
	encyclopedia_panel = panel_scene.instantiate()
	
	# 添加到编辑器dock（左侧）
	add_control_to_dock(DOCK_SLOT_LEFT_UL, encyclopedia_panel)
	
	print("词条图鉴插件已加载")

func _exit_tree():
	# 移除面板
	if encyclopedia_panel:
		remove_control_from_docks(encyclopedia_panel)
		encyclopedia_panel.queue_free()
	
	print("词条图鉴插件已卸载")
