extends Node2D

## ElevatorDoor — Interactable area that teleports player between elevator floors.
## Player presses E near the door to go to the other floor.

@export var target_slot: String = "Slot_Elevator_F2"
@export var target_spawn: String = "SpawnDefault"

var player_in_range: bool = false

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player_in_range:
		RoomManager.change_room(target_slot, target_spawn)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
