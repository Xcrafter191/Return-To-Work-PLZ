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
var current_score: int = 0

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
			set_productivity(productivity - 5.0)
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

func add_loop_score() -> void:
	current_score += 10

func _trigger_game_over() -> void:
	# Clean up any active state
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("cancel_task"):
		player.cancel_task()

	if has_node("/root/InconvenienceManager"):
		InconvenienceManager.full_reset()
	
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
	current_score = 0
	consecutive_tasks = 0
	talked_npcs.clear()
	npc_positions.clear()
	special_npc_assignments.clear()
	is_deadline_active = false
	task_deadline_time = 0.0
	_build_objectives()
	
	if has_node("/root/InconvenienceManager"):
		InconvenienceManager.full_reset()

	if has_node("/root/SkillCheck"):
		SkillCheck.reset_tutorial_state()

	if has_node("/root/AttackSequenceManager"):
		AttackSequenceManager.reset_attack_state()

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
			set_productivity(productivity + 10.0)
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
	if get_current_task_id() == "talk_npcs":
		# Reset NPC talk count when this task becomes active — only talks DURING this task count
		talked_npcs.clear()
		npc_talk_updated.emit(0)
		print("[GameManager] talk_npcs task now active — NPC talk counter reset to 0.")

## Time Reverse — undo the last completed task so the player must redo it
func reverse_last_task() -> void:
	if current_task_index <= 0:
		print("[GameManager] Time Reverse: No task to reverse!")
		return
	# Don't reverse clock_in or coffee — those are intro tasks
	if current_task_index <= 2:
		print("[GameManager] Time Reverse: Can't reverse past coffee (index %d)." % current_task_index)
		return
	
	current_task_index -= 1
	var obj = objectives[current_task_index]
	obj["completed"] = false
	
	# Also need to un-complete the workstation in the scene
	# We do this by re-emitting the task changed signal so HUD updates
	current_task_changed.emit(current_task_index)
	_start_task_deadline()
	print("[GameManager] Time Reverse! Must redo: %s" % obj["id"])

## Force Room Swap — inject a random special room into Floor 2 layout (ADD only, never removes)
## Also randomizes layout if loop 4+ for extra chaos
func force_inject_special_room() -> void:
	# If loop 4+, also do a random room swap for chaos
	if current_loop >= 4:
		var swappable_slots = []
		for slot in RoomManager.current_layout.keys():
			if "Elevator" in slot: continue
			if slot == "Slot_F1_Left": continue
			swappable_slots.append(slot)
		if swappable_slots.size() >= 2:
			var idx_a = randi() % swappable_slots.size()
			var idx_b = randi() % swappable_slots.size()
			while idx_b == idx_a:
				idx_b = randi() % swappable_slots.size()
			var slot_a = swappable_slots[idx_a]
			var slot_b = swappable_slots[idx_b]
			var temp = RoomManager.current_layout[slot_a]
			RoomManager.current_layout[slot_a] = RoomManager.current_layout[slot_b]
			RoomManager.current_layout[slot_b] = temp
			print("[GameManager] Force swap: %s ↔ %s" % [slot_a, slot_b])
		_validate_objective_rooms_present()
	
	# Inject a special room
	var special_rooms = ["Special_Beach", "Special_Ikea", "Special_Market", "Special_Spaceship", "Special_Castle"]
	var available_rooms = []
	var existing_rooms = RoomManager.current_layout.values()
	for room in special_rooms:
		if room not in existing_rooms:
			available_rooms.append(room)
	
	if available_rooms.is_empty():
		print("[GameManager] All special rooms already in layout, nothing to inject!")
		return
	
	var chosen_room = available_rooms.pick_random()
	
	var valid_indices = []
	for i in range(1, RoomManager.active_slots_f2.size()):
		if "Elevator" in RoomManager.active_slots_f2[i]:
			continue
		if i > 0 and "Elevator" in RoomManager.active_slots_f2[i-1]:
			continue
		if RoomManager.active_slots_f2[i].begins_with("Slot_Special"):
			continue
		valid_indices.append(i)
	
	if valid_indices.size() > 0:
		var insert_idx = valid_indices.pick_random()
		var slot_id = "Slot_Special_" + str(randi() % 10000)
		RoomManager.active_slots_f2.insert(insert_idx, slot_id)
		RoomManager.current_layout[slot_id] = chosen_room
		print("[GameManager] Force injected special room %s at F2 index %d" % [chosen_room, insert_idx])
	else:
		print("[GameManager] No valid slot to inject special room!")

