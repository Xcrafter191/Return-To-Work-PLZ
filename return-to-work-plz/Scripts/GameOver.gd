extends CanvasLayer

@onready var main_menu_button = $Content/MainMenuButton
@onready var exit_button = $Content/ExitButton
@onready var restart_button = $Content/RestartButton

func _ready():
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	main_menu_button.mouse_entered.connect(_on_button_hover)
	exit_button.mouse_entered.connect(_on_button_hover)
	if restart_button:
		restart_button.mouse_entered.connect(_on_button_hover)
		
	visible = false

func _on_button_hover():
	UISoundManager.play_hover()

func show_game_over():
	visible = true
	get_tree().paused = true
	# Stop in-game BGM and play game over music
	if has_node("/root/MusicManager"):
		MusicManager.play_track("res://Assets/Music/gameover.mp3")

func _on_main_menu_pressed():
	UISoundManager.play_click()
	get_tree().paused = false
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_restart_button_pressed() -> void:
	UISoundManager.play_click()
	get_tree().paused = false
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()
	if has_node("/root/GameManager"):
		GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_exit_pressed():
	UISoundManager.play_click()
	get_tree().paused = false
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
