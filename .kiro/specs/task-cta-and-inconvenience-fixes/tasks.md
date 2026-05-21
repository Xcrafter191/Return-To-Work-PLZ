# Implementation Plan

## Overview

This task list implements fixes for 10 bugs across the Task CTA system and Inconvenience mechanics, plus a new admin/debug panel for testing inconveniences in "Return to Work Plz". The workflow follows the bug condition methodology: first write exploration tests to confirm bugs exist, then write preservation tests to capture baseline behavior, then implement fixes, and finally verify all tests pass.

## Tasks

- [~] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Task CTA & Inconvenience Defects
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fixes when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bugs exist across all 10 conditions
  - **Scoped PBT Approach**: Scope properties to concrete failing cases for each bug:
    - Bug 1 (CTA Flash): Verify `_start_cta_flash()` animates `direction_arrow.modulate:a` NOT `task_bg.modulate:a`. Counterexample: call `_start_cta_flash()` and assert tween target is `direction_arrow` — will fail because it targets `task_bg`
    - Bug 2 (Glow): Create workstation with `task_id != GameManager.get_current_task_id()`, call `_update_prompt()`, assert `_start_glow()` is NOT called — will fail because glow starts unconditionally
    - Bug 3 (Arrow): Set player on Floor 2 at Slot_F2_Right, task target at Slot_F2_Left, call `_update_direction_arrow()`, assert arrow text is "←" not "↓" — will fail on unfixed code
    - Bug 5 (Keybind): Trigger "keybind" inconvenience, assert all 4 actions (move_left, move_right, interact, qte_confirm) have randomized keys — will fail because only move_left/move_right swap
    - Bug 7 (Time Stop): Set `is_time_stopped = true`, simulate player entering workstation range, assert prompt shows "[TIME FROZEN]" without E press — will fail because prompt only changes after E
    - Bug 8 (Gibberish): Trigger gibberish on labels of varying lengths, assert each scrambled label length matches original and is NOT the static string `"!@#$%^&*()_+"` — will fail because all labels get same static string
    - Bug 9 (Time Reverse): Complete a task, call `reverse_last_task()`, assert workstation `task_completed == false` — will fail because workstation state is not reset
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bugs exist)
  - Document counterexamples found to understand root causes
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.7, 1.8, 1.9_

- [~] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Existing Task Flow, UI Animations & Unaffected Mechanics
  - **IMPORTANT**: Follow observation-first methodology
  - Observe on UNFIXED code for non-buggy inputs (cases where isBugCondition returns false):
    - Observe: Complete a task normally → slide-out animation plays, next task slides in
    - Observe: Stand in same room as active task → direction arrow is hidden
    - Observe: Enter elevator with task on different floor → arrow shows ↑ or ↓ correctly
    - Observe: Stand near active workstation → "Press [E]" prompt appears, interaction works
    - Observe: Trigger `time_accelerate` → Engine.time_scale = 4.0 for 2s then reverts
    - Observe: Complete tasks consecutively → productivity bonus awarded
    - Observe: QTE skill check active → Space (qte_confirm) confirms timing
    - Observe: Trigger `fake_ad` or `blur` → displays and auto-fixes per timeout
    - Observe: Debug panel not active → no debug UI visible, game behaves normally
  - Write property-based tests capturing observed behavior patterns:
    - For all normal task completions, `_animate_task_complete()` is called and animation plays
    - For all states where player is in task room, direction arrow is hidden
    - For all elevator states with task on different floor, arrow shows correct vertical direction
    - For all active workstation interactions, prompt shows and interaction succeeds
    - For all `time_accelerate` triggers, time_scale is 4.0 for exactly 2s
    - For all non-bug inconvenience triggers, existing timeout/revert logic is unchanged
    - For all states where debug flag is disabled, no debug panel is visible
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

