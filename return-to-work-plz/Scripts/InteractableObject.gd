extends Node2D

## InteractableObject — Workstation/desk object that the player can interact with.
## Shows "Press E" prompt when near, starts a timed task on the player.

@export var task_name: String = "Working..."
@export var task_duration: float = 3.0

var player_in_range: bool = false
var current_player: CharacterBody2D = null
var task_completed: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player_in_range and current_player:
		if not current_player.is_working and not task_completed:
			prompt_label.visible = false
			current_player.start_task(task_duration)

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
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(prompt_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): prompt_label.visible = false; prompt_label.modulate.a = 1.0)
