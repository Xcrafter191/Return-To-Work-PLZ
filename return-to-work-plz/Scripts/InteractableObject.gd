extends Node2D

## InteractableObject — Workstation/desk object that the player can interact with.
## Shows "Press E" prompt when near AND this task is the current active task.
## Skippable tasks also show "Press Q to skip".
## Reports completion to GameManager.

@export var task_name: String = "Working..."
@export var task_duration: float = 3.0
@export var task_id: String = ""  ## Must match a GameManager objective id
@export var on_complete_npc_path: NodePath = ""  ## Optional: NPC to change dialogue on completion
@export var on_complete_npc_dialogue: String = ""  ## New dialogue for that NPC
var task_sfx: AudioStreamPlayer2D = null

var player_in_range: bool = false
var current_player: CharacterBody2D = null
var task_completed: bool = false

var prompt_label: Label = null

var _highlight_rect: ColorRect = null

func _ready() -> void:
	task_sfx = get_node_or_null("TaskSFX")
	prompt_label = get_node_or_null("PromptLabel")
	if prompt_label == null:
		# Create a fallback PromptLabel so the rest of the script doesn't crash
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.position = Vector2(0, -60)
		add_child(prompt_label)
	prompt_label.visible = false
	var detection_area = get_node_or_null("DetectionArea")
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	# Update prompt and glow when task changes
	GameManager.current_task_changed.connect(_on_task_changed)
	GameManager.all_objectives_completed.connect(_on_all_completed)
	_setup_highlight_rect()
	# Add to group so InconvenienceManager can find us for Time Reverse reset
	add_to_group("interactables")
	# Initial glow state check (in case this workstation is already the active task)
	call_deferred("_update_glow_state")

func _setup_highlight_rect() -> void:
	var area = get_node_or_null("DetectionArea")
	if not area: return
	var col_shape = area.get_node_or_null("CollisionShape2D")
	if not col_shape or not col_shape.shape is RectangleShape2D: return
	
	var rect_shape: RectangleShape2D = col_shape.shape
	var size = rect_shape.size
	var pos = col_shape.position + area.position
	
	_highlight_rect = ColorRect.new()
	_highlight_rect.size = size
	_highlight_rect.position = pos - (size / 2.0)
	_highlight_rect.color = Color(1.0, 0.95, 0.0, 0.0)
	_highlight_rect.visible = false
	_highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(_highlight_rect)
	move_child(_highlight_rect, 0)

func _is_available() -> bool:
	if task_completed or task_id == "": return false
	if InconvenienceManager.is_task_deception: return true
	return GameManager.is_task_active(task_id)

func _is_skippable() -> bool:
	return _is_available() and GameManager.is_current_task_skippable()

func _input(event: InputEvent) -> void:
	if not player_in_range or not current_player:
		return
	
	# E key: do the task
	if event.is_action_pressed("interact"):
		if not current_player.is_working and _is_available():
			if InconvenienceManager.is_time_stopped:
				prompt_label.text = "[TIME FROZEN]"
				return
			prompt_label.visible = false
			on_interact_start()
			var scaled_dur = GameManager.get_scaled_duration(task_duration)
			current_player.start_task(scaled_dur)
	
	# Q key: skip the task (only for skippable tasks)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if not current_player.is_working and _is_skippable():
			_skip_task()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		current_player = body
		body.set_nearby_workstation(self)
		_update_prompt_visibility()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		body.clear_nearby_workstation(self)
		current_player = null
		prompt_label.visible = false

func _on_task_changed(_idx: int) -> void:
	# If our task just became active again (e.g. from Time Reverse), reset completion
	if task_completed and task_id != "" and GameManager.is_task_active(task_id):
		task_completed = false
		prompt_label.modulate.a = 1.0
	# Update glow based on whether this workstation is now the active task
	_update_glow_state()
	if player_in_range:
		_update_prompt_visibility()

