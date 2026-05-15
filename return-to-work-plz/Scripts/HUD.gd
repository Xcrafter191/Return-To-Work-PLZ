extends CanvasLayer

## HUD — Basic UI overlay showing room name.

@onready var room_label: Label = $RoomLabel

func _ready() -> void:
	RoomManager.room_changed.connect(_on_room_changed)

func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name
