# Task CTA & Inconvenience Fixes — Bugfix Design

## Overview

This design addresses 10 bugs across two categories in the "Return to Work Plz" Godot 4 game. Category A covers the task CTA system (flashing task bar, incorrect glow, wrong elevator arrow direction). Category B covers inconvenience mechanics (removed Stopped Clock, broken Control Reverse, misplaced Hacker Unpause trigger, incomplete Time Stop blocking, static Text Scramble, incomplete Time Reverse, and unreliable Time Erase). The fix approach is minimal and targeted: each bug is corrected at its root cause without altering unrelated game flow.

## Glossary

- **Bug_Condition (C)**: The set of conditions under which any of the 10 bugs manifest — incorrect CTA flash target, glow on wrong workstation, wrong arrow direction, or broken inconvenience behavior
- **Property (P)**: The desired correct behavior for each bug condition — flash only the arrow, glow only active workstation, show correct directional arrow, and each inconvenience behaving per spec
- **Preservation**: Existing behaviors that must remain unchanged — task slide animations, elevator arrows on different floors, interaction prompts on active workstations, productivity bonuses, QTE confirm action, and other inconvenience timings
- **HUD.gd**: The script at `Scripts/HUD.gd` that manages the task bar UI, direction arrow, and CTA flash tween
- **InteractableObject.gd**: The script at `Scripts/InteractableObject.gd` that manages workstation interaction, glow highlight, and task completion
- **InconvenienceManager.gd**: The autoload at `Scripts/InconvenienceManager.gd` that manages all inconvenience triggers, execution, and auto-fix timers
- **GameManager.gd**: The autoload at `Scripts/GameManager.gd` that tracks task flow, objectives, and loop state
- **PauseMenu.gd**: The script at `Scripts/PauseMenu.gd` that handles pause logic and keybind settings

## Bug Details

### Bug Condition

The bugs manifest across multiple subsystems. The compound bug condition is:

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type GameState (current HUD state, workstation state, inconvenience state)
  OUTPUT: boolean
  
  RETURN (input.directionArrowVisible AND input.ctaFlashTarget == "task_bg")
         OR (input.workstationGlowActive AND NOT GameManager.is_task_active(input.workstation.task_id))
         OR (input.playerFloor == input.targetFloor AND input.arrowShows == "up/down")
         OR (input.inconvenience == "clock_stop" AND input.isInPool)
         OR (input.inconvenience == "keybind" AND input.onlySwapsLeftRight)
         OR (input.inconvenience == "unpause_hack" AND input.triggeredFrom == "objective_completed")
         OR (input.inconvenience == "time_stop" AND input.promptVisibleBeforePress)
         OR (input.inconvenience == "gibberish" AND input.usesStaticString)
         OR (input.inconvenience == "time_reverse" AND NOT input.workstationResetInScene)
         OR (input.inconvenience == "time_erase" AND NOT input.triggerPathWorksEndToEnd)
