class_name PauseMenu
extends Control

signal resume_requested
signal main_menu_requested

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var main_menu_button: Button = $Panel/VBox/MainMenuButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process_unhandled_input(true)
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.disabled = true
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func open():
	if visible:
		return
	visible = true
	grab_focus()
	get_viewport().set_input_as_handled()
	get_tree().paused = true

func close():
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _on_resume_pressed():
	resume_requested.emit()

func _on_main_menu_pressed():
	main_menu_requested.emit()

func _unhandled_input(event: InputEvent):
	if not visible:
		return
	
	# 如果暂停菜单打开，按ESC关闭
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not event.echo:
		resume_requested.emit()
		get_viewport().set_input_as_handled()
