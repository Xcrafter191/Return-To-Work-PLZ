extends Node

## GameManager — Autoload Singleton
## Tracks the core gameplay loop: objectives, quota, loops, NPC state.
## Tasks are SEQUENTIAL — must be completed in order.

signal objective_completed(task_id: String)
signal all_objectives_completed()
signal loop_restarted(loop_number: int)
signal current_task_changed(task_index: int)

# ── Loop state ──
var current_loop: int = 1
var difficulty_modifier: float = 1.0  # Scales task duration
var current_task_index: int = 0  # Which task is currently active (sequential)

# ── Objective definitions ──
# Each objective: { "id": String, "label": String, "room": String, "completed": bool }
var objectives: Array = []

# ── NPC position persistence ──
# { "RoomName": { "NPCNodeName": Vector2 } }
var npc_positions: Dictionary = {}

func _ready() -> void:
	_build_objectives()

## Build the fixed 4-task list (will be 10 in final)
## ORDER MATTERS — tasks must be done sequentially
func _build_objectives() -> void:
	objectives = [
		{ "id": "coffee", "label": "Make coffee", "room": "Lounge", "completed": false },
		{ "id": "type_report", "label": "Type report", "room": "Cubicle", "completed": false },
		{ "id": "print_paper", "label": "Print documents", "room": "Printer", "completed": false },
		{ "id": "give_paper", "label": "Give paper to Manager", "room": "Meeting", "completed": false },
	]
	current_task_index = 0

## Get the currently active task id (the one the player should do next)
func get_current_task_id() -> String:
	if current_task_index < objectives.size():
		return objectives[current_task_index]["id"]
	return ""

## Check if a task_id is the currently active task
func is_task_active(task_id: String) -> bool:
	return task_id == get_current_task_id()

## Called by InteractableObject when a task finishes
func complete_objective(task_id: String) -> void:
	if task_id != get_current_task_id():
		return  # Can't complete out-of-order tasks
	var obj = objectives[current_task_index]
	obj["completed"] = true
	current_task_index += 1
	objective_completed.emit(task_id)
	print("[GameManager] Objective completed: %s (%d/%d)" % [task_id, current_task_index, objectives.size()])
	
	if current_task_index >= objectives.size():
		all_objectives_completed.emit()
		print("[GameManager] All objectives done! Clock out to finish the loop.")
	else:
		current_task_changed.emit(current_task_index)

func get_completed_count() -> int:
	return current_task_index

func get_total_count() -> int:
	return objectives.size()

## Check if all objectives are done (for clock-out gate)
func can_clock_out() -> bool:
	return current_task_index >= objectives.size()

## Called when player clocks out at Lobby wall
func clock_out() -> void:
	current_loop += 1
	difficulty_modifier += 0.15  # Each loop: tasks take ~15% longer
	_build_objectives()  # Reset all tasks
	npc_positions.clear()  # Reset NPC positions on new loop
	loop_restarted.emit(current_loop)
	print("[GameManager] === LOOP %d START === (difficulty: %.2f)" % [current_loop, difficulty_modifier])

## Get the scaled task duration
func get_scaled_duration(base_duration: float) -> float:
	return base_duration * difficulty_modifier

# ── NPC Position Persistence ──

## Save a room's moving NPC positions before unloading
func save_npc_positions(room_name: String, room_node: Node2D) -> void:
	var positions: Dictionary = {}
	for child in room_node.get_children():
		if child is CharacterBody2D and child.has_method("_physics_process"):
			# Only save NPCs, not the player
			if not child.is_in_group("player"):
				positions[child.name] = child.global_position
	if positions.size() > 0:
		npc_positions[room_name] = positions

## Restore NPC positions after loading a room
func restore_npc_positions(room_name: String, room_node: Node2D) -> void:
	if room_name not in npc_positions:
		return
	var positions: Dictionary = npc_positions[room_name]
	for child in room_node.get_children():
		if child.name in positions:
			child.global_position = positions[child.name]