- [ ] 3. Fix for Task CTA & Inconvenience Bugs

  - [x] 3.1 Fix CTA flash target (Bug 1)
    - In `Scripts/HUD.gd` → `_start_cta_flash()`: change tween target from `task_bg` to `direction_arrow`
    - Animate `direction_arrow.modulate:a` between 0.4 and 1.0 (not `task_bg.modulate:a`)
    - In `_stop_cta_flash()`: reset `direction_arrow.modulate.a = 1.0` instead of `task_bg.modulate.a = 1.0`
    - Remove any `task_bg.modulate.a` manipulation from CTA flash logic
    - _Bug_Condition: isBugCondition(input) where input.directionArrowVisible AND input.ctaFlashTarget == "task_bg"_
    - _Expected_Behavior: Flash only direction_arrow label alpha, task_bg stays solid_
    - _Preservation: Task slide animations, arrow hide in same room_
    - _Requirements: 2.1, 3.1, 3.2_

  - [~] 3.2 Fix glow on non-active workstations (Bug 2)
    - In `Scripts/InteractableObject.gd` → `_update_prompt()`: in the `else` branch (task NOT available), replace `_start_glow()` with `_stop_glow()`
    - Ensure glow only starts in the `if _is_available()` branch
    - _Bug_Condition: isBugCondition(input) where input.workstationGlowActive AND NOT GameManager.is_task_active(input.workstation.task_id)_
    - _Expected_Behavior: Glow only on workstation matching current active task_
    - _Preservation: Active workstation prompt and interaction unchanged_
    - _Requirements: 2.2, 3.5_

  - [~] 3.3 Fix same-floor arrow direction (Bug 3)
    - In `Scripts/HUD.gd` → `_update_direction_arrow()`: add guard for `target_floor == 0` (slot not found) — hide arrow and return
    - Verify same-floor logic correctly uses `_set_arrow_side(target_idx < cur_idx)` for horizontal arrows
    - Verify dynamically shuffled slot mappings are accounted for
    - _Bug_Condition: isBugCondition(input) where input.playerFloor == input.targetFloor AND input.arrowShows == "up/down"_
    - _Expected_Behavior: Arrow shows ← or → for same-floor targets_
    - _Preservation: Elevator arrows (↑/↓) still work for different-floor targets_
    - _Requirements: 2.3, 3.3, 3.4_

  - [~] 3.4 Remove Stopped Clock dead code (Bug 4)
    - In `Scripts/InconvenienceManager.gd`: delete `is_clock_stopped` variable declaration
    - Remove `"clock_stop"` case from `_execute_minor()`
    - Remove `"clock_stop"` case from `_revert_inconvenience()`
    - Remove `is_clock_stopped = false` from `_reset_permanent_inconveniences()`
    - In `Scripts/HUD.gd` → `_process()`: remove the `if InconvenienceManager.is_clock_stopped:` branch
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "clock_stop" AND input.isInPool_
    - _Expected_Behavior: No clock_stop references exist in codebase_
    - _Preservation: Other inconvenience timings unchanged_
    - _Requirements: 2.4, 3.6_

  - [x] 3.5 Fix Control Reverse randomization (Bug 5)
    - In `Scripts/InconvenienceManager.gd` → `_execute_medium("keybind")`: replace left/right swap with full randomization
    - Collect current key events for all remappable actions: move_left, move_right, interact, qte_confirm
    - Shuffle collected events array and reassign to actions in random order
    - Update keybind button display text for all affected actions
    - Exclude ESC and numpad keys from the random pool
    - In `Scripts/PauseMenu.gd`: add `"qte_confirm"` to `keybind_actions` array and `keybind_display_names` (display: "QTE Confirm")
    - Ensure "QTE Confirm" has a visible, rebindable row in the Settings → Keybinds UI screen
    - Update save/load settings to include qte_confirm binding
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "keybind" AND input.onlySwapsLeftRight_
    - _Expected_Behavior: All 4 remappable actions get randomized key assignments_
    - _Preservation: QTE skill check still uses qte_confirm action_
    - _Requirements: 2.5, 3.9_

  - [~] 3.6 Fix Hacker Unpause trigger location (Bug 6)
    - In `Scripts/InconvenienceManager.gd` → `_trigger_random_inconvenience()`: remove `"unpause_hack"` from the `Difficulty.MEDIUM` pick_random array
    - Verify `try_pause_inconvenience()` (called from PauseMenu) still correctly triggers unpause_hack
    - Verify chance scales with loop number as specified
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "unpause_hack" AND input.triggeredFrom == "objective_completed"_
    - _Expected_Behavior: unpause_hack only triggers from pause action, never from task completion_
    - _Preservation: Other medium inconveniences still trigger from task completion pool_
    - _Requirements: 2.6, 3.6_

  - [~] 3.7 Fix Time Stop prompt blocking (Bug 7)
    - In `Scripts/InteractableObject.gd` → `_update_prompt()`: when `_is_available()` is true, check `InconvenienceManager.is_time_stopped` FIRST
    - If time is stopped: set prompt text to "[TIME FROZEN]", show prompt, do NOT call `_start_glow()`, do NOT allow interaction
    - Player should see "[TIME FROZEN]" immediately upon entering workstation range without pressing E
    - Ensure deadline timer keeps running during time_stop (verify `GameManager._process()` does not pause timer)
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "time_stop" AND input.promptVisibleBeforePress_
    - _Expected_Behavior: Prompt shows "[TIME FROZEN]" immediately, no E press required, timer keeps running_
    - _Preservation: Normal workstation interaction unchanged when time_stop is not active_
    - _Requirements: 2.7, 3.5_

  - [~] 3.8 Fix Text Scramble randomization (Bug 8)
    - In `Scripts/InconvenienceManager.gd` → `_scramble_all_labels()`: replace static `"!@#$%^&*()_+"` with random string generation
    - Generate random string of same length as original label text
    - Use character pool: uppercase letters (A-Z), lowercase letters (a-z), and symbols (@#$%^&*!?~)
    - Each character in the replacement string should be independently randomized
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "gibberish" AND input.usesStaticString_
    - _Expected_Behavior: Each label gets unique random string matching original length_
    - _Preservation: Unscramble (revert) still restores original text correctly_
    - _Requirements: 2.8_

  - [~] 3.9 Fix Time Reverse workstation reset (Bug 9)
    - In `Scripts/InconvenienceManager.gd` or `Scripts/GameManager.gd`: after `reverse_last_task()` is called, ensure workstation `task_completed` resets
    - Verify `current_task_changed` signal is emitted in `reverse_last_task()` (it already is)
    - Verify `InteractableObject._on_task_changed()` resets `task_completed` when `GameManager.is_task_active(task_id)` returns true
    - If the signal path doesn't work for out-of-range workstations: add explicit group query to find all InteractableObjects with matching task_id and reset their `task_completed = false`
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "time_reverse" AND NOT input.workstationResetInScene_
    - _Expected_Behavior: Workstation task_completed resets to false, becomes interactable again_
    - _Preservation: Normal task progression and completion state unchanged_
    - _Requirements: 2.9, 3.1_

  - [~] 3.10 Verify and fix Time Erase trigger path (Bug 10)
    - Verify `is_time_erased = true` is set in `_execute_major()` after attack sequence finishes
    - Verify `InteractableObject.on_interact_complete()` checks `is_time_erased` and prevents `complete_objective()`
    - Verify auto-fix timer (7s) uses `process_always` mode so it works even if tree is paused
    - Verify flag is set BEFORE player can reach a workstation (no race condition with attack animation)
    - If race condition exists: add a guard in `on_interact_complete()` that also checks timing
    - Ensure workstation resets to allow retry when task completion is blocked
    - Add debug logging to confirm trigger path works end-to-end
    - _Bug_Condition: isBugCondition(input) where input.inconvenience == "time_erase" AND NOT input.triggerPathWorksEndToEnd_
    - _Expected_Behavior: is_time_erased blocks objective completion for 7s, then auto-reverts_
    - _Preservation: Other major inconveniences unchanged_
    - _Requirements: 2.10, 3.6_

  - [~] 3.11 Implement admin/debug panel for inconvenience testing (Feature)
    - Create a new debug panel UI scene (e.g., `Scenes/DebugPanel.tscn`) with a dropdown listing ALL inconveniences
    - Add a debug flag (e.g., `GameManager.debug_mode`) that controls panel visibility
    - Implement a key combo (e.g., Ctrl+Shift+D) to toggle the debug panel
    - Selecting an inconvenience from the dropdown SHALL immediately trigger it as if rolled from the pool
    - Panel must list all inconveniences: time_accelerate, fake_ad, blur, gibberish, keybind, unpause_hack, time_stop, time_reverse, time_erase
    - When debug flag is disabled, panel is completely hidden and game behaves identically to release build
    - _Expected_Behavior: Developer can manually trigger any inconvenience from a dropdown panel_
    - _Preservation: When debug panel is not active, game behaves identically to release build_
    - _Requirements: 2.11, 3.11_

  - [~] 3.12 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Task CTA & Inconvenience Defects Fixed
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior for all 10 bug conditions
    - When this test passes, it confirms all expected behaviors are satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms all bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [~] 3.13 Verify preservation tests still pass
    - **Property 2: Preservation** - Existing Task Flow, UI Animations & Unaffected Mechanics
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions introduced)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

