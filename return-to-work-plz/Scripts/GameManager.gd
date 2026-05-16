extends Node

## GameManager — Autoload Singleton
## Tracks the core gameplay loop: objectives, quota, loops, NPC state.
## Tasks are SEQUENTIAL — must be completed in order.

signal objective_completed(task_id: String)
signal all_objectives_completed()
signal loop_restarted(loop_number: int)
signal current_task_changed(task_index: int)
signal npc_talk_updated(count: int)
signal morale_changed(value: float)
signal productivity_changed(value: float)

# ── Player Stats (Dummy values for UI) ──
var morale: float = 100.0
var productivity: float = 50.0

# ── Loop state ──
var current_loop: int = 1
var difficulty_modifier: float = 1.0  # Scales task duration
var current_task_index: int = 0  # Which task is currently active (sequential)

# ── Objective definitions ──
var objectives: Array = []

# ── NPC talk tracking ──
var talked_npcs: Dictionary = {}  # { npc_name: true } — acts as a Set
const REQUIRED_NPC_TALKS: int = 5

# ── NPC position persistence ──
var npc_positions: Dictionary = {}

func _ready() -> void:
	_build_objectives()
	# Dummy init so UI gets the starting values
	call_deferred("emit_signal", "morale_changed", morale)
	call_deferred("emit_signal", "productivity_changed", productivity)

## Stat Helpers
func set_morale(val: float) -> void:
	morale = clamp(val, 0.0, 100.0)
	morale_changed.emit(morale)

func set_productivity(val: float) -> void:
	productivity = clamp(val, 0.0, 100.0)
	productivity_changed.emit(productivity)

## Build the full 10-task list. ORDER MATTERS — tasks are sequential.
func _build_objectives() -> void:
	objectives = [
		{ "id": "clock_in", "label": "Clock in", "room": "Lobby", "completed": false },
		{ "id": "coffee", "label": "Make coffee", "room": "Lounge", "completed": false },
		{ "id": "type_report", "label": "Type report", "room": "Cubicle", "completed": false, "skippable": true },
		{ "id": "reply_email", "label": "Reply email", "room": "Cubicle", "completed": false, "skippable": true },
		{ "id": "print_paper", "label": "Print documents", "room": "Printer", "completed": false },
		{ "id": "give_paper", "label": "Give paper to Manager", "room": "Meeting", "completed": false },
		{ "id": "fix_spreadsheet", "label": "Fix spreadsheet", "room": "Cubicle", "completed": false, "skippable": true },
		{ "id": "present_manager", "label": "Present to Manager", "room": "Meeting", "completed": false },
		{ "id": "talk_npcs", "label": "Talk to 5 coworkers", "room": "Any", "completed": false },
		{ "id": "clock_out", "label": "Clock out", "room": "Lobby", "completed": false },
	]
	current_task_index = 0
	talked_npcs.clear()

## Get the currently active task id
func get_current_task_id() -> String:
	if current_task_index < objectives.size():
		return objectives[current_task_index]["id"]
	return ""

## Check if a task_id is the currently active task
func is_task_active(task_id: String) -> bool:
	return task_id == get_current_task_id()

## Check if the current task is skippable
func is_current_task_skippable() -> bool:
	if current_task_index < objectives.size():
		return objectives[current_task_index].get("skippable", false)
	return false

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
		print("[GameManager] All objectives done!")
	else:
		current_task_changed.emit(current_task_index)
		# Check if the NEW current task can auto-complete
		_check_auto_complete()

## Check if the current task can be auto-completed (e.g., talk_npcs already met)
func _check_auto_complete() -> void:
	if get_current_task_id() == "talk_npcs" and talked_npcs.size() >= REQUIRED_NPC_TALKS:
		complete_objective("talk_npcs")

# ── NPC Talk Tracking ──

## Called by NPC scripts when player enters their interaction area
func register_npc_talk(npc_name: String) -> void:
	if npc_name not in talked_npcs:
		talked_npcs[npc_name] = true
		print("[GameManager] Talked to: %s (%d/%d unique NPCs)" % [npc_name, talked_npcs.size(), REQUIRED_NPC_TALKS])
		npc_talk_updated.emit(talked_npcs.size())
		# If the talk_npcs task is active and we've met the quota, auto-complete
		if get_current_task_id() == "talk_npcs" and talked_npcs.size() >= REQUIRED_NPC_TALKS:
			complete_objective("talk_npcs")

func get_talked_count() -> int:
	return talked_npcs.size()

# ── Utility ──

func get_completed_count() -> int:
	return current_task_index

func get_total_count() -> int:
	return objectives.size()

func can_clock_out() -> bool:
	return get_current_task_id() == "clock_out"

## Called when player clocks out at Lobby wall
func clock_out() -> void:
	# Complete the clock_out objective first
	complete_objective("clock_out")
	current_loop += 1
	difficulty_modifier += 0.15
	_build_objectives()
	npc_positions.clear()
	loop_restarted.emit(current_loop)
	print("[GameManager] === LOOP %d START === (difficulty: %.2f)" % [current_loop, difficulty_modifier])

## Get the scaled task duration
func get_scaled_duration(base_duration: float) -> float:
	return base_duration * difficulty_modifier

# ── NPC Position Persistence ──

func save_npc_positions(room_name: String, room_node: Node2D) -> void:
	var positions: Dictionary = {}
	for child in room_node.get_children():
		if child is CharacterBody2D and child.has_method("_physics_process"):
			if not child.is_in_group("player"):
				positions[child.name] = child.global_position
	if positions.size() > 0:
		npc_positions[room_name] = positions

func restore_npc_positions(room_name: String, room_node: Node2D) -> void:
	if room_name not in npc_positions:
		return
	var positions: Dictionary = npc_positions[room_name]
	for child in room_node.get_children():
		if child.name in positions:
			child.global_position = positions[child.name]
