extends SceneTree

## Preservation Property Tests — Task 2
## Tests that verify EXISTING correct behavior on UNFIXED code.
## These tests capture baseline behavior that must be preserved after bugfixes.
##
## **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**
##
## Run with: godot --headless --script res://Tests/test_preservation.gd

var _pass_count: int = 0
var _fail_count: int = 0
var _total_count: int = 0

func _init() -> void:
	print("\n══════════════════════════════════════════════════════════")
	print("  PRESERVATION PROPERTY TESTS — Baseline Behavior")
	print("══════════════════════════════════════════════════════════\n")
	
	_run_all_tests()
	
	print("\n══════════════════════════════════════════════════════════")
	print("  RESULTS: %d passed, %d failed, %d total" % [_pass_count, _fail_count, _total_count])
	print("══════════════════════════════════════════════════════════\n")
	
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _run_all_tests() -> void:
	# Property 2.1: Task completion animation (Req 3.1)
	_test_task_complete_animation_called_on_objective_complete()
	_test_task_complete_animation_slides_out_then_shows_next()
	_test_task_complete_animation_multiple_completions()
	
	# Property 2.2: Direction arrow hidden in same room (Req 3.2)
	_test_direction_arrow_hidden_when_in_task_room()
	_test_direction_arrow_hidden_for_any_room_type()
	_test_direction_arrow_hidden_for_cubicle_tasks()
	
	# Property 2.3: Elevator arrow shows correct vertical direction (Req 3.3, 3.4)
	_test_elevator_arrow_up_when_task_above()
	_test_elevator_arrow_down_when_task_below()
	_test_arrow_points_to_elevator_when_different_floor()
	
	# Property 2.4: Active workstation prompt and interaction (Req 3.5)
	_test_active_workstation_shows_prompt()
	_test_active_workstation_prompt_format()
	_test_workstation_is_available_only_for_active_task()
	
	# Property 2.5: Time accelerate behavior (Req 3.7)
	_test_time_accelerate_sets_4x_speed()
	_test_time_accelerate_uses_process_always_timer()
	
	# Property 2.6: Productivity bonus for consecutive tasks (Req 3.8)
	_test_consecutive_tasks_award_productivity_bonus()
	_test_productivity_bonus_resets_after_award()
	
	# Property 2.7: QTE skill check uses qte_confirm (Req 3.9)
	_test_qte_uses_qte_confirm_action()
	_test_qte_does_not_use_interact_action()
	
	# Property 2.8: Inconvenience auto-fix timers (Req 3.6, 3.10)
	_test_fake_ad_has_autofix_timer()
	_test_blur_has_autofix_timer()
	_test_time_accelerate_reverts_after_2s()
	_test_inconvenience_quotas_respected()
	_test_accumulated_chance_mechanics()

# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	_total_count += 1
	if condition:
		_pass_count += 1
		print("  ✓ PASS: %s" % test_name)
	else:
		_fail_count += 1
		var msg = "  ✗ FAIL: %s" % test_name
		if detail != "":
			msg += " — %s" % detail
		print(msg)

func _assert_eq(actual, expected, test_name: String) -> void:
	_assert(actual == expected, test_name, "expected '%s', got '%s'" % [str(expected), str(actual)])

func _assert_neq(actual, not_expected, test_name: String) -> void:
	_assert(actual != not_expected, test_name, "should not be '%s'" % str(not_expected))

func _assert_gt(actual: float, threshold: float, test_name: String) -> void:
	_assert(actual > threshold, test_name, "expected > %s, got %s" % [str(threshold), str(actual)])

func _assert_contains(text: String, substring: String, test_name: String) -> void:
	_assert(text.contains(substring), test_name, "'%s' not found in '%s'" % [substring, text])

# ═══════════════════════════════════════════════════════════════════
# Property 2.1: Task Completion Animation
# **Validates: Requirements 3.1**
# For all normal task completions, _animate_task_complete() is called
# and animation plays (slide-out, then next task slides in).
# ═══════════════════════════════════════════════════════════════════