# ── NPC Talk Tracking ──

## Called by NPC scripts when player enters their interaction area
func register_npc_talk(npc_name: String) -> void:
	# Only count NPC talks when the talk_npcs task is the active task
	if get_current_task_id() != "talk_npcs":
		return
	if npc_name not in talked_npcs:
		talked_npcs[npc_name] = true
		print("[GameManager] Talked to: %s (%d/%d unique NPCs)" % [npc_name, talked_npcs.size(), REQUIRED_NPC_TALKS])
		npc_talk_updated.emit(talked_npcs.size())
		# If we've met the quota, auto-complete
		if talked_npcs.size() >= REQUIRED_NPC_TALKS:
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
	add_loop_score()
	
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
const OBJECTIVE_REQUIRED_ROOMS = ["Lobby", "Lounge", "Meeting", "Printer", "Cubicle_Middle"]

func shuffle_rooms(is_start_of_loop: bool = false) -> void:
	# Expand floor 2 at Loop 5 — BEFORE collecting swappable rooms
	if current_loop >= 5:
		if "Slot_Cubicle_Left" not in RoomManager.active_slots_f2:
			# Deduplication: only add Cubicle_Left/Right if not already in layout values
			var existing_rooms = RoomManager.current_layout.values()
			var should_add_left = "Cubicle_Left" not in existing_rooms
			var should_add_right = "Cubicle_Right" not in existing_rooms
			
			if should_add_left or should_add_right:
				print("[GameManager] Expanding Floor 2 layout (Loop 5+)")
			if should_add_left:
				RoomManager.active_slots_f2.insert(1, "Slot_Cubicle_Left")
				RoomManager.current_layout["Slot_Cubicle_Left"] = "Cubicle_Left"
			if should_add_right:
				# Adjust insert index based on whether left was added
				var right_idx = 3 if should_add_left else 2
				RoomManager.active_slots_f2.insert(right_idx, "Slot_Cubicle_Right")
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
	
	# ── PHASE 1: Room layout randomization (loop 4+) ──
	# Shuffle non-objective rooms between their slots for chaos
	if current_loop >= 4:
		# Determine how many rooms to randomize based on loop
		var num_swaps: int = 1
		if current_loop >= 5:
			num_swaps = 2
		if current_loop >= 7:
			num_swaps = 3
		if current_loop >= 10:
			num_swaps = 5
		
		# Collect swappable slots (not Lobby, not Elevator, not objective-required)
		var swappable_slots = []
		for slot in RoomManager.current_layout.keys():
			if "Elevator" in slot: continue
			if slot == "Slot_F1_Left": continue  # Lobby slot never moves
			var room_in_slot = RoomManager.current_layout[slot]
			# Objective rooms CAN be swapped between slots (they stay in layout, just move position)
			swappable_slots.append(slot)
		
		# Perform random pair swaps
		for _i in range(num_swaps):
			if swappable_slots.size() < 2:
				break
			var idx_a = randi() % swappable_slots.size()
			var idx_b = randi() % swappable_slots.size()
			while idx_b == idx_a and swappable_slots.size() > 1:
				idx_b = randi() % swappable_slots.size()
			var slot_a = swappable_slots[idx_a]
			var slot_b = swappable_slots[idx_b]
			# Swap the rooms between these two slots
			var temp = RoomManager.current_layout[slot_a]
			RoomManager.current_layout[slot_a] = RoomManager.current_layout[slot_b]
			RoomManager.current_layout[slot_b] = temp
			print("[GameManager] Swapped rooms: %s ↔ %s" % [slot_a, slot_b])
		
		# Validate objective rooms are still present after swaps
		_validate_objective_rooms_present()
	
	# ── PHASE 2: Inject special rooms (loop 3+) ──
	# Special rooms are ADDED to the layout, never replacing regular rooms
	var should_inject: bool = false
	if is_start_of_loop:
		if current_loop >= 3:
			should_inject = true
	else:
		should_inject = true  # Mid-loop attack always injects
		
	if should_inject:
		print("[GameManager] INJECTING SPECIAL ROOMS (loop %d)!" % current_loop)
		# Determine how many special rooms to inject based on loop
		var num_injections: int = 1
		if current_loop >= 5:
			num_injections = 2
		if current_loop >= 8:
			num_injections = 3
		
		var special_rooms = ["Special_Beach", "Special_Ikea", "Special_Market", "Special_Spaceship", "Special_Castle"]
		special_rooms.shuffle()
		
		for n in range(num_injections):
			if n >= special_rooms.size():
				break
			var chosen_room = special_rooms[n]
			
			# Check if this special room is already in the layout
			if chosen_room in RoomManager.current_layout.values():
				continue
			
			var valid_indices = []
			for i in range(1, RoomManager.active_slots_f2.size()):
				if "Elevator" in RoomManager.active_slots_f2[i]:
					continue
				if i > 0 and "Elevator" in RoomManager.active_slots_f2[i-1]:
					continue
				if RoomManager.active_slots_f2[i].begins_with("Slot_Special"):
					continue
				valid_indices.append(i)
			
			if valid_indices.size() > 0:
				var insert_idx = valid_indices.pick_random()
				var slot_id = "Slot_Special_" + str(randi() % 10000)
				RoomManager.active_slots_f2.insert(insert_idx, slot_id)
				RoomManager.current_layout[slot_id] = chosen_room
				print("[GameManager] Injected special room %s at F2 index %d" % [chosen_room, insert_idx])
	
	# Final validation: ensure all objective-required rooms are still present
	_validate_objective_rooms_present()

