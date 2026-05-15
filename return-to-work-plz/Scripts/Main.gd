extends Node2D

## Main — Root scene. Assembles player, camera, HUD, transition overlay,
## and initializes the RoomManager to load the first room.

@onready var camera: Camera2D = $Camera2D
@onready var room_container: Node2D = $RoomContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay/Overlay
@onready var player_scene: PackedScene = preload("res://Scenes/Player.tscn")

var player: CharacterBody2D = null

func _ready() -> void:
	# Instance the player (persists across rooms)
	player = player_scene.instantiate()
	
	# Initialize RoomManager with references
	RoomManager.initialize(player, transition_overlay, room_container)
	
	# Load the starting room
	RoomManager.change_room("Lobby", "SpawnDefault")
