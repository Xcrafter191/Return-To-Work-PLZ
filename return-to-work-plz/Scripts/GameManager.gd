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
var productivity: float = 100.0

# ── Deadline State ──
var task_deadline_time: float = 0.0
var is_deadline_active: bool = false
var consecutive_tasks: int = 0

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
var special_npc_assignments: Dictionary = {}

func _ready() -> void:
	_build_objectives()
	# Dummy init so UI gets the starting values
	call_deferred("emit_signal", "morale_changed", morale)
	call_deferred("emit_signal", "productivity_changed", productivity)

func _process(delta: float) -> void:
	if is_deadline_active and task_deadline_time > 0:
		task_deadline_time -= delta
		if task_deadline_time <= 0:
			# Failed deadline!
			set_productivity(productivity - 10.0)
			consecutive_tasks = 0
			# Reset to 20 seconds to keep the pressure on!
			task_deadline_time = 20.0

## Stat Helpers
func set_morale(val: float) -> void:
	morale = clamp(val, 0.0, 100.0)
	morale_changed.emit(morale)

func set_productivity(val: float) -> void:
	productivity = clamp(val, 0.0, 100.0)
	productivity_changed.emit(productivity)
	if productivity <= 0.0:
		_trigger_game_over()

func _trigger_game_over() -> void:
	# Clean up any active state
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("cancel_task"):
		player.cancel_task()

	if has_node("/root/InconvenienceManager"):
		InconvenienceManager._reset_permanent_inconveniences()
	
	# Show the GameOver overlay instead of changing scene
	var game_over = get_tree().current_scene.get_node_or_null("GameOver")
	if game_over and game_over.has_method("show_game_over"):
		game_over.show_game_over()
	else:
		# Fallback if overlay not found
		get_tree().change_scene_to_file("res://Scenes/UI/GameOver.tscn")

func reset_game_state() -> void:
	current_loop = 1
	difficulty_modifier = 1.0
	productivity = 100.0
	morale = 100.0
	consecutive_tasks = 0
	talked_npcs.clear()
	npc_positions.clear()
	special_npc_assignments.clear()
	is_deadline_active = false
	task_deadline_time = 0.0
	_build_objectives()
	
	if has_node("/root/InconvenienceManager"):
		InconvenienceManager._reset_permanent_inconveniences()

	if has_node("/root/RoomManager"):
		RoomManager.reset_layout()
	loop_restarted.emit(1)
	call_deferred("emit_signal", "morale_changed", morale)
	call_deferred("emit_signal", "productivity_changed", productivity)

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
	_start_task_deadline()

func _start_task_deadline() -> void:
	if current_task_index >= objectives.size():
		is_deadline_active = false
		return
	var time_to_complete = 24.0 * difficulty_modifier
	task_deadline_time = time_to_complete
	is_deadline_active = true
	print("[GameManager] Deadline started: %.1fs" % time_to_complete)

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
	
	# -- Productivity Logic --
	if is_deadline_active and task_deadline_time > 0:
		consecutive_tasks += 1
		if consecutive_tasks >= 2:
			set_productivity(productivity + 5.0)
			consecutive_tasks = 0
			print("[GameManager] 2 tasks done in time! Recovered 5% productivity.")
	
	# -- Morale Logic --
	var total_drop = 0.0
	if current_loop == 1:
		total_drop = 20.0
	elif current_loop == 2:
		total_drop = 40.0
	elif current_loop >= 5:
		total_drop = 1000.0 # Instantly drains morale to 0 on 1 task
	else:
		total_drop = 250.0 # 25% per task (assuming 10 tasks)
	
	var drop_per_task = total_drop / objectives.size()
	set_morale(morale - drop_per_task)
	
	objective_completed.emit(task_id)
	print("[GameManager] Objective completed: %s (%d/%d)" % [task_id, current_task_index, objectives.size()])
	
	if current_task_index >= objectives.size():
		is_deadline_active = false
		all_objectives_completed.emit()
		print("[GameManager] All objectives done!")
	else:
		_start_task_deadline()
		current_task_changed.emit(current_task_index)
		# Check if the NEW current task can auto-complete
		_check_auto_complete()

