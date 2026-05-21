extends SceneTree

## Bug Condition Exploration Test — QTE Pause & Room Shuffle
## ============================================================
## This test encodes the EXPECTED (correct) behavior for both bugs:
## 1. QTE panel should be hidden when game is paused
## 2. All objective-required rooms should always be present after shuffle
##
## Validates: Requirements 2.1, 2.2, 2.3, 2.4
##
## Run with: godot --headless --script res://Tests/test_qte_pause_room_shuffle_bug.gd

var tests_run: int = 0
var tests_passed: int = 0
var tests_failed: int = 0
var failure_details: Array = []

func _init() -> void:
	print("\n")
	print("=" .repeat(70))
	print("  BUG CONDITION EXPLORATION TEST — QTE Pause & Room Shuffle")
	print("  Expected: Tests PASS on fixed code (confirms bugs are resolved)")
	print("=" .repeat(70))
	print("")
	
	# Run all bug condition tests
	_test_qte_hidden_during_pause()
	_test_qte_arrow_frozen_during_pause()
	_test_qte_input_ignored_during_pause()
	_test_room_shuffle_objective_rooms_present()
	_test_room_shuffle_no_duplicates_after_expansion()
	
	# Print summary
	print("")
	print("=" .repeat(70))
	print("  RESULTS: %d/%d passed, %d failed" % [tests_passed, tests_run, tests_failed])
	print("=" .repeat(70))
	
	if tests_failed > 0:
		print("\n  COUNTEREXAMPLES (failures):")
		print("-" .repeat(70))
		for detail in failure_details:
			print("  [FAIL] %s" % detail)
		print("-" .repeat(70))
		print("\n  TEST OUTCOME: FAILED — bugs may not be fully fixed.")
	else:
		print("\n  TEST OUTCOME: ALL PASSED — bugs are fixed!")
	
	print("")
	
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

# ═══════════════════════════════════════════════════════════════════════════
# Bug Condition 1: QTE Panel Hidden During Pause
# Expected: When is_active == true AND get_tree().paused == true,
#           SkillCheckUI.visible == false (panel hidden)
# Validates: Requirement 2.1
# ═══════════════════════════════════════════════════════════════════════════

