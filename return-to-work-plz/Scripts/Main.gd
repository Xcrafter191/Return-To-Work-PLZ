extends Node2D

## Main — Root scene. Assembles player, camera, HUD, transition overlay,
## and initializes the RoomManager to load the first room.

@onready var camera: Camera2D = $Camera2D
@onready var room_container: Node2D = $RoomContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay/Overlay
@onready var player_scene: PackedScene = preload("res://Scenes/Player.tscn")
@onready var tutorial_scene: PackedScene = preload("res://Scenes/UI/LoopTutorial.tscn")

var player: CharacterBody2D = null

func _ready() -> void:
	# Instance the player (persists across rooms)
	player = player_scene.instantiate()
	
	# Initialize RoomManager with references
	RoomManager.initialize(player, transition_overlay, room_container)
	
	# Load the starting room
	RoomManager.change_room("Slot_F1_Left", "SpawnDefault")
	
	GameManager.loop_restarted.connect(_on_loop_restarted)

func _on_loop_restarted(loop_num: int) -> void:
	if loop_num == 2:
		# Small delay to let room layout transition finish smoothly
		await get_tree().create_timer(0.3).timeout
		var tut = tutorial_scene.instantiate()
		add_child(tut)
