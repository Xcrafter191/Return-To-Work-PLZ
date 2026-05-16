extends Node2D

## InteractableObject — Workstation/desk object that the player can interact with.
## Shows "Press E" prompt when near, starts a timed task on the player.
## Reports completion to GameManager.

@export var task_name: String = "Working..."
@export var task_duration: float = 3.0
@export var task_id: String = ""  ## Must match a GameManager objective id

var player_in_range: bool = false
var current_player: CharacterBody2D = null
var task_completed: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)
	# Listen for loop restart to reset this task
	GameManager.loop_restarted.connect(_on_loop_restarted)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player_in_range and current_player:
		if not current_player.is_working and not task_completed:
			prompt_label.visible = false
			# Scale duration by difficulty
			var scaled_dur = GameManager.get_scaled_duration(task_duration)
			current_player.start_task(scaled_dur)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		current_player = body
		body.set_nearby_workstation(self)
		if not body.is_working and not task_completed:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		body.clear_nearby_workstation(self)
		current_player = null
		prompt_label.visible = false

func on_interact_start() -> void:
	prompt_label.visible = false

func on_interact_complete() -> void:
	task_completed = true
	prompt_label.text = "Done!"
	prompt_label.visible = true
	# Report to GameManager
	if task_id != "":
		GameManager.complete_objective(task_id)
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): prompt_label.visible = false; prompt_label.modulate.a = 1.0)

func _on_loop_restarted(_loop_number: int) -> void:
	# Reset this task for the new loop
	task_completed = false
	prompt_label.text = "Press [E] - " + task_name
	prompt_label.modulate.a = 1.0
	prompt_label.visible = false