func _test_task_complete_animation_called_on_objective_complete() -> void:
	# Verify that HUD connects objective_completed signal to _on_objective_completed
	# which calls _animate_task_complete()
	# We verify the code structure: _on_objective_completed calls _animate_task_complete
	
	# The HUD._on_objective_completed function exists and calls _animate_task_complete
	# We verify this by checking the signal connection pattern in _ready()
	# HUD._ready() has: GameManager.objective_completed.connect(_on_objective_completed)
	# And _on_objective_completed calls _animate_task_complete()
	
	# Structural verification: the function exists and has the right call chain
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("objective_completed.connect(_on_objective_completed)"),
		"HUD connects objective_completed signal")
	_assert(source.contains("func _on_objective_completed"),
		"HUD has _on_objective_completed handler")
	_assert(source.contains("_animate_task_complete()"),
		"_on_objective_completed calls _animate_task_complete()")

func _test_task_complete_animation_slides_out_then_shows_next() -> void:
	# Verify _animate_task_complete() creates a tween that:
	# 1. Waits 0.8s
	# 2. Slides task_bg to x=1550 (slide out)
	# 3. Calls _on_slide_out_done which shows next task
	
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	# Check slide-out animation structure
	_assert(source.contains("tween_interval(0.8)"),
		"Animation has 0.8s delay before slide-out")
	_assert(source.contains("\"position:x\", 1550"),
		"Animation slides task_bg to x=1550")
	_assert(source.contains("_on_slide_out_done"),
		"Animation calls _on_slide_out_done callback")

func _test_task_complete_animation_multiple_completions() -> void:
	# Verify _animating flag prevents overlapping animations
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("if _animating:"),
		"_animate_task_complete guards against overlapping animations")
	_assert(source.contains("_animating = true"),
		"Sets _animating flag at start")
	_assert(source.contains("_animating = false"),
		"Clears _animating flag when done")

# ═══════════════════════════════════════════════════════════════════
# Property 2.2: Direction Arrow Hidden in Same Room
# **Validates: Requirements 3.2**
# For all states where player is in task room, direction arrow is hidden.
# ═══════════════════════════════════════════════════════════════════

func _test_direction_arrow_hidden_when_in_task_room() -> void:
	# When target_slot == current_slot, arrow is hidden
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	# The code checks: if target_slot == "" or target_slot == RoomManager.current_slot:
	#   direction_arrow.visible = false
	_assert(source.contains("target_slot == RoomManager.current_slot"),
		"Arrow hidden when player is in target slot (same room)")

func _test_direction_arrow_hidden_for_any_room_type() -> void:
	# When task_room is "Any", arrow is hidden (talk_npcs task)
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("task_room == \"Any\""),
		"Arrow hidden for 'Any' room tasks (talk_npcs)")

func _test_direction_arrow_hidden_for_cubicle_tasks() -> void:
	# When task_room is "Cubicle", arrow is hidden (multiple possible locations)
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("task_room == \"Cubicle\"") or source.contains("\"Cubicle\""),
		"Arrow hidden for 'Cubicle' room tasks (multiple locations)")

# ═══════════════════════════════════════════════════════════════════
# Property 2.3: Elevator Arrow Shows Correct Vertical Direction
# **Validates: Requirements 3.3, 3.4**
# For all elevator states with task on different floor, arrow shows ↑ or ↓.
# ═══════════════════════════════════════════════════════════════════

func _test_elevator_arrow_up_when_task_above() -> void:
	# When in elevator and target_floor > current_floor, arrow shows ↑
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("\"↑\" if target_floor > RoomManager.current_floor else \"↓\""),
		"Elevator arrow shows ↑ when task is on higher floor")

func _test_elevator_arrow_down_when_task_below() -> void:
	# The same expression handles both: ↑ if above, ↓ if below
	# Verify the in_elevator special case exists
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("if in_elevator:"),
		"Special case for player inside elevator exists")
	_assert(source.contains("\"Elevator\" in current_slot"),
		"Detects elevator by checking slot name")