func _update_prompt_visibility() -> void:
	if _is_available():
		# Time Stop: block interaction immediately, show frozen prompt without E press
		if InconvenienceManager.is_time_stopped:
			prompt_label.text = "[TIME FROZEN]"
			prompt_label.visible = true
			return
		
		var display_name = task_name
		if InconvenienceManager.is_task_deception:
			var fake_names = ["Typing report...", "Fixing spreadsheet...", "Replying email...", "Print documents", "Present to Manager"]
			display_name = fake_names.pick_random()
			
		if _is_skippable():
			prompt_label.text = "Press [E] - %s  |  [Q] Skip" % display_name
		else:
			prompt_label.text = "Press [E] - %s" % display_name
		prompt_label.visible = true
		_start_glow()
	else:
		prompt_label.visible = false
		_stop_glow()

func _update_glow_state() -> void:
	if task_id == "" or task_completed:
		_stop_glow()
		return
	# Do NOT glow during time_stop — player cannot interact anyway
	if InconvenienceManager.is_time_stopped:
		_stop_glow()
		return
	if task_id == GameManager.get_current_task_id():
		_start_glow()
	else:
		_stop_glow()

func _on_all_completed() -> void:
	_stop_glow()

var _glow_tween: Tween = null
func _start_glow() -> void:
	if not _highlight_rect: return
	_highlight_rect.visible = true
	if _glow_tween and _glow_tween.is_valid(): return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_highlight_rect, "color:a", 0.45, 0.5)
	_glow_tween.tween_property(_highlight_rect, "color:a", 0.05, 0.5)

func _stop_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	if _highlight_rect:
		_highlight_rect.visible = false
		_highlight_rect.color.a = 0.0

func on_interact_start() -> void:
	prompt_label.visible = false
	if task_sfx:
		task_sfx.play()

func on_interact_complete() -> void:
	task_completed = true
	_stop_glow()
	if task_sfx:
		task_sfx.stop()
	
	# Time Erase: task finishes but doesn't count!
	# Guard checks both the flag AND that the attack sequence has finished (no race condition)
	if InconvenienceManager.is_time_erased:
		print("[InteractableObject] DEBUG time_erase: task '%s' completed but ERASED (is_time_erased=%s, attack_active=%s)" % [task_id, str(InconvenienceManager.is_time_erased), str(AttackSequenceManager.is_attacking)])
		prompt_label.text = "[ERASED]"
		prompt_label.visible = true
		task_completed = false  # Reset so player can retry
		_update_glow_state()  # Re-enable glow for retry
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func():
			prompt_label.visible = false
			prompt_label.modulate.a = 1.0
			if player_in_range:
				_update_prompt_visibility()
		)
		return
	
	prompt_label.text = "Done!"
	prompt_label.visible = true
	if task_id != "":
		if InconvenienceManager.is_task_deception and not GameManager.is_task_active(task_id):
			print("[InteractableObject] Wrong task completed during deception! Punishing player.")
			GameManager.punish_wrong_task()
			return
		GameManager.complete_objective(task_id)
	# Change NPC dialogue if configured
	if not on_complete_npc_path.is_empty() and on_complete_npc_dialogue != "":
		var npc = get_node_or_null(on_complete_npc_path)
		if npc and "dialogue_text" in npc:
			npc.dialogue_text = on_complete_npc_dialogue
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): prompt_label.visible = false; prompt_label.modulate.a = 1.0)

func _skip_task() -> void:
	task_completed = true
	if task_sfx:
		task_sfx.stop()
	
	# Time Erase: skip also doesn't count during erase window
	if InconvenienceManager.is_time_erased:
		print("[InteractableObject] DEBUG time_erase: task '%s' skipped but ERASED (is_time_erased=true)" % task_id)
		prompt_label.text = "[ERASED]"
		prompt_label.visible = true
		task_completed = false  # Reset so player can retry
		_update_glow_state()
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func():
			prompt_label.visible = false
			prompt_label.modulate.a = 1.0
			if player_in_range:
				_update_prompt_visibility()
		)
		return
	
	prompt_label.text = "Skipped"
	prompt_label.visible = true
	if task_id != "":
		GameManager.complete_objective(task_id)
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(prompt_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): prompt_label.visible = false; prompt_label.modulate.a = 1.0)

func _on_loop_restarted(_loop_number: int) -> void:
	task_completed = false
	prompt_label.text = "Press [E] - " + task_name
	prompt_label.modulate.a = 1.0
	prompt_label.visible = false
	_update_glow_state()