END FUNCTION
```

### Examples

- **Bug 1**: Player is in Lobby (F1), task is "Make coffee" in Lounge (F2). Direction arrow shows and `task_bg` flashes between alpha 0.4–1.0. Expected: only the arrow label flashes, task bar stays solid.
- **Bug 2**: Player enters Cubicle_Middle room. The "type_report" workstation glows yellow even though current task is "clock_in". Expected: no glow on non-active workstations.
- **Bug 3**: Player is on Floor 2 at Slot_F2_Right (Meeting). Task target is Lounge at Slot_F2_Left. Arrow shows "↓" (elevator direction). Expected: arrow shows "←" pointing left toward Lounge.
- **Bug 5**: "keybind" inconvenience fires. Only move_left and move_right swap. Expected: all remappable keys (move_left, move_right, interact, qte_confirm) get randomized assignments.
- **Bug 7**: "time_stop" is active. Player walks to workstation, sees "Press [E] - Make coffee" prompt. Only after pressing E does it show "[TIME FROZEN]". Expected: prompt shows "[TIME FROZEN]" immediately (or is hidden) without requiring E press.
- **Bug 8**: "gibberish" activates. All labels show `"!@#$%^&*()_+"` regardless of original length. Expected: each label gets a random string of matching length using random characters.
- **Bug 9**: "time_reverse" fires. GameManager decrements task index, but the workstation in the scene still has `task_completed = true`. Player cannot re-interact. Expected: workstation's `task_completed` resets to false.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Task label slide-out animation on completion (`_animate_task_complete()`) must continue working
- Direction arrow hidden when player is in the same room as the active task
- Direction arrow shows up/down when player is in elevator and task is on different floor
- Direction arrow points toward elevator when task is on a different floor (and player is not in elevator)
- "Press [E]" prompt and interaction on the active task workstation must continue working
- Inconvenience trigger chance system (accumulated chance, quotas, difficulty tiers) must remain intact
- `time_accelerate` inconvenience (Engine.time_scale = 4.0 for 2s) must remain unchanged
- Productivity bonuses for consecutive task completions must remain unchanged
- QTE skill check uses `qte_confirm` action (Space by default) — must continue working
- `fake_ad` and `blur` inconveniences display and auto-fix per existing timeout logic
- Loop restart resets all permanent inconveniences

**Scope:**
All game states that do NOT involve the 10 specific bug conditions should be completely unaffected by these fixes. This includes:
- Normal task progression when player is in the correct room
- Mouse/keyboard interaction with non-task UI elements
- NPC talk tracking and auto-complete logic
- Room shuffling and special room injection
- Save/load settings functionality

## Hypothesized Root Cause

Based on the bug analysis and code review:

1. **CTA Flash Target (Bug 1)**: In `HUD._start_cta_flash()`, the tween targets `task_bg` (the task bar background) instead of `direction_arrow`. The flash should animate `direction_arrow.modulate:a` not `task_bg.modulate:a`.

2. **Glow on Non-Active Workstations (Bug 2)**: In `InteractableObject._update_prompt()`, the `_start_glow()` call is made unconditionally at the end of the else branch (when task is NOT available). The glow should only start when `_is_available()` returns true, and `_stop_glow()` should be called otherwise.

3. **Wrong Arrow Direction on Same Floor (Bug 3)**: In `HUD._update_direction_arrow()`, the logic checks `target_floor != RoomManager.current_floor` to decide elevator direction, but when the player IS on the correct floor, the code falls through to the "same floor" section. The issue is that `target_floor` is determined by checking `f1_slots` and `f2_slots` arrays, but if the target slot is not found in either (e.g., dynamically added slots), `target_floor` stays 0 and the wrong branch executes. Additionally, the current code correctly handles same-floor navigation, so the real issue may be that `target_slot` lookup fails for rooms in dynamically shuffled layouts — need to verify the slot-to-room mapping after shuffles.

4. **Stopped Clock Removal (Bug 4)**: The `is_clock_stopped` variable, its check in `HUD._process()`, and the `"clock_stop"` case in `_revert_inconvenience()` and `_execute_minor()` are dead code. They should be removed entirely since "clock_stop" is not in the active minor pool but the flag still exists.

5. **Control Reverse Only Swaps L/R (Bug 5)**: In `_execute_medium("keybind")`, the code explicitly only swaps `move_left` and `move_right` events. It should instead collect all remappable actions, shuffle their key assignments, and redistribute them randomly. The `qte_confirm` action also needs to be added to the remappable set.

6. **Hacker Unpause Trigger Location (Bug 6)**: The `unpause_hack` case exists in `_execute_medium()` which is called from `_trigger_random_inconvenience()` (fired on objective completion). It should ONLY trigger from `try_pause_inconvenience()` (called by PauseMenu when player pauses). The medium pool entry should be removed.

7. **Time Stop Incomplete Blocking (Bug 7)**: In `InteractableObject._input()`, the `is_time_stopped` check only fires after the player presses E. The `_update_prompt()` function doesn't check `is_time_stopped` to hide/modify the prompt preemptively.

8. **Text Scramble Static String (Bug 8)**: In `_scramble_all_labels()`, every label is set to the literal `"!@#$%^&*()_+"` regardless of original text length. It should generate a random string of the same length as the original text.

9. **Time Reverse Missing Workstation Reset (Bug 9)**: `GameManager.reverse_last_task()` decrements `current_task_index` and marks the objective incomplete, but doesn't signal or directly reset the `InteractableObject.task_completed` flag. The `_on_task_changed` handler in InteractableObject DOES reset `task_completed` if the task becomes active again — but only if `player_in_range` is true for the prompt update. The actual reset logic exists but the glow/visual state may not update if the player isn't in range.

10. **Time Erase Trigger Path (Bug 10)**: The `time_erase` choice is in the MAJOR pool and sets `is_time_erased = true` with a 7s auto-fix. The `InteractableObject.on_interact_complete()` checks `is_time_erased` and prevents `complete_objective()`. The trigger path appears correct but needs verification that the flag is properly set before the player can complete a task (race condition with attack sequence animation).

## Correctness Properties

Property 1: Bug Condition - CTA Flash Targets Direction Arrow Only

_For any_ game state where the direction arrow CTA is visible (player not in task room, task has a specific room target), the `_start_cta_flash()` function SHALL animate only the `direction_arrow` label's alpha, NOT the `task_bg` TextureRect's alpha.

**Validates: Requirements 2.1**

Property 2: Bug Condition - Glow Only On Active Workstation

_For any_ workstation in the scene where `task_id` does NOT match `GameManager.get_current_task_id()`, the workstation SHALL NOT display the yellow highlight glow. The glow SHALL only be active on the workstation whose task matches the current active task.

**Validates: Requirements 2.2**

Property 3: Bug Condition - Same-Floor Arrow Shows Horizontal Direction

_For any_ game state where the player is on the same floor as the task target room but in a different slot, the direction arrow SHALL show "←" or "→" pointing toward the target room's slot position, NOT "↑" or "↓".

**Validates: Requirements 2.3**

Property 4: Bug Condition - Stopped Clock Fully Removed

_For any_ build of the game after the fix, there SHALL be no `is_clock_stopped` variable, no `"clock_stop"` case in execute/revert functions, and no HUD freeze logic referencing stopped clock state.

**Validates: Requirements 2.4**

Property 5: Bug Condition - Control Reverse Randomizes All Remappable Keys

_For any_ trigger of the "keybind" inconvenience, the system SHALL randomly redistribute key assignments across ALL remappable actions (move_left, move_right, interact, qte_confirm), not just swap two of them.

**Validates: Requirements 2.5**

Property 6: Bug Condition - Hacker Unpause Only Triggers On Pause Action

_For any_ task completion event, the system SHALL NOT trigger the "unpause_hack" inconvenience. The unpause hack SHALL only be triggered when the player presses the pause key, via `try_pause_inconvenience()`.

**Validates: Requirements 2.6**

Property 7: Bug Condition - Time Stop Blocks Prompt Immediately

_For any_ game state where `is_time_stopped` is true and the player enters a workstation's detection area, the prompt SHALL immediately show "[TIME FROZEN]" or be hidden entirely, WITHOUT requiring the player to press E first.

**Validates: Requirements 2.7**

Property 8: Bug Condition - Text Scramble Uses Random Characters

_For any_ label affected by the "gibberish" inconvenience, the replacement text SHALL be a random string of the SAME LENGTH as the original text, composed of random uppercase/lowercase letters and symbols, NOT the static string `"!@#$%^&*()_+"`.

**Validates: Requirements 2.8**

Property 9: Bug Condition - Time Reverse Resets Workstation State

_For any_ trigger of the "time_reverse" inconvenience, the system SHALL reset the corresponding `InteractableObject.task_completed` flag to false in the current scene, making the workstation interactable again regardless of whether the player is currently in range.

**Validates: Requirements 2.9**

Property 10: Bug Condition - Time Erase Triggers Correctly From Pool

_For any_ trigger of the "time_erase" inconvenience from the MAJOR pool, the system SHALL correctly set `is_time_erased = true` before the player can interact, the flag SHALL persist for 7 seconds, and any task completed during that window SHALL NOT count toward objective progress.

**Validates: Requirements 2.10**

Property 11: Preservation - Existing Task Flow and UI Animations

_For any_ input where none of the 10 bug conditions hold (normal task completion, normal room navigation, normal inconvenience triggers), the fixed code SHALL produce the same behavior as the original code, preserving task slide animations, elevator arrows, interaction prompts, productivity bonuses, and all unaffected inconvenience mechanics.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `Scripts/HUD.gd`

**Function**: `_start_cta_flash()` / `_stop_cta_flash()`

**Specific Changes**:
1. **Flash target change**: Replace `task_bg` with `direction_arrow` in the tween property calls inside `_start_cta_flash()`. The tween should animate `direction_arrow.modulate:a` between 0.4 and 1.0.
2. **Stop flash cleanup**: In `_stop_cta_flash()`, reset `direction_arrow.modulate.a = 1.0` instead of `task_bg.modulate.a = 1.0`.
3. **Remove task_bg flash reset**: Remove the `task_bg.modulate.a = 1.0` line from `_stop_cta_flash()` (task_bg should never have its alpha modified by the CTA system).

---

**File**: `Scripts/InteractableObject.gd`

**Function**: `_update_prompt()`

**Specific Changes**:
4. **Conditional glow**: In the `else` branch of `_update_prompt()` (when task is NOT available), replace `_start_glow()` with `_stop_glow()`. The glow should only start in the `if _is_available()` branch.
5. **Time Stop prompt**: Add a check for `InconvenienceManager.is_time_stopped` at the top of `_update_prompt()`. If time is stopped and the task is available, show "[TIME FROZEN]" as the prompt text and do NOT call `_start_glow()`.

---

**File**: `Scripts/HUD.gd`

**Function**: `_update_direction_arrow()`

**Specific Changes**:
6. **Same-floor arrow fix**: The existing same-floor logic appears correct (it uses `_set_arrow_side(target_idx < cur_idx)`). The bug likely occurs when `target_floor` is computed as 0 because the target slot isn't found in either `f1_slots` or `f2_slots` (can happen with dynamically added special slots). Add a guard: if `target_floor == 0`, hide the arrow and return. Also verify the Cubicle task room mapping — "Cubicle" tasks can be in multiple slots (Cubicle_Left, Cubicle_Middle, Cubicle_Right), and the code already returns early for "Cubicle" room type, so this is handled.

---

**File**: `Scripts/InconvenienceManager.gd`

**Functions**: Multiple

**Specific Changes**:
7. **Remove Stopped Clock**: Delete `is_clock_stopped` variable declaration, remove `"clock_stop"` from `_execute_minor()`, remove `"clock_stop"` case from `_revert_inconvenience()`, remove `is_clock_stopped = false` from `_reset_permanent_inconveniences()`.

8. **Remove clock_stop from HUD**: In `HUD._process()`, remove the `if InconvenienceManager.is_clock_stopped:` branch.

9. **Control Reverse randomization**: In `_execute_medium("keybind")`, replace the simple left/right swap with a full randomization:
   - Collect current key events for all remappable actions (move_left, move_right, interact, qte_confirm)
   - Shuffle the collected events array
   - Reassign shuffled events to actions in order
   - Update keybind button display text for all affected actions
   - Exclude ESC and numpad keys from the random pool

10. **Add qte_confirm to keybind system**: In `PauseMenu.gd`, add `"qte_confirm"` to `keybind_actions` array and `keybind_display_names` dictionary (display as "QTE Confirm"). Update save/load to include it.

11. **Remove unpause_hack from medium pool**: Remove `"unpause_hack"` from the `Difficulty.MEDIUM` pick_random array in `_trigger_random_inconvenience()`. The unpause hack is already correctly triggered via `try_pause_inconvenience()` called from `PauseMenu._pause()`.

12. **Time Stop prompt blocking**: In `InteractableObject._update_prompt()`, when `_is_available()` is true, check `InconvenienceManager.is_time_stopped` first. If stopped, set prompt to "[TIME FROZEN]", show it, and do NOT start glow. Do not allow interaction.

13. **Text Scramble randomization**: Replace the static `"!@#$%^&*()_+"` assignment in `_scramble_all_labels()` with a function that generates a random string of the same length as the original text, using characters from a pool of uppercase letters, lowercase letters, and symbols (`@#$%^&*!?~`).