- [~] 4. Checkpoint - Ensure all tests pass
  - Run full test suite (exploration + preservation tests)
  - Verify all 10 bug conditions are resolved
  - Verify admin/debug panel works correctly and is hidden when disabled
  - Verify no regressions in preserved behaviors
  - Manual playtest: complete 3-4 tasks, trigger inconveniences, verify correct behavior
  - Ensure all tests pass, ask the user if questions arise.


## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3.2", "3.3", "3.4", "3.6", "3.7", "3.8", "3.9", "3.10", "3.11"] },
    { "id": 2, "tasks": ["3.12"] },
    { "id": 3, "tasks": ["3.13"] },
    { "id": 4, "tasks": ["4"] }
  ]
}
```

## Notes

- Tasks 1 and 2 can be done in parallel since they are independent
- All implementation sub-tasks (3.1–3.11) can be done in parallel after tasks 1 and 2 complete
- Verification tasks (3.12, 3.13) must run after all implementation is complete
- This is a Godot 4 GDScript project — tests may be manual test scenes or GUT framework tests
- Bug 4 (Stopped Clock removal) is low-risk dead code removal
- Bug 10 (Time Erase) primarily requires verification of existing trigger path
- Task 3.11 (Debug Panel) is a new feature addition, not a bug fix — it supports developer testing of all inconveniences
- The "qte_confirm" action addition (task 3.5) requires both InputMap and Settings UI changes