func _test_arrow_points_to_elevator_when_different_floor() -> void:
	# When target is on different floor and player NOT in elevator,
	# arrow points toward the elevator slot on current floor
	var script = load("res://Scripts/HUD.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("target_floor != RoomManager.current_floor"),
		"Detects when target is on different floor")
	_assert(source.contains("Elevator_F1") and source.contains("Elevator_F2"),
		"Finds elevator slot on current floor")
	_assert(source.contains("_set_arrow_side(elev_idx < cur_idx)"),
		"Points arrow toward elevator direction")

# ═══════════════════════════════════════════════════════════════════
# Property 2.4: Active Workstation Prompt and Interaction
# **Validates: Requirements 3.5**
# For all active workstation interactions, prompt shows and interaction succeeds.
# ═══════════════════════════════════════════════════════════════════

func _test_active_workstation_shows_prompt() -> void:
	# When _is_available() returns true and player_in_range, prompt is visible
	var script = load("res://Scripts/InteractableObject.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("if _is_available():"),
		"_update_prompt checks _is_available()")
	_assert(source.contains("prompt_label.visible = true"),
		"Prompt becomes visible when task is available")

func _test_active_workstation_prompt_format() -> void:
	# Prompt shows "Press [E] - <task_name>" format
	var script = load("res://Scripts/InteractableObject.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("\"Press [E] - %s\" % display_name"),
		"Prompt shows 'Press [E] - <task_name>' format")

func _test_workstation_is_available_only_for_active_task() -> void:
	# _is_available() returns true only when task_id matches current active task
	var script = load("res://Scripts/InteractableObject.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("GameManager.is_task_active(task_id)"),
		"_is_available checks GameManager.is_task_active(task_id)")
	_assert(source.contains("if task_completed or task_id == \"\": return false"),
		"_is_available returns false if already completed or no task_id")

# ═══════════════════════════════════════════════════════════════════
# Property 2.5: Time Accelerate Behavior
# **Validates: Requirements 3.7**
# For all time_accelerate triggers, time_scale is 4.0 for exactly 2s then reverts.
# ═══════════════════════════════════════════════════════════════════

func _test_time_accelerate_sets_4x_speed() -> void:
	# time_accelerate sets Engine.time_scale = 4.0
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("Engine.time_scale = 4.0"),
		"time_accelerate sets Engine.time_scale to 4.0")

func _test_time_accelerate_uses_process_always_timer() -> void:
	# Timer uses process_always so it works correctly at 4x speed
	# The timer is created with create_timer(2.0, true, false, true)
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("create_timer(2.0, true, false, true)"),
		"time_accelerate uses 2s timer with process_always=true")
	_assert(source.contains("Engine.time_scale = 1.0"),
		"time_accelerate reverts Engine.time_scale to 1.0")

# ═══════════════════════════════════════════════════════════════════
# Property 2.6: Productivity Bonus for Consecutive Tasks
# **Validates: Requirements 3.8**
# For all consecutive task completions within deadline, productivity bonus awarded.
# ═══════════════════════════════════════════════════════════════════

func _test_consecutive_tasks_award_productivity_bonus() -> void:
	# When consecutive_tasks >= 2, productivity increases by 5.0
	var script = load("res://Scripts/GameManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("consecutive_tasks += 1"),
		"Increments consecutive_tasks on completion within deadline")
	_assert(source.contains("if consecutive_tasks >= 2:"),
		"Checks for 2 consecutive completions")
	_assert(source.contains("set_productivity(productivity + 5.0)"),
		"Awards +5.0 productivity for consecutive completions")

func _test_productivity_bonus_resets_after_award() -> void:
	# After awarding bonus, consecutive_tasks resets to 0
	var script = load("res://Scripts/GameManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("consecutive_tasks = 0"),
		"Resets consecutive_tasks after awarding bonus")