func punish_wrong_task() -> void:
	print("[GameManager] Player did the WRONG task! Knocking back 1 loop.")
	current_loop = maxi(1, current_loop - 1)
	difficulty_modifier = maxf(1.0, difficulty_modifier - 0.15)
	set_morale(100.0)
	_build_objectives()
	npc_positions.clear()
	shuffle_rooms(true)
	loop_restarted.emit(current_loop)

## Check if the current task can be auto-completed (e.g., talk_npcs already met)
func _check_auto_complete() -> void:
	if get_current_task_id() == "talk_npcs" and talked_npcs.size() >= REQUIRED_NPC_TALKS:
		complete_objective("talk_npcs")

## Time Reverse — undo the last completed task so the player must redo it
func reverse_last_task() -> void:
	if current_task_index <= 0:
		print("[GameManager] Time Reverse: No task to reverse!")
		return
	# Don't reverse clock_in — that would be confusing
	if current_task_index == 1:
		print("[GameManager] Time Reverse: Can't reverse clock_in.")
		return
	
	current_task_index -= 1
	var obj = objectives[current_task_index]
	obj["completed"] = false
	
	# Also need to un-complete the workstation in the scene
	# We do this by re-emitting the task changed signal so HUD updates
	current_task_changed.emit(current_task_index)
	_start_task_deadline()
	print("[GameManager] Time Reverse! Must redo: %s" % obj["id"])

## Force Room Swap — inject a random special room into Floor 2 layout
func force_inject_special_room() -> void:
	var special_rooms = ["Special_Castle", "Special_Beach", "Special_Ikea", "Special_Market", "Special_Spaceship"]
	var chosen_room = special_rooms.pick_random()
	
	var valid_indices = []
	for i in range(1, RoomManager.active_slots_f2.size()):
		if not "Elevator" in RoomManager.active_slots_f2[i] and not "Elevator" in RoomManager.active_slots_f2[i-1]:
			if not RoomManager.active_slots_f2[i].begins_with("Slot_Special"):
				valid_indices.append(i)
	
	if valid_indices.size() > 0:
		var insert_idx = valid_indices.pick_random()
		var slot_id = "Slot_Special_" + str(randi() % 1000)
		RoomManager.active_slots_f2.insert(insert_idx, slot_id)
		RoomManager.current_layout[slot_id] = chosen_room
		print("[GameManager] Force injected special room %s at F2 index %d" % [chosen_room, insert_idx])
	else:
		print("[GameManager] No valid slot to inject special room!")

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
	
	# Morale resets every loop. Productivity carries over.
	set_morale(100.0)
	
	_build_objectives()
	npc_positions.clear()
	shuffle_rooms(true)
	determine_special_npc_spawns()
	loop_restarted.emit(current_loop)
	print("[GameManager] === LOOP %d START === (difficulty: %.2f)" % [current_loop, difficulty_modifier])

## Get the scaled task duration
func get_scaled_duration(base_duration: float) -> float:
	return base_duration * difficulty_modifier

# ── NPC Position Persistence ──

func save_npc_positions(room_name: String, room_node: Node2D) -> void:
	var positions: Dictionary = {}
	for child in room_node.get_children():
		if child.is_in_group("npc"):
			positions[child.name] = child.global_position
	if positions.size() > 0:
		npc_positions[room_name] = positions

func restore_npc_positions(room_name: String, room_node: Node2D) -> void:
	if room_name in npc_positions:
		var positions = npc_positions[room_name]
		for child in room_node.get_children():
			if child.name in positions:
				child.global_position = positions[child.name]

