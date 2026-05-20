extends CanvasLayer

@onready var main_menu_button = $Content/MainMenuButton
@onready var exit_button = $Content/ExitButton

func _ready():
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	visible = false

func show_game_over():
	visible = true
	get_tree().paused = true

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	if has_node("/root/GameManager"):
		GameManager.reset_game_state()
	var error = get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_exit_pressed():
	print("Exit button pressed")
	get_tree().quit()
