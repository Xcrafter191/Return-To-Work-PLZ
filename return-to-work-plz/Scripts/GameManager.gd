extends Node

## GameManager — Autoload Singleton
## Tracks the core gameplay loop: objectives, quota, loops, NPC state.

signal objective_completed(task_id: String)
signal all_objectives_completed()
signal loop_restarted(loop_number: int)

# ── Loop state ──
var current_loop: int = 1
var difficulty_modifier: float = 1.0  # Scales task duration

# ── Objective definitions ──
# Each objective: { "id": String, "label": String, "room": String, "completed": bool }
var objectives: Array = []

# ── NPC position persistence ──
# { "RoomName": { "NPCNodeName": Vector2 } }
var npc_positions: Dictionary = {}

func _ready() -> void:
	_build_objectives()

## Build the fixed 4-task list (will be 10 in final)
func _build_objectives() -> void:
	objectives = [
		{ "id": "coffee", "label": "Make coffee", "room": "Lounge", "completed": false },
		{ "id": "type_report", "label": "Type report", "room": "Cubicle", "completed": false },
		{ "id": "print_paper", "label": "Print documents", "room": "Printer", "completed": false },
		{ "id": "give_paper", "label": "Give paper to Manager", "room": "Meeting", "completed": false },
	]

## Called by InteractableObject when a task finishes
func complete_objective(task_id: String) -> void:
	for obj in objectives:
		if obj["id"] == task_id and not obj["completed"]:
			obj["completed"] = true
			objective_completed.emit(task_id)
			print("[GameManager] Objective completed: %s" % task_id)
			if _all_completed():
				all_objectives_completed.emit()
				print("[GameManager] All objectives done! Clock out to finish the loop.")
			return

func _all_completed() -> bool:
	for obj in objectives:
		if not obj["completed"]:
			return false
	return true

func get_completed_count() -> int:
	var count: int = 0
	for obj in objectives:
		if obj["completed"]:
			count += 1
	return count

func get_total_count() -> int:
	return objectives.size()

## Check if all objectives are done (for clock-out gate)
func can_clock_out() -> bool:
	return _all_completed()

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
