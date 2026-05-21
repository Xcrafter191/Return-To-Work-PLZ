extends SceneTree

## Bug Condition Exploration Test — Task CTA & Inconvenience Defects
## ==================================================================
## This test encodes the EXPECTED (correct) behavior for 7 bugs.
## It is designed to FAIL on unfixed code, confirming the bugs exist.
##
## **Validates: Requirements 1.1, 1.2, 1.3, 1.5, 1.7, 1.8, 1.9**
##
## Run with: godot --headless --script res://Tests/test_bug_condition_exploration.gd

var tests_run: int = 0
var tests_passed: int = 0
var tests_failed: int = 0
var failure_details: Array = []

func _init() -> void:
	print("\n")
	print("=" .repeat(70))
	print("  BUG CONDITION EXPLORATION TEST — Task CTA & Inconvenience Defects")
	print("  Expected: Tests FAIL on unfixed code (confirms bugs exist)")
	print("  Expected: Tests PASS on fixed code (confirms bugs resolved)")
	print("=" .repeat(70))
	print("")

	_test_bug1_cta_flash_targets_direction_arrow()
	_test_bug2_glow_only_on_active_workstation()
	_test_bug3_same_floor_arrow_horizontal()
	_test_bug5_keybind_randomizes_all_actions()
	_test_bug7_time_stop_blocks_prompt_immediately()
	_test_bug8_gibberish_random_per_label()
	_test_bug9_time_reverse_resets_workstation()

	print("")
	print("=" .repeat(70))
	print("  RESULTS: %d/%d passed, %d failed" % [tests_passed, tests_run, tests_failed])
	print("=" .repeat(70))

	if tests_failed > 0:
		print("\n  COUNTEREXAMPLES (failures confirm bugs exist):")
		print("-" .repeat(70))
		for detail in failure_details:
			print("  [BUG] %s" % detail)
		print("-" .repeat(70))
		print("\n  TEST OUTCOME: FAILED — bugs confirmed to exist on unfixed code.")
	else:
		print("\n  TEST OUTCOME: ALL PASSED — all bugs are fixed!")

	print("")

	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

# ═══════════════════════════════════════════════════════════════════════════
# Bug 1: CTA Flash Targets Direction Arrow, NOT task_bg
# Expected: _start_cta_flash() animates direction_arrow.modulate:a
# Counterexample on unfixed code: tween targets task_bg instead
# Validates: Requirement 1.1
# ═══════════════════════════════════════════════════════════════════════════

