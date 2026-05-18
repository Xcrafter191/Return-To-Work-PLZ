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
var room_registry: Dictionary = {
	"Lobby": "res://Scenes/Rooms/Lobby.tscn",
	"Lounge": "res://Scenes/Rooms/Lounge.tscn",
	"Elevator_F1": "res://Scenes/Rooms/Elevator_F1.tscn",
	"Elevator_F2": "res://Scenes/Rooms/Elevator_F2.tscn",
	"Meeting": "res://Scenes/Rooms/Meeting.tscn",
	"Printer": "res://Scenes/Rooms/Printer.tscn",
	"Bathroom": "res://Scenes/Rooms/Bathroom.tscn",
	"Cubicle_Left": "res://Scenes/Rooms/Cubicle_Left.tscn",
	"Cubicle_Middle": "res://Scenes/Rooms/Cubicle_Middle.tscn",
	"Cubicle_Right": "res://Scenes/Rooms/Cubicle_Right.tscn",
}

var active_slots_f1: Array = ["Slot_F1_Left", "Slot_Elevator_F1", "Slot_F1_Right"]
var active_slots_f2: Array = ["Slot_F2_Left", "Slot_F2_Middle", "Slot_Elevator_F2", "Slot_F2_Right", "Slot_F2_FarRight"]

var current_layout: Dictionary = {
	"Slot_F1_Left": "Lobby",
	"Slot_Elevator_F1": "Elevator_F1",
	"Slot_F1_Right": "Bathroom",
	"Slot_F2_Left": "Lounge",
	"Slot_F2_Middle": "Cubicle_Middle",
	"Slot_Elevator_F2": "Elevator_F2",
	"Slot_F2_Right": "Meeting",
	"Slot_F2_FarRight": "Printer"
}

var current_slot: String = "Slot_F1_Left"
var current_floor: int = 1

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

## Change to a new room with fade transition using SLOT NAME.
func change_room(slot_name: String, spawn_point_name: String = "SpawnDefault", force_reload: bool = false) -> void:
	if is_transitioning:
		return
	if slot_name == current_slot and not force_reload and current_room != null:
		return
	if slot_name not in current_layout:
		push_error("RoomManager: Slot '%s' not found in layout!" % slot_name)
		return
	
	var target_room_name = current_layout[slot_name]
	
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
	var room_scene: PackedScene = load(room_registry[target_room_name])
	current_room = room_scene.instantiate()
	room_container.add_child(current_room)
	current_room_name = target_room_name
	current_slot = slot_name
	
	if current_slot in active_slots_f1:
		current_floor = 1
	elif current_slot in active_slots_f2:
		current_floor = 2
	
	# Configure Walls vs Exits dynamically
	_configure_room_boundaries()
	
	# Restore NPC positions
	GameManager.restore_npc_positions(target_room_name, current_room)
	
	# Place player at spawn point
	if player:
		current_room.add_child(player)
		var spawn = current_room.get_node_or_null(spawn_point_name)
		if spawn and spawn is Marker2D:
			player.global_position = spawn.global_position
		else:
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

func _configure_room_boundaries() -> void:
	if not current_room: return
	
	var active_slots = active_slots_f1 if current_floor == 1 else active_slots_f2
	var idx = active_slots.find(current_slot)
	
	var is_far_left = (idx == 0)
	var is_far_right = (idx == active_slots.size() - 1)
	
	var wall_left = current_room.get_node_or_null("WallLeft")
	var exit_left = current_room.get_node_or_null("ExitLeft")
	var visual_left = current_room.get_node_or_null("ExitVisual_Left")
	var label_left = current_room.get_node_or_null("ExitLabel_Left")
	
	if wall_left: wall_left.process_mode = Node.PROCESS_MODE_INHERIT if is_far_left else Node.PROCESS_MODE_DISABLED
	if wall_left: wall_left.visible = is_far_left
	if exit_left: exit_left.process_mode = Node.PROCESS_MODE_DISABLED if is_far_left else Node.PROCESS_MODE_INHERIT
	if visual_left: visual_left.visible = not is_far_left
	if label_left: label_left.visible = not is_far_left
	
	var wall_right = current_room.get_node_or_null("WallRight")
	var exit_right = current_room.get_node_or_null("ExitRight")
	var visual_right = current_room.get_node_or_null("ExitVisual_Right")
	var label_right = current_room.get_node_or_null("ExitLabel_Right")
	
	if wall_right: wall_right.process_mode = Node.PROCESS_MODE_INHERIT if is_far_right else Node.PROCESS_MODE_DISABLED
	if wall_right: wall_right.visible = is_far_right
	if exit_right: exit_right.process_mode = Node.PROCESS_MODE_DISABLED if is_far_right else Node.PROCESS_MODE_INHERIT
	if visual_right: visual_right.visible = not is_far_right
	if label_right: label_right.visible = not is_far_right

func go_left() -> void:
	var active_slots = active_slots_f1 if current_floor == 1 else active_slots_f2
	var idx = active_slots.find(current_slot)
	if idx > 0:
		change_room(active_slots[idx - 1], "SpawnRight")

func go_right() -> void:
	var active_slots = active_slots_f1 if current_floor == 1 else active_slots_f2
	var idx = active_slots.find(current_slot)
	if idx >= 0 and idx < active_slots.size() - 1:
		change_room(active_slots[idx + 1], "SpawnLeft")

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