14. **Time Reverse workstation reset**: After `GameManager.reverse_last_task()` is called, emit a signal or directly find all `InteractableObject` nodes in the current scene whose `task_id` matches the reversed task and set their `task_completed = false`. The existing `_on_task_changed` signal handler in InteractableObject already does this check — verify it fires correctly by ensuring `current_task_changed` is emitted (it already is in `reverse_last_task()`). The issue is that `_on_task_changed` only resets `task_completed` if `GameManager.is_task_active(task_id)` — which should be true after reversal. Confirm this path works; if not, add explicit workstation reset via group query.

15. **Time Erase verification**: The trigger path appears correct. Verify that `AttackSequenceManager.sequence_finished` fires before the player can reach a workstation. If the attack animation takes time, the flag is set in `_execute_major()` which runs after the sequence finishes — this means `is_time_erased` IS set before interaction. The implementation looks correct; add a print statement for debugging and ensure the auto-fix timer uses `process_always` mode so it works even if tree is paused.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write GDScript test scenes or manual test procedures that reproduce each bug condition. Run on UNFIXED code to observe failures.

**Test Cases**:
1. **CTA Flash Target Test**: Navigate to a room different from the task target. Observe that `task_bg.modulate.a` oscillates (will fail on unfixed code — it should be `direction_arrow`)
2. **Glow on Wrong Workstation Test**: Enter a room with a non-active workstation. Observe yellow glow appears (will fail on unfixed code)
3. **Same-Floor Arrow Test**: Stand on Floor 2 at Meeting (Slot_F2_Right), with task in Lounge (Slot_F2_Left). Observe arrow shows "↓" instead of "←" (will fail on unfixed code)
4. **Keybind Randomization Test**: Trigger "keybind" inconvenience. Check that only move_left/move_right swap (will fail on unfixed code — should randomize all)
5. **Time Stop Prompt Test**: Activate time_stop, walk to workstation. Observe prompt shows normal text until E is pressed (will fail on unfixed code)
6. **Gibberish Static Test**: Trigger gibberish. Observe all labels show same static string regardless of length (will fail on unfixed code)
7. **Time Reverse Workstation Test**: Complete a task, trigger time_reverse, return to workstation. Observe it's still marked complete (will fail on unfixed code if player wasn't in range)

