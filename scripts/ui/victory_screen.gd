class_name VictoryScreen
extends Control

@onready var title_label: Label = %TitleLabel
@onready var winner_label: Label = %WinnerLabel
@onready var tip_label: Label = %TipLabel
@onready var back_button: Button = %BackButton

var winner_id: int = -1
const HUMAN_PLAYER_ID := 0

func _ready():
	set_process_input(true)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

func set_result(new_winner_id: int):
	winner_id = new_winner_id
	
	var result_text = "玩家 " + str(new_winner_id) + " 获得赏金胜利！"
	if new_winner_id == HUMAN_PLAYER_ID:
		result_text = "恭喜，你获得了赏金胜利！"
	
	if winner_label:
		winner_label.text = result_text
	
	if tip_label:
		tip_label.text = "携带赏金返回任意部署区域即可获胜。"

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


