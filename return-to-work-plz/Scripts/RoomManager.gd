extends Node

## RoomManager — Autoload Singleton
## Manages room transitions with fade effects.

signal room_changed(room_name: String)

var current_room: Node2D = null
var current_room_name: String = ""
var player: CharacterBody2D = null
var transition_overlay: ColorRect = null
var is_transitioning: bool = false

const FADE_DURATION: float = 0.4

# Room registry — maps room names to scene paths.
# Add new rooms here as they are created.
var room_registry: Dictionary = {
	"Lobby": "res://Scenes/Rooms/Lobby.tscn",
	"Cubicle": "res://Scenes/Rooms/Cubicle.tscn",
	"Lounge": "res://Scenes/Rooms/Lounge.tscn",
	"Elevator_F1": "res://Scenes/Rooms/Elevator_F1.tscn",
	"Elevator_F2": "res://Scenes/Rooms/Elevator_F2.tscn",
	"Meeting": "res://Scenes/Rooms/Meeting.tscn",
	"Printer": "res://Scenes/Rooms/Printer.tscn",
	"Bathroom": "res://Scenes/Rooms/Bathroom.tscn",
}

func _ready() -> void:
	pass

## Call this from Main.gd to set up references.
func initialize(p_player: CharacterBody2D, p_overlay: ColorRect, room_container: Node2D) -> void:
	player = p_player
	transition_overlay = p_overlay
	# Ensure overlay starts fully transparent
	transition_overlay.modulate.a = 0.0
	# Store room container reference
	set_meta("room_container", room_container)

## Change to a new room with fade transition.
## room_name: key in room_registry
## spawn_point_name: name of the Marker2D to place the player at
func change_room(room_name: String, spawn_point_name: String = "SpawnDefault") -> void:
	if is_transitioning:
		return
	if room_name not in room_registry:
		push_error("RoomManager: Room '%s' not found in registry!" % room_name)
		return
	
	is_transitioning = true
	
	# Disable player input during transition
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
	
	# Fade out
	await _fade_out()
	
	# Unload current room
	var room_container: Node2D = get_meta("room_container")
	if current_room:
		# Save NPC positions before unloading
		GameManager.save_npc_positions(current_room_name, current_room)
		# Remove player from current room before freeing
		if player and player.get_parent() == current_room:
			current_room.remove_child(player)
		current_room.queue_free()
		current_room = null
	
	# Load new room
	var room_scene: PackedScene = load(room_registry[room_name])
	current_room = room_scene.instantiate()
	room_container.add_child(current_room)
	current_room_name = room_name
	
	# Restore NPC positions
	GameManager.restore_npc_positions(room_name, current_room)
	
	# Place player at spawn point
	if player:
		current_room.add_child(player)
		var spawn = current_room.get_node_or_null(spawn_point_name)
		if spawn and spawn is Marker2D:
			player.global_position = spawn.global_position
		else:
			# Fallback: try "SpawnDefault"
			var fallback = current_room.get_node_or_null("SpawnDefault")
			if fallback and fallback is Marker2D:
				player.global_position = fallback.global_position
			else:
				player.global_position = Vector2(200, 500)
	
	# Update camera to room center
	_update_camera()
	
	# Fade in
	await _fade_in()
	
	# Re-enable player input
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)
	
	is_transitioning = false
	room_changed.emit(current_room_name)

func _fade_out() -> void:
	if not transition_overlay:
		return
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

func _fade_in() -> void:
	if not transition_overlay:
		return
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

func _update_camera() -> void:
	# Fixed camera — center on the room
	var camera = get_viewport().get_camera_2d()
	if camera and current_room:
		var room_center = current_room.get_node_or_null("RoomCenter")
		if room_center and room_center is Marker2D:
			camera.global_position = room_center.global_position
		else:
			# Default to center of viewport
			camera.global_position = Vector2(960, 540)
