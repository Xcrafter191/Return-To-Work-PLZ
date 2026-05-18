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
		prompt_label.text = "Press [E] — Clock In"
		prompt_label.visible = true
	elif current_task == "clock_out":
		prompt_label.text = "Press [E] — Clock Out"
		prompt_label.visible = true
	else:
		prompt_label.visible = false

func _do_clock_in() -> void:
	prompt_label.text = "Clocking in..."
	prompt_label.visible = true
	GameManager.complete_objective("clock_in")
	await get_tree().create_timer(0.5).timeout
	prompt_label.visible = false

func _do_clock_out() -> void:
	prompt_label.text = "Clocking out..."
	prompt_label.visible = true
	
	# Disable player movement
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		p.velocity.x = 0
		if p.has_method("_update_animation"):
			p._update_animation(0.0)
		p.set_physics_process(false)
		p.set_process_input(false)
	
	await get_tree().create_timer(1.0).timeout
	GameManager.clock_out()
	RoomManager.change_room("Slot_F1_Left", "SpawnDefault", true)
	prompt_label.visible = false
	
	if players.size() > 0:
		var p = players[0]
		p.set_physics_process(true)
		p.set_process_input(true)
