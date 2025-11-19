class_name MainMenu
extends Control

@export_file("*.tscn") var single_player_scene: String = "res://scenes/main.tscn"
@export_file("*.tscn") var training_scene: String = "res://scenes/training.tscn"

@onready var single_player_button: Button = %SinglePlayerButton
@onready var training_button: Button = %TrainingButton

func _ready():
	_connect_button(single_player_button, single_player_scene)
	_connect_button(training_button, training_scene)

func _connect_button(button: Button, scene_path: String):
	if not button:
		return
	button.pressed.connect(func():
		_load_scene(scene_path)
	)

func _load_scene(scene_path: String):
	if scene_path.is_empty():
		push_warning("MainMenu: scene path is empty")
		return
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("MainMenu: failed to load scene: " + scene_path + " (error " + str(error) + ")")