**Expected Counterexamples**:
- CTA flash animates wrong element (task_bg instead of direction_arrow)
- Glow starts unconditionally in `_update_prompt()` else branch
- Arrow direction logic falls through incorrectly for same-floor targets
- Keybind swap is hardcoded to only two actions

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixedSystem(input)
  ASSERT expectedBehavior(result)
END FOR
```

Specifically:
- Assert `direction_arrow.modulate.a` oscillates (not `task_bg`)
- Assert glow is off for non-active workstations
- Assert horizontal arrow on same floor
- Assert no `is_clock_stopped` references exist
- Assert all 4 actions get randomized keys on keybind trigger
- Assert unpause_hack not in medium pool
- Assert prompt shows "[TIME FROZEN]" without E press
- Assert scrambled text length matches original and uses random chars
- Assert workstation `task_completed` resets on time_reverse
- Assert `is_time_erased` blocks objective completion for 7s

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalSystem(input) = fixedSystem(input)
END FOR
```

**Testing Approach**: Manual and automated testing to verify:
- Task completion still triggers slide animation
- Arrow hides when in same room as task
- Arrow shows up/down in elevator correctly
- Active workstation still shows prompt and allows interaction
- Other inconveniences (fake_ad, blur, time_accelerate) work unchanged
- Productivity bonuses still awarded for consecutive completions
- QTE skill check still uses qte_confirm/Space