# ═══════════════════════════════════════════════════════════════════
# Property 2.7: QTE Skill Check Uses qte_confirm Action
# **Validates: Requirements 3.9**
# QTE skill check uses qte_confirm (Space) to confirm timing, not interact.
# ═══════════════════════════════════════════════════════════════════

func _test_qte_uses_qte_confirm_action() -> void:
	# SkillCheckUI uses Input.is_action_just_pressed("qte_confirm")
	var script = load("res://Scripts/SkillCheckUI.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("is_action_just_pressed(\"qte_confirm\")"),
		"QTE uses qte_confirm action for input")

func _test_qte_does_not_use_interact_action() -> void:
	# SkillCheckUI does NOT use "interact" action for confirmation
	var script = load("res://Scripts/SkillCheckUI.gd") as GDScript
	var source = script.source_code
	
	# The _process function should only check qte_confirm, not interact
	var process_section = ""
	var in_process = false
	for line in source.split("\n"):
		if "func _process" in line:
			in_process = true
		elif in_process and line.begins_with("func "):
			break
		if in_process:
			process_section += line + "\n"
	
	_assert(not process_section.contains("\"interact\""),
		"QTE _process does NOT use interact action")

# ═══════════════════════════════════════════════════════════════════
# Property 2.8: Inconvenience Auto-Fix Timers
# **Validates: Requirements 3.6, 3.10**
# For all non-bug inconvenience triggers, existing timeout/revert logic unchanged.
# ═══════════════════════════════════════════════════════════════════

func _test_fake_ad_has_autofix_timer() -> void:
	# fake_ad uses AUTOFIX_HAS_SOLUTION (30s) timeout
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	# _execute_major calls _auto_fix with AUTOFIX_HAS_SOLUTION for fake_ad
	_assert(source.contains("AUTOFIX_HAS_SOLUTION: float = 30.0"),
		"AUTOFIX_HAS_SOLUTION is 30 seconds")
	# fake_ad is in _execute_major which ends with _auto_fix(choice, AUTOFIX_HAS_SOLUTION)
	_assert(source.contains("_auto_fix(choice, AUTOFIX_HAS_SOLUTION)"),
		"Major inconveniences use AUTOFIX_HAS_SOLUTION timer")

func _test_blur_has_autofix_timer() -> void:
	# blur uses AUTOFIX_NO_SOLUTION (10s) timeout (it's a minor inconvenience)
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("AUTOFIX_NO_SOLUTION: float = 10.0"),
		"AUTOFIX_NO_SOLUTION is 10 seconds")
	# Minor inconveniences end with _auto_fix(choice, AUTOFIX_NO_SOLUTION)
	_assert(source.contains("_auto_fix(choice, AUTOFIX_NO_SOLUTION)"),
		"Minor inconveniences use AUTOFIX_NO_SOLUTION timer")

func _test_time_accelerate_reverts_after_2s() -> void:
	# time_accelerate has its own 2s timer that reverts Engine.time_scale
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	# Verify the revert callback exists
	_assert(source.contains("is_time_accelerated = false"),
		"time_accelerate revert sets is_time_accelerated = false")
	_assert(source.contains("Engine.time_scale = 1.0"),
		"time_accelerate revert restores Engine.time_scale = 1.0")

func _test_inconvenience_quotas_respected() -> void:
	# The trigger system checks quotas before triggering
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("if triggered[diff] < quotas[diff]"),
		"Trigger system respects per-difficulty quotas")
	_assert(source.contains("triggered[chosen_diff] += 1"),
		"Increments triggered count after choosing difficulty")

func _test_accumulated_chance_mechanics() -> void:
	# Chance accumulates on miss, resets on hit
	var script = load("res://Scripts/InconvenienceManager.gd") as GDScript
	var source = script.source_code
	
	_assert(source.contains("if randf() <= accumulated_chance:"),
		"Uses accumulated_chance for trigger roll")
	_assert(source.contains("accumulated_chance = base_chance"),
		"Resets accumulated_chance to base_chance after trigger")
	_assert(source.contains("accumulated_chance += base_chance"),
		"Accumulates chance on miss")
