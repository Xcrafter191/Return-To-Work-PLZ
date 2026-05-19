extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var logo_rect = $LogoRect

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_play_pressed():
	print("Play button pressed - not connected yet")
	var error = get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	

func _on_exit_pressed():
	print("Exit button pressed")
	get_tree().quit()
