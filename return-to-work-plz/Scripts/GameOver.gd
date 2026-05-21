extends CanvasLayer

@onready var main_menu_button = $Content/MainMenuButton
@onready var restart_button = $Content/RestartButton
@onready var score_label = $Content/ScoreLabel
@onready var content = $Content
@onready var dim_overlay = $DimOverlay

func _ready():
	if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if restart_button and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if not main_menu_button.mouse_entered.is_connected(_on_button_hover):
		main_menu_button.mouse_entered.connect(_on_button_hover)
	if restart_button and not restart_button.mouse_entered.is_connected(_on_button_hover):
		restart_button.mouse_entered.connect(_on_button_hover)
		
	# Bikin blur shader langsung lewat script
	var shader_code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	void fragment() {
		vec4 blur_color = textureLod(screen_texture, SCREEN_UV, 3.0);
		COLOR = mix(blur_color, COLOR, COLOR.a);
	}
	"""
	var shader = Shader.new()
	shader.code = shader_code
	var mat = ShaderMaterial.new()
	mat.shader = shader
	dim_overlay.material = mat
	
	visible = false

func _on_button_hover():
	UISoundManager.play_hover()

func show_game_over():
	visible = true
	get_tree().paused = true
	
	# Tampilin skor
	if has_node("/root/GameManager"):
		score_label.text = "SCORE: " + str(GameManager.current_score)
		
	# Stop in-game BGM and play game over music
	if has_node("/root/MusicManager"):
		MusicManager.play_track("res://Assets/Music/gameover.mp3")
		
	# Animasi UI Game Over (Fade in + Slide up)
	var original_y = content.position.y
	content.position.y += 100
	content.modulate.a = 0.0
	dim_overlay.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(dim_overlay, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(content, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(content, "position:y", original_y, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
