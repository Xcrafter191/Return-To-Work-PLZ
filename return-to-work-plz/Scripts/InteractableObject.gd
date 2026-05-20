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
@onready var task_sfx: AudioStreamPlayer2D = $TaskSFX

var player_in_range: bool = false
var current_player: CharacterBody2D = null
var task_completed: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	# Update prompt when task changes (in case player is already standing here)
	GameManager.current_task_changed.connect(_on_task_changed)

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
		_update_prompt()

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
	if player_in_range:
		_update_prompt()

func _update_prompt() -> void:
	if _is_available():
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
		_start_glow()

var _glow_tween: Tween = null
func _start_glow() -> void:
	if _glow_tween and _glow_tween.is_valid(): return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(self, "modulate", Color(1.4, 1.3, 0.2), 0.4)
	_glow_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.4)

func _stop_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	modulate = Color(1.0, 1.0, 1.0)

func on_interact_start() -> void:
	prompt_label.visible = false
	if task_sfx:
		task_sfx.play()

func on_interact_complete() -> void:
	task_completed = true
	if task_sfx:
		task_sfx.stop()
	
	# Time Erase: task finishes but doesn't count!
	if InconvenienceManager.is_time_erased:
		prompt_label.text = "[ERASED]"
		prompt_label.visible = true
		task_completed = false  # Let them redo it
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func(): prompt_label.visible = false; prompt_label.modulate.a = 1.0)
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
