extends Control

@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var exit_button = $VBoxContainer/ExitButton

func _ready():
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_main_menu_pressed():
	print("Main Menu button pressed - not connected yet")
	# get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_exit_pressed():
	print("Exit button pressed")
	get_tree().quit()