func _test_bug1_cta_flash_targets_direction_arrow() -> void:
	var test_name = "Bug 1 (CTA Flash): _start_cta_flash() animates direction_arrow NOT task_bg"
	tests_run += 1

	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code

	if source == "":
		_fail_test(test_name, "Could not load HUD.gd source")
		return

	var flash_func = _extract_function(source, "func _start_cta_flash")
	var stop_func = _extract_function(source, "func _stop_cta_flash")

	# Check: tween targets direction_arrow, NOT task_bg
	var targets_direction_arrow = "direction_arrow" in flash_func and "modulate:a" in flash_func
	var does_not_target_task_bg = "task_bg" not in flash_func

	# Check: stop resets direction_arrow, NOT task_bg
	var stop_resets_arrow = "direction_arrow" in stop_func
	var stop_does_not_reset_task_bg = "task_bg" not in stop_func

	if targets_direction_arrow and does_not_target_task_bg and stop_resets_arrow and stop_does_not_reset_task_bg:
		_pass_test(test_name)
	else:
		var issues = []
		if not targets_direction_arrow:
			issues.append("tween does not target direction_arrow.modulate:a")
		if not does_not_target_task_bg:
			issues.append("tween targets task_bg (WRONG element)")
		if not stop_resets_arrow:
			issues.append("_stop_cta_flash does not reset direction_arrow")
		if not stop_does_not_reset_task_bg:
			issues.append("_stop_cta_flash resets task_bg (should not)")
		_fail_test(test_name, "CTA flash targets wrong element. Issues: %s. Counterexample: _start_cta_flash() called, task_bg.modulate:a oscillates 0.4-1.0 instead of direction_arrow." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug 2: Glow Only On Active Workstation
# Expected: _update_glow_state() calls _stop_glow() for non-active tasks
# Counterexample on unfixed code: _start_glow() called unconditionally
# Validates: Requirement 1.2
# ═══════════════════════════════════════════════════════════════════════════

func _test_bug2_glow_only_on_active_workstation() -> void:
	var test_name = "Bug 2 (Glow): Non-active workstations do NOT glow"
	tests_run += 1

	var script = load("res://Scripts/InteractableObject.gd") as GDScript
	var source = script.source_code

	if source == "":
		_fail_test(test_name, "Could not load InteractableObject.gd source")
		return

	# The fix uses _update_glow_state() which checks task_id against current task
	var glow_state_func = _extract_function(source, "func _update_glow_state")

	# Check: _update_glow_state exists and has conditional logic
	var has_glow_state_func = glow_state_func != ""
	var checks_current_task = "get_current_task_id()" in glow_state_func
	var calls_stop_glow_for_non_active = "_stop_glow()" in glow_state_func
	var calls_start_glow_for_active = "_start_glow()" in glow_state_func

	# Also verify _update_prompt_visibility does NOT call _start_glow
	var prompt_func = _extract_function(source, "func _update_prompt_visibility")
	var prompt_does_not_start_glow = "_start_glow()" not in prompt_func

	if has_glow_state_func and checks_current_task and calls_stop_glow_for_non_active and calls_start_glow_for_active and prompt_does_not_start_glow:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_glow_state_func:
			issues.append("_update_glow_state() function missing")
		if not checks_current_task:
			issues.append("does not check get_current_task_id()")
		if not calls_stop_glow_for_non_active:
			issues.append("does not call _stop_glow() for non-active tasks")
		if not calls_start_glow_for_active:
			issues.append("does not call _start_glow() for active task")
		if not prompt_does_not_start_glow:
			issues.append("_update_prompt_visibility still calls _start_glow()")
		_fail_test(test_name, "Glow starts on non-active workstations. Issues: %s. Counterexample: workstation with task_id='type_report' glows when current task is 'clock_in'." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug 3: Same-Floor Arrow Shows Horizontal Direction
# Expected: When player and task are on same floor, arrow shows ← or →
# Counterexample on unfixed code: arrow shows ↓ for same-floor targets
# Validates: Requirement 1.3
# ═══════════════════════════════════════════════════════════════════════════

func _test_bug3_same_floor_arrow_horizontal() -> void:
	var test_name = "Bug 3 (Arrow): Same-floor targets get horizontal arrow (← or →)"
	tests_run += 1

	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code

	if source == "":
		_fail_test(test_name, "Could not load HUD.gd source")
		return

	var arrow_func = _extract_function(source, "func _update_direction_arrow")

	# Check 1: Guard for target_floor == 0 (slot not found)
	var has_floor_zero_guard = 'target_floor == 0' in arrow_func and "direction_arrow.visible = false" in arrow_func

	# Check 2: Same-floor logic uses _set_arrow_side (horizontal)
	var has_same_floor_logic = "_set_arrow_side(target_idx < cur_idx)" in arrow_func

	# Check 3: The same-floor section does NOT set rotation to 90 or 270 (vertical)
	# Extract the same-floor section (after "Target di lantai sama" comment)
	var same_floor_idx = arrow_func.find("Target di lantai sama")
	var same_floor_section = arrow_func.substr(same_floor_idx) if same_floor_idx != -1 else ""
	var no_vertical_in_same_floor = "rotation_degrees = 90" not in same_floor_section and "rotation_degrees = 270" not in same_floor_section

	if has_floor_zero_guard and has_same_floor_logic and no_vertical_in_same_floor:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_floor_zero_guard:
			issues.append("no guard for target_floor == 0 (unknown slot)")
		if not has_same_floor_logic:
			issues.append("same-floor logic does not use _set_arrow_side for horizontal direction")
		if not no_vertical_in_same_floor:
			issues.append("same-floor section sets vertical rotation (90/270)")
		_fail_test(test_name, "Same-floor arrow shows wrong direction. Issues: %s. Counterexample: Player at Slot_F2_Right (Meeting), task at Slot_F2_Left (Lounge), arrow shows ↓ instead of ←." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug 5: Control Reverse Randomizes ALL Remappable Keys
# Expected: "keybind" inconvenience randomizes move_left, move_right,
#           interact, AND qte_confirm — not just left/right swap
# Counterexample on unfixed code: only move_left and move_right swap
# Validates: Requirement 1.5
# ═══════════════════════════════════════════════════════════════════════════

func _test_bug5_keybind_randomizes_all_actions() -> void:
	var test_name = "Bug 5 (Keybind): All 4 remappable actions get randomized"
	tests_run += 1

	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code

	if source == "":
		_fail_test(test_name, "Could not load InconvenienceManager.gd source")
		return

	var medium_func = _extract_function(source, "func _execute_medium")

	# Extract the keybind section from _execute_medium
	var keybind_start = medium_func.find('choice == "keybind"')
	var keybind_section = medium_func.substr(keybind_start, 800) if keybind_start != -1 else ""

	# Check 1: All 4 actions are in the remappable list
	var has_move_left = '"move_left"' in keybind_section
	var has_move_right = '"move_right"' in keybind_section
	var has_interact = '"interact"' in keybind_section
	var has_qte_confirm = '"qte_confirm"' in keybind_section

	# Check 2: Uses shuffle for randomization (not just a simple swap)
	var uses_shuffle = ".shuffle()" in keybind_section

	# Check 3: Excludes ESC and numpad keys
	var excludes_esc = "KEY_ESCAPE" in keybind_section
	var excludes_numpad = "KEY_KP" in keybind_section

	if has_move_left and has_move_right and has_interact and has_qte_confirm and uses_shuffle and excludes_esc and excludes_numpad:
		_pass_test(test_name)
	else:
		var issues = []
		if not has_move_left:
			issues.append("move_left not in remappable actions")
		if not has_move_right:
			issues.append("move_right not in remappable actions")
		if not has_interact:
			issues.append("interact not in remappable actions")
		if not has_qte_confirm:
			issues.append("qte_confirm not in remappable actions")
		if not uses_shuffle:
			issues.append("does not use shuffle() for randomization (likely just swaps 2)")
		if not excludes_esc:
			issues.append("does not exclude ESC key")
		if not excludes_numpad:
			issues.append("does not exclude numpad keys")
		_fail_test(test_name, "Keybind only swaps left/right. Issues: %s. Counterexample: 'keybind' triggered, only move_left and move_right swap, interact and qte_confirm unchanged." % ", ".join(issues))

# ═══════════════════════════════════════════════════════════════════════════
# Bug 7: Time Stop Blocks Prompt Immediately
# Expected: When is_time_stopped == true and player enters workstation range,
#           prompt shows "[TIME FROZEN]" WITHOUT requiring E press
# Counterexample on unfixed code: prompt shows normal text, only changes after E
# Validates: Requirement 1.7
# ═══════════════════════════════════════════════════════════════════════════

func _test_bug7_time_stop_blocks_prompt_immediately() -> void:
	var test_name = "Bug 7 (Time Stop): Prompt shows [TIME FROZEN] immediately without E press"
	tests_run += 1

	var script = load("res://Scripts/InteractableObject.gd") as GDScript
	var source = script.source_code

	if source == "":
		_fail_test(test_name, "Could not load InteractableObject.gd source")
		return

	var prompt_func = _extract_function(source, "func _update_prompt_visibility")

	# Check 1: _update_prompt_visibility checks is_time_stopped
	var checks_time_stopped = "is_time_stopped" in prompt_func

	# Check 2: Shows "[TIME FROZEN]" in the prompt function (not just in _input)
	var shows_frozen_in_prompt = "[TIME FROZEN]" in prompt_func

	# Check 3: The time stop check happens BEFORE showing normal prompt text
	var time_stop_idx = prompt_func.find("is_time_stopped")
	var press_e_idx = prompt_func.find('Press [E]')
	var check_before_normal = time_stop_idx != -1 and press_e_idx != -1 and time_stop_idx < press_e_idx

	if checks_time_stopped and shows_frozen_in_prompt and check_before_normal:
		_pass_test(test_name)
	else:
		var issues = []
		if not checks_time_stopped:
			issues.append("_update_prompt_visibility does not check is_time_stopped")
		if not shows_frozen_in_prompt:
			issues.append("'[TIME FROZEN]' not shown in prompt update function")
		if not check_before_normal:
			issues.append("time stop check does not come before normal prompt text")
		_fail_test(test_name, "Time stop does not block prompt immediately. Issues: %s. Counterexample: is_time_stopped=true, player enters range, sees 'Press [E] - Make coffee' instead of '[TIME FROZEN]'." % ", ".join(issues))