# ── Dynamic Room Swapping ──
func shuffle_rooms(is_start_of_loop: bool = false) -> void:
	# Expand floor 2 at Loop 5
	if current_loop >= 5:
		if "Slot_Cubicle_Left" not in RoomManager.active_slots_f2:
			print("[GameManager] Expanding Floor 2 layout (Loop 5+)")
			RoomManager.active_slots_f2.insert(1, "Slot_Cubicle_Left")
			RoomManager.active_slots_f2.insert(3, "Slot_Cubicle_Right")
			RoomManager.current_layout["Slot_Cubicle_Left"] = "Cubicle_Left"
			RoomManager.current_layout["Slot_Cubicle_Right"] = "Cubicle_Right"
	
	# Clean up any existing special rooms from previous shuffle
	var keys_to_remove = []
	for key in RoomManager.current_layout.keys():
		if key.begins_with("Slot_Special"):
			keys_to_remove.append(key)
			if key in RoomManager.active_slots_f2:
				RoomManager.active_slots_f2.erase(key)
	for key in keys_to_remove:
		RoomManager.current_layout.erase(key)
	
	var chance = 0.0
	if is_start_of_loop:
		if current_loop == 1: chance = 0.0
		elif current_loop == 2: chance = 0.05
		elif current_loop == 3: chance = 0.15
		elif current_loop == 4: chance = 0.30
		else: chance = 0.50 + min((current_loop - 5) * 0.10, 0.49)
	else:
		chance = 1.0 # Mid-loop attack
		
	if randf() <= chance:
		print("[GameManager] SHUFFLING ROOMS!")
		var swappable_rooms = []
		var slots_to_swap = []
		
		for slot in RoomManager.current_layout.keys():
			if "Elevator" in slot: continue
			if slot == "Slot_F1_Left": continue # Lobby never swaps
			
			swappable_rooms.append(RoomManager.current_layout[slot])
			slots_to_swap.append(slot)
				
		swappable_rooms.shuffle()
		
		for i in range(slots_to_swap.size()):
			RoomManager.current_layout[slots_to_swap[i]] = swappable_rooms[i]
			
	# Inject a Special Room at the start of the loop
	if is_start_of_loop:
		var special_chance = min((current_loop - 1) * 0.05, 0.40)
		if randf() <= special_chance:
			var special_rooms = ["Special_Castle", "Special_Beach", "Special_Ikea", "Special_Market", "Special_Spaceship"]
			var chosen_room = special_rooms.pick_random()
			
			var valid_indices = []
			for i in range(1, RoomManager.active_slots_f2.size()):
				if not "Elevator" in RoomManager.active_slots_f2[i] and not "Elevator" in RoomManager.active_slots_f2[i-1]:
					valid_indices.append(i)
			
			if valid_indices.size() > 0:
				var insert_idx = valid_indices.pick_random()
				var slot_id = "Slot_Special_" + str(randi() % 1000)
				RoomManager.active_slots_f2.insert(insert_idx, slot_id)
				RoomManager.current_layout[slot_id] = chosen_room
				print("[GameManager] Spawned special room %s at F2 index %d" % [chosen_room, insert_idx])

func determine_special_npc_spawns() -> void:
	special_npc_assignments.clear()
	
	# Probability schedule:
	# - loop 1: 0%
	# - loop 2-3: 10%
	# - loop 4-7: 30%
	# - loop 8+: 40%
	var chance: float = 0.0
	if current_loop == 1:
		chance = 0.0
	elif current_loop in [2, 3]:
		chance = 0.1
	elif current_loop >= 4 and current_loop <= 7:
		chance = 0.3
	else:
		chance = 0.4
		
	var to_spawn: Array = []
	for npc_name in ["Steve", "Hans", "Chloe"]:
		if randf() < chance:
			to_spawn.append(npc_name)
			
	if to_spawn.is_empty():
		return
		
	# Get all active rooms in layout, excluding Lobby and Elevators
	var valid_rooms: Array = []
	if has_node("/root/RoomManager"):
		for slot in RoomManager.current_layout.keys():
			var rname = RoomManager.current_layout[slot]
			if "Elevator" in rname:
				continue
			if rname == "Lobby":
				continue
			valid_rooms.append(rname)
			
	if valid_rooms.is_empty():
		return
		
	valid_rooms.shuffle()
	for npc_name in to_spawn:
		if valid_rooms.is_empty():
			break
		var chosen_room = valid_rooms.pop_back()
		if not chosen_room in special_npc_assignments:
			special_npc_assignments[chosen_room] = []
		special_npc_assignments[chosen_room].append(npc_name)
		print("[GameManager] Special NPC %s assigned to spawn in %s" % [npc_name, chosen_room])
