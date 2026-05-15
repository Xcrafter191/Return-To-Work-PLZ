extends CanvasLayer

## HUD — Basic UI overlay showing room name and interaction prompt.

@onready var room_label: Label = $RoomLabel
@onready var interact_prompt: Label = $InteractPrompt

func _ready() -> void:
	RoomManager.room_changed.connect(_on_room_changed)
	interact_prompt.visible = false

func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name

func show_interact_prompt() -> void:
	interact_prompt.visible = true

func hide_interact_prompt() -> void:
	interact_prompt.visible = false
