extends Area2D

## ClockOut — Placed at the far-left wall of Lobby.
## Handles both "Clock In" (first task) and "Clock Out" (last task).
## Player must press E to interact — no auto-trigger.

var player_in_range: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameManager.current_task_changed.connect(_on_task_changed)
	GameManager.loop_restarted.connect(_on_loop_restarted)

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return
	
	var current_task = GameManager.get_current_task_id()
	
	if current_task == "clock_in":
		_do_clock_in()
	elif current_task == "clock_out":
		_do_clock_out()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false

func _on_task_changed(_idx: int) -> void:
	if player_in_range:
		_update_prompt()

func _on_loop_restarted(_loop: int) -> void:
	prompt_label.visible = false

func _update_prompt() -> void:
	var current_task = GameManager.get_current_task_id()
	if current_task == "clock_in":
		prompt_label.text = "Press [E] - Clock In"
		prompt_label.visible = true
	elif current_task == "clock_out":
		prompt_label.text = "Press [E] - Clock Out"
		prompt_label.visible = true
	else:
		prompt_label.visible = false

func _do_clock_in() -> void:
	prompt_label.visible = false
	GameManager.complete_objective("clock_in")
	await get_tree().create_timer(0.5).timeout
	prompt_label.visible = false

func _do_clock_out() -> void:
	prompt_label.visible = false
	
	# Disable player movement
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		p.velocity.x = 0
		if p.has_method("_update_animation"):
			p._update_animation(0.0)
		p.set_physics_process(false)
		p.set_process_input(false)
	
	await get_tree().create_timer(0.5).timeout
	
	# Show loop transition overlay with loop number
	var next_loop = GameManager.current_loop + 1
	var overlay = _create_loop_overlay(next_loop)
	
	await get_tree().create_timer(2.5).timeout
	
	# Proceed with clock out
	GameManager.clock_out()
	RoomManager.change_room("Slot_F1_Left", "SpawnDefault", true)
	prompt_label.visible = false
	
	# Fade out overlay
	if is_instance_valid(overlay):
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			if is_instance_valid(overlay):
				overlay.queue_free()
		)
	
	if players.size() > 0:
		var p = players[0]
		p.set_physics_process(true)
		p.set_process_input(true)

func _create_loop_overlay(loop_num: int) -> CanvasLayer:
	var canvas = CanvasLayer.new()
	canvas.layer = 50
	
	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)
	
	# Loop number label
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = -50
	label.offset_bottom = 50
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "LOOP %d" % loop_num
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate.a = 0.0
	var font = load("res://Assets/Font/Pixeled.ttf")
	if font:
		label.add_theme_font_override("font", font)
	canvas.add_child(label)
	
	get_tree().current_scene.add_child(canvas)
	
	# Animate: fade in background and label
	var tween = create_tween()
	tween.tween_property(bg, "color:a", 0.9, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.6)
	
	return canvas