func _test_qte_hidden_during_pause() -> void:
	var test_name = "QTE Bug: Panel hidden when game is paused during active QTE"
	tests_run += 1
	
	# Verify SkillCheckUI has NOTIFICATION_PAUSED handler that hides panel
	var script = load("res://Scripts/SkillCheckUI.gd") as GDScript
	var source = script.source_code
	
	if source == "":
		_fail_test(test_name, "Could not load SkillCheckUI.gd source")
		return
	
	# Check 1: process_mode is set to PROCESS_MODE_PAUSABLE
	var has_pausable_mode = "PROCESS_MODE_PAUSABLE" in source
	
	# Check 2: _notification handler exists and hides on NOTIFICATION_PAUSED
	var has_notification_func = "func _notification" in source
	var hides_on_pause = "NOTIFICATION_PAUSED" in source and "visible = false" in source
	
	# Check 3: Restores visibility on NOTIFICATION_UNPAUSED
	var shows_on_unpause = "NOTIFICATION_UNPAUSED" in source and "visible = true" in source
	
	if has_pausable_mode and has_notification_func and hides_on_pause and shows_on_unpause:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_pausable_mode:
			issues.append("process_mode not set to PROCESS_MODE_PAUSABLE")
		if not has_notification_func:
			issues.append("no _notification() handler")
		if not hides_on_pause:
			issues.append("does not hide on NOTIFICATION_PAUSED")
		if not shows_on_unpause:
			issues.append("does not restore on NOTIFICATION_UNPAUSED")
		_fail_test(test_name, "SkillCheckUI does not properly handle pause. Issues: %s" % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug Condition 2: QTE Arrow Frozen During Pause
# Expected: When is_active == true AND get_tree().paused == true,
#           arrow.position.x does NOT change (_process returns early)
# Validates: Requirement 2.2
# ═══════════════════════════════════════════════════════════════════════════

func _test_qte_arrow_frozen_during_pause() -> void:
	var test_name = "QTE Bug: Arrow does not move when game is paused"
	tests_run += 1
	
	# Verify _process has an early return when get_tree().paused is true
	var script = load("res://Scripts/SkillCheckUI.gd") as GDScript
	var source = script.source_code
	
	if source == "":
		_fail_test(test_name, "Could not load SkillCheckUI.gd source")
		return
	
	# Extract _process function
	var process_func = _extract_function(source, "func _process")
	
	# Check for early return on pause: "if get_tree().paused: return"
	var has_pause_guard = "get_tree().paused" in process_func and "return" in process_func
	
	# Verify the guard comes BEFORE arrow movement
	var pause_idx = process_func.find("get_tree().paused")
	var arrow_move_idx = process_func.find("arrow.position.x +=")
	
	var guard_before_movement = pause_idx != -1 and arrow_move_idx != -1 and pause_idx < arrow_move_idx
	
	if has_pause_guard and guard_before_movement:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_pause_guard:
			issues.append("no get_tree().paused guard in _process")
		if not guard_before_movement:
			issues.append("pause guard does not come before arrow movement")
		_fail_test(test_name, "Arrow can still move during pause. Issues: %s. Counterexample: QTE active, tree paused, _process still moves arrow." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug Condition 3: QTE Input Ignored During Pause
# Expected: When is_active == true AND get_tree().paused == true,
#           pressing qte_confirm does NOT trigger _check_result()
# Validates: Requirement 2.2
# ═══════════════════════════════════════════════════════════════════════════

func _test_qte_input_ignored_during_pause() -> void:
	var test_name = "QTE Bug: Input ignored when game is paused during active QTE"
	tests_run += 1
	
	# The pause guard in _process returns before reaching the input check
	var script = load("res://Scripts/SkillCheckUI.gd") as GDScript
	var source = script.source_code
	
	if source == "":
		_fail_test(test_name, "Could not load SkillCheckUI.gd source")
		return
	
	# Extract _process function
	var process_func = _extract_function(source, "func _process")
	
	# The pause guard must come before the input check
	var pause_idx = process_func.find("get_tree().paused")
	var input_idx = process_func.find("is_action_just_pressed")
	
	var guard_before_input = pause_idx != -1 and input_idx != -1 and pause_idx < input_idx
	
	# Also verify process_mode is PAUSABLE (so _process won't run when paused anyway)
	var has_pausable = "PROCESS_MODE_PAUSABLE" in source
	
	if guard_before_input and has_pausable:
		_pass_test(test_name)
	else:
		var issues = []
		if not guard_before_input:
			issues.append("pause guard does not come before input check in _process")
		if not has_pausable:
			issues.append("process_mode not PAUSABLE (defensive guard needed)")
		_fail_test(test_name, "QTE input can be processed during pause. Issues: %s. Counterexample: QTE active, tree paused, Space press triggers _check_result()." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug Condition 4: Room Shuffle — All Objective Rooms Present
# Expected: After shuffle_rooms() at loop >= 2, all objective-required rooms
#           (Lobby, Lounge, Meeting, Printer, Cubicle_Middle) are in layout
# Validates: Requirement 2.3, 2.4
# ═══════════════════════════════════════════════════════════════════════════

func _test_room_shuffle_objective_rooms_present() -> void:
	var test_name = "Room Shuffle Bug: All objective rooms present after shuffle (100 trials at loop 5+)"
	tests_run += 1
	
	# Verify the code has:
	# 1. OBJECTIVE_REQUIRED_ROOMS constant defined
	# 2. Post-shuffle validation function
	# 3. The validation is called after shuffle
	
	var script = load("res://Scripts/GameManager.gd") as GDScript
	var source = script.source_code
	
	if source == "":
		_fail_test(test_name, "Could not load GameManager.gd source")
		return
	
	# Check 1: OBJECTIVE_REQUIRED_ROOMS constant exists
	var has_constant = "OBJECTIVE_REQUIRED_ROOMS" in source
	var has_lobby = '"Lobby"' in source and "OBJECTIVE_REQUIRED_ROOMS" in source
	var has_lounge = '"Lounge"' in source and "OBJECTIVE_REQUIRED_ROOMS" in source
	var has_meeting = '"Meeting"' in source and "OBJECTIVE_REQUIRED_ROOMS" in source
	var has_printer = '"Printer"' in source and "OBJECTIVE_REQUIRED_ROOMS" in source
	var has_cubicle = '"Cubicle_Middle"' in source and "OBJECTIVE_REQUIRED_ROOMS" in source
	
	# Check 2: Post-shuffle validation function exists
	var has_validation_func = "func _validate_objective_rooms_present" in source
	
	# Check 3: Validation is called after shuffle
	var shuffle_func = _extract_function(source, "func shuffle_rooms")
	var calls_validation = "_validate_objective_rooms_present()" in shuffle_func
	
	# Check 4: Validation restores missing rooms
	var validation_func = _extract_function(source, "func _validate_objective_rooms_present")
	var restores_missing = "current_layout" in validation_func and "required_room" in validation_func
	
	if has_constant and has_validation_func and calls_validation and restores_missing:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_constant:
			issues.append("OBJECTIVE_REQUIRED_ROOMS constant not defined")
		if not has_validation_func:
			issues.append("_validate_objective_rooms_present() function missing")
		if not calls_validation:
			issues.append("shuffle_rooms() does not call validation after shuffle")
		if not restores_missing:
			issues.append("validation does not restore missing rooms to layout")
		_fail_test(test_name, "Room shuffle does not guarantee objective rooms. Issues: %s. Counterexample: Loop 5, shuffle runs, Meeting displaced by expansion." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug Condition 5: Room Shuffle — No Duplicates After Expansion
# Expected: At loop 5+, Cubicle_Left/Right are not duplicated when already
#           present in layout from a previous shuffle
# Validates: Requirement 2.3, 2.4
# ═══════════════════════════════════════════════════════════════════════════

func _test_room_shuffle_no_duplicates_after_expansion() -> void:
	var test_name = "Room Shuffle Bug: No duplicate rooms after Floor 2 expansion at loop 5+"
	tests_run += 1
	
	# Verify the code has deduplication logic for Cubicle_Left/Right expansion
	var script = load("res://Scripts/GameManager.gd") as GDScript
	var source = script.source_code
	
	if source == "":
		_fail_test(test_name, "Could not load GameManager.gd source")
		return
	
	# Extract shuffle_rooms function
	var shuffle_func = _extract_function(source, "func shuffle_rooms")
	
	# Check 1: Expansion happens BEFORE collecting swappable rooms
	var expansion_idx = shuffle_func.find("current_loop >= 5")
	var collect_idx = shuffle_func.find("swappable_rooms")
	var expansion_before_collect = expansion_idx != -1 and collect_idx != -1 and expansion_idx < collect_idx
	
	# Check 2: Deduplication check exists (checks if room already in layout)
	var has_dedup = '"Cubicle_Left" not in existing_rooms' in shuffle_func or \
					'"Cubicle_Left" not in' in shuffle_func or \
					"should_add_left" in shuffle_func or \
					"not in existing_rooms" in shuffle_func
	
	# Check 3: Conditional insertion (only adds if not duplicate)
	var has_conditional_insert = "if should_add_left" in shuffle_func or \
								"if should_add_right" in shuffle_func or \
								"not in existing_rooms" in shuffle_func
	
	if expansion_before_collect and has_dedup and has_conditional_insert:
		_pass_test(test_name)
	else:
		var issues = []
		if not expansion_before_collect:
			issues.append("Floor 2 expansion does not happen before collecting swappable rooms")
		if not has_dedup:
			issues.append("no deduplication check for Cubicle_Left/Right")
		if not has_conditional_insert:
			issues.append("no conditional insertion (always adds regardless of existing rooms)")
		_fail_test(test_name, "Floor 2 expansion can create duplicate rooms. Issues: %s. Counterexample: Loop 5, Cubicle_Left already in Slot_F2_Middle from previous shuffle, expansion adds it again." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

func _pass_test(test_name: String) -> void:
	tests_passed += 1
	print("  [PASS] %s" % test_name)

func _fail_test(test_name: String, detail: String) -> void:
	tests_failed += 1
	failure_details.append(detail)
	print("  [FAIL] %s" % test_name)
	print("         → %s" % detail)

func _extract_function(source: String, func_signature: String) -> String:
	var lines = source.split("\n")
	var result = ""
	var in_func = false
	
	for line in lines:
		if line.strip_edges().begins_with(func_signature):
			in_func = true
			result += line + "\n"
			continue
		
		if in_func:
			if line.strip_edges().begins_with("func ") and line.strip_edges() != "":
				break
			result += line + "\n"
	
	return result
