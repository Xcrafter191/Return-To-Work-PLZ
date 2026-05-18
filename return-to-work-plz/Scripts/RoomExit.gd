extends Area2D

## RoomExit — Placed at room edges to trigger room transitions.
## When the player enters this area, it tells RoomManager to switch rooms.

@export var exit_direction: int = 1 # 1 for Right, -1 for Left

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if exit_direction == -1:
			RoomManager.go_left()
		else:
			RoomManager.go_right()