**Test Cases**:
1. **Task Animation Preservation**: Complete a task normally, verify slide-out and slide-in animations play
2. **Elevator Arrow Preservation**: Enter elevator with task on different floor, verify up/down arrow shows correctly
3. **Active Workstation Interaction Preservation**: Stand near active workstation, verify "Press [E]" prompt appears and interaction works
4. **Other Inconvenience Preservation**: Trigger time_accelerate, verify 4x speed for 2s then revert
5. **QTE Preservation**: Start a skill check, verify Space (qte_confirm) still works as confirm

### Unit Tests

- Test `_start_cta_flash()` targets `direction_arrow` not `task_bg`
- Test `_update_prompt()` calls `_stop_glow()` for non-active workstations
- Test `_update_direction_arrow()` returns horizontal arrow for same-floor targets
- Test keybind randomization produces different assignments for all 4 actions
- Test `_scramble_all_labels()` produces random strings of correct length
- Test `reverse_last_task()` triggers workstation reset via signal

### Property-Based Tests

- Generate random floor/slot combinations and verify arrow direction is always correct (horizontal for same floor, vertical for elevator, toward-elevator for different floor)
- Generate random sets of 4 key assignments and verify keybind randomization produces valid permutations (no duplicates, no ESC, no numpad)
- Generate random label texts of varying lengths and verify scrambled output has same length and uses only allowed characters
- Generate random task sequences and verify time_reverse always resets the correct workstation

### Integration Tests

- Full game flow: complete tasks 1-3, trigger time_reverse, verify task 3 workstation is interactable again
- Full game flow: trigger keybind inconvenience, verify all 4 actions have new keys, verify settings UI shows correct bindings
- Full game flow: trigger time_stop, walk to workstation, verify "[TIME FROZEN]" shows without pressing E
- Full game flow: trigger gibberish, verify all labels show random text of correct length, verify unscramble restores originals
- Full game flow: navigate between rooms on same floor, verify arrow always points correct horizontal direction