## Post-shuffle validation: ensure all objective-required rooms remain in the layout.
## If any are missing, swap them back in by replacing a non-objective room.
func _validate_objective_rooms_present() -> void:
	var layout_values = RoomManager.current_layout.values()
	
	for required_room in OBJECTIVE_REQUIRED_ROOMS:
		if required_room in layout_values:
			continue
		
		# Special handling: if Cubicle_Middle is missing, check if any Cubicle variant exists
		if required_room == "Cubicle_Middle":
			var has_cubicle_variant = false
			for room in layout_values:
				if room.begins_with("Cubicle"):
					has_cubicle_variant = true
					break
			if has_cubicle_variant:
				continue
		
		# Required room is missing — find a non-objective slot to swap it into
		print("[GameManager] Post-shuffle fix: %s missing from layout, swapping back in" % required_room)
		var replaced = false
		for slot in RoomManager.current_layout.keys():
			if "Elevator" in slot: continue
			if slot == "Slot_F1_Left": continue  # Never touch Lobby slot
			var current_room_in_slot = RoomManager.current_layout[slot]
			# Don't replace another objective-required room or cubicle variant
			if current_room_in_slot in OBJECTIVE_REQUIRED_ROOMS:
				continue
			if current_room_in_slot.begins_with("Cubicle"):
				continue
			if current_room_in_slot.begins_with("Special"):
				continue
			# Replace this non-objective room with the missing required room
			RoomManager.current_layout[slot] = required_room
			replaced = true
			break
		
		if not replaced:
			push_warning("[GameManager] Could not find a slot to restore %s!" % required_room)
		
		# Refresh layout_values for subsequent checks
		layout_values = RoomManager.current_layout.values()

func determine_special_npc_spawns() -> void:
	special_npc_assignments.clear()
	
	# All 3 main NPCs always spawn from loop 1, each in a different room.
	# Chance per NPC scales with loop:
	# - loop 1: 30%
	# - loop 2: 50%
	# - loop 3: 60%
	# - loop 4-5: 75%
	# - loop 6+: 90%
	var chance: float = 0.3
	if current_loop == 1:
		chance = 0.3
	elif current_loop == 2:
		chance = 0.5
	elif current_loop == 3:
		chance = 0.6
	elif current_loop >= 4 and current_loop <= 5:
		chance = 0.75
	else:
		chance = 0.9
		
	var to_spawn: Array = []
	for npc_name in ["Steve", "Hans", "Chloe"]:
		if randf() < chance:
			to_spawn.append(npc_name)
	if to_spawn.is_empty():
		return
		
	# Get all active rooms in layout, including Elevators (NPCs can appear anywhere)
	var valid_rooms: Array = []
	if has_node("/root/RoomManager"):
		for slot in RoomManager.current_layout.keys():
			var rname = RoomManager.current_layout[slot]
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
