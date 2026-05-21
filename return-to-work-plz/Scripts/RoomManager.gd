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
	"Special_Castle": "res://Scenes/Rooms/Special_Castle.tscn",
	"Special_Beach": "res://Scenes/Rooms/Special_Beach.tscn",
	"Special_Ikea": "res://Scenes/Rooms/Special_Ikea.tscn",
	"Special_Market": "res://Scenes/Rooms/Special_Market.tscn",
	"Special_Spaceship": "res://Scenes/Rooms/Special_Spaceship.tscn"
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
	
	# Spawn special NPCs if assigned for this room
	if GameManager.special_npc_assignments.has(target_room_name):
		for npc_id in GameManager.special_npc_assignments[target_room_name]:
			var npc_scene_path = "res://Scenes/NPCs/%s.tscn" % npc_id
			var npc_scene = load(npc_scene_path)
			if npc_scene:
				var npc_inst = npc_scene.instantiate()
				npc_inst.name = npc_id
				
				var spawn_pos = Vector2(960, 873)
				if npc_id == "Steve":
					spawn_pos = Vector2(1100, 873)
				elif npc_id == "Hans":
					spawn_pos = Vector2(900, 873)
					npc_inst.patrol_left_x = 400.0
					npc_inst.patrol_right_x = 1400.0
				elif npc_id == "Chloe":
					spawn_pos = Vector2(800, 873)
					npc_inst.patrol_left_x = 300.0
					npc_inst.patrol_right_x = 1500.0
					npc_inst.move_speed = 40.0
				
				current_room.add_child(npc_inst)
				npc_inst.global_position = spawn_pos
				print("[RoomManager] Dynamically spawned special NPC %s in room %s at %s" % [npc_id, target_room_name, str(spawn_pos)])
				
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
	# Brief cooldown so RoomExit areas don't immediately re-fire after the player spawns
	await get_tree().create_timer(0.15).timeout

func _configure_room_boundaries() -> void:
	if not current_room: return
	
	var active_slots = active_slots_f1 if current_floor == 1 else active_slots_f2
	var idx = active_slots.find(current_slot)
	
	# Guard: slot tidak ditemukan → paksa wall kedua sisi
	if idx == -1:
		push_warning("RoomManager: slot '%s' not in active_slots, forcing walls." % current_slot)
		_apply_boundary("Left", true, false)
		_apply_boundary("Right", true, false)
		return
	
	# Ada tetangga kiri? → exit. Tidak ada? → wall
	var has_left  = (idx > 0)
	var has_right = (idx < active_slots.size() - 1)
	
	_apply_boundary("Left",  not has_left,  has_left)
	_apply_boundary("Right", not has_right, has_right)

func _apply_boundary(side: String, need_wall: bool, need_exit: bool) -> void:
	var wall   = current_room.get_node_or_null("Wall" + side)
	var exit   = current_room.get_node_or_null("Exit" + side)
	var visual = current_room.get_node_or_null("ExitVisual_" + side)
	var label  = current_room.get_node_or_null("ExitLabel_" + side)
	
	# Handle wall node
	if wall:
		wall.process_mode = Node.PROCESS_MODE_INHERIT if need_wall else Node.PROCESS_MODE_DISABLED
		wall.visible = need_wall
	elif need_wall:
		# Room tidak punya WallLeft/WallRight — spawn dinamis
		_spawn_temp_wall(side)
	
	# Handle exit node
	if exit:
		exit.process_mode = Node.PROCESS_MODE_INHERIT if need_exit else Node.PROCESS_MODE_DISABLED
	elif need_exit:
		# Room doesn't have an exit on this side — spawn a temporary one
		_spawn_temp_exit(side)
	if visual: visual.visible = need_exit
	if label:  label.visible  = need_exit

func _spawn_temp_wall(side: String) -> void:
	# Cegah duplikat kalau dipanggil dua kali
	var existing = current_room.get_node_or_null("TempWall" + side)
	if existing: return
	
	var body = StaticBody2D.new()
	body.name = "TempWall" + side
	body.collision_layer = 2
	body.collision_mask = 0
	
	var shape = CollisionShape2D.new()
	var rect  = RectangleShape2D.new()
	rect.size = Vector2(40, 2000)  # Match wall width from room scenes, tall enough
	shape.shape = rect
	body.add_child(shape)
	current_room.add_child(body)
	
	# Posisi: tempel di tepi kiri atau kanan viewport (match room wall positions)
	if side == "Left":
		body.position = Vector2(-10, 513)
		shape.position = Vector2(-2, 55)
	else:
		body.position = Vector2(1945, 524)
		shape.position = Vector2(-2, 55)
	
	print("[RoomManager] Spawned temp wall on %s for room '%s'" % [side, current_room_name])

func _spawn_temp_exit(side: String) -> void:
	# Cegah duplikat
	var existing = current_room.get_node_or_null("TempExit" + side)
	if existing: return
	
	var exit_area = Area2D.new()
	exit_area.name = "TempExit" + side
	exit_area.collision_layer = 0
	exit_area.collision_mask = 1  # Detect player (layer 1)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(42, 972)  # Match exit collision size from room scenes
	shape.shape = rect
	exit_area.add_child(shape)
	current_room.add_child(exit_area)
	
	# Position at room edge, matching existing exit positions
	var exit_dir: int
	if side == "Left":
		exit_area.position = Vector2(10, 780)
		shape.position = Vector2(0, -290)
		exit_dir = -1
	else:
		exit_area.position = Vector2(1910, 780)
		shape.position = Vector2(0, -290)
		exit_dir = 1
	
	# Connect the body_entered signal to trigger room transition
	exit_area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			if exit_dir == -1:
				go_left()
			else:
				go_right()
	)
	
	print("[RoomManager] Spawned temp exit on %s for room '%s'" % [side, current_room_name])

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

func reset_layout() -> void:
	active_slots_f1 = ["Slot_F1_Left", "Slot_Elevator_F1", "Slot_F1_Right"]
	active_slots_f2 = ["Slot_F2_Left", "Slot_F2_Middle", "Slot_Elevator_F2", "Slot_F2_Right", "Slot_F2_FarRight"]
	current_layout = {
		"Slot_F1_Left":       "Lobby",
		"Slot_Elevator_F1":   "Elevator_F1",
		"Slot_F1_Right":      "Bathroom",
		"Slot_F2_Left":       "Lounge",
		"Slot_F2_Middle":     "Cubicle_Middle",
		"Slot_Elevator_F2":   "Elevator_F2",
		"Slot_F2_Right":      "Meeting",
		"Slot_F2_FarRight":   "Printer"
	}
	current_slot = "Slot_F1_Left"
	current_floor = 1
	print("[RoomManager] Layout reset to default.")
