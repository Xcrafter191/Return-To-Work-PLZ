extends Area2D

## ClockOut — Placed at the far-left wall of Lobby.
## When player walks into this area AND all objectives are complete,
## triggers the loop restart.

var player_in_range: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Listen for all objectives completed to show prompt if player already here
	GameManager.all_objectives_completed.connect(_check_show_prompt)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if GameManager.can_clock_out():
			_do_clock_out()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false

func _check_show_prompt() -> void:
	if player_in_range:
		_do_clock_out()

func _do_clock_out() -> void:
	# Show brief "Clocking out..." feedback then restart loop
	prompt_label.visible = true
	prompt_label.text = "Clocking out..."
	
	# Disable player movement briefly
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set_physics_process(false)
		players[0].set_process_input(false)
	
	# Short delay then restart
	await get_tree().create_timer(1.0).timeout
	GameManager.clock_out()
	RoomManager.change_room("Lobby", "SpawnDefault")
	
	# Re-enable player (RoomManager handles this after transition)
	prompt_label.visible = false
