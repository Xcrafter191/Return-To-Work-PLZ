extends Area2D

## RoomExit — Placed at room edges to trigger room transitions.
## When the player enters this area, it tells RoomManager to switch rooms.

@export var target_room: String = ""  ## Room name key in RoomManager.room_registry
@export var target_spawn: String = "SpawnDefault"  ## Marker2D name in target room

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		if target_room != "":
			RoomManager.change_room(target_room, target_spawn)
