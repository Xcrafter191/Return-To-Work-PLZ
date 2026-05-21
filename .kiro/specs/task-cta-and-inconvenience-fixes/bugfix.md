# Bugfix Requirements Document

## Introduction

This document addresses multiple bugs in the "Return to Work Plz" Godot 4 game affecting the task CTA system and the inconvenience mechanics. The bugs fall into two categories:

**Category A — Task UI & Navigation:**
- Task bar (top-right) incorrectly flashes when the direction arrow CTA is active
- Yellow hitbox glow appears on non-active (skipped) task workstations
- Elevator direction arrow shows incorrect direction when player is already on the correct floor
- Arrow sprite direction rotations are inverted (all directions point the wrong way)
- QTE tutorial overlay is broken (wrong size, wrong position, no background dim)

**Category B — Inconvenience Mechanics:**
- "Stopped Clock" inconvenience should be removed entirely
- Control Reverse only swaps left/right instead of randomizing all remappable keys
- Hacker Unpause triggers on task completion instead of on player pause action
- Time Stop does not keep the deadline timer running and does not fully block task interaction
- Text Scramble always uses the same static string instead of random characters
- Time Reverse does not undo workstation completion state in the scene
- Time Erase may not trigger correctly from the inconvenience pool

**Category C — Developer Tooling:**
- No admin/debug panel exists to manually trigger and test individual inconveniences

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the direction arrow CTA is active (player not in the task room) THEN the system flashes the `task_bg` TextureRect (task bar background) alpha between 0.4 and 1.0 via `_start_cta_flash()`

1.2 WHEN a task workstation's `_update_prompt()` is called and the task is NOT the currently active task THEN the system still calls `_start_glow()` which starts the yellow highlight rectangle flashing on that workstation

1.3 WHEN the player is on the same floor as the task target room (e.g. player on Floor 2 and task is "make coffee" in the Lounge on Floor 2) THEN the elevator direction arrow incorrectly points down (↓) to Floor 1 because the arrow logic incorrectly determines the target floor — it shows an up/down elevator arrow even though no floor change is needed

1.4 WHEN the "Stopped Clock" inconvenience variable `is_clock_stopped` is set to true THEN the system freezes the deadline timer display text but the variable and reset logic still exist in the codebase as dead/unused code (it is not in the active minor pool but the flag and revert logic remain)

1.5 WHEN the "keybind" inconvenience triggers THEN the system only swaps `move_left` and `move_right` events instead of randomizing the mapping of all remappable input actions

1.6 WHEN a task objective is completed (`_on_objective_completed`) THEN the system rolls a chance to trigger the "unpause_hack" inconvenience from the medium pool, instead of only triggering it when the player attempts to pause

1.7 WHEN the "time_stop" inconvenience is active THEN the system blocks task interaction via `is_time_stopped` check in `InteractableObject._input()`, but the deadline timer in `GameManager._process()` does not explicitly account for time stop (it keeps running, which is correct) — however the player CAN still move to a workstation and see the prompt, and the `[TIME FROZEN]` text only appears after pressing E

1.8 WHEN the "gibberish" (text scramble) inconvenience activates THEN the system replaces ALL label text with the static string `"!@#$%^&*()_+"` instead of generating a random mix of alphabet characters and symbols per label

1.9 WHEN the "time_reverse" inconvenience triggers THEN the system calls `GameManager.reverse_last_task()` which decrements `current_task_index` and marks the objective as incomplete, but does NOT reset the corresponding `InteractableObject.task_completed` flag in the current scene — the workstation remains visually "done" and non-interactable

1.10 WHEN the "time_erase" inconvenience is supposed to trigger from the MAJOR pool THEN the system may fail to activate because the `is_time_erased` flag is set but the `InteractableObject.on_interact_complete()` check only prevents the `GameManager.complete_objective()` call — need to verify the trigger path works end-to-end and the flag resets correctly

1.11 WHEN a developer wants to test a specific inconvenience in isolation THEN the system provides no admin/debug panel to manually select and trigger individual inconveniences — the only way to test them is to play through the game and hope the random pool selects the desired one

1.12 WHEN the Arrow_Sprite (ARROW.png) is displayed on the HUD THEN ALL rotations are inverted — up points down, down points up, left points right, right points left — because the rotation degrees are backwards

1.13 WHEN the Skill Check tutorial appears for the first time THEN the tutorial overlay renders as plain text in the top-left corner of the screen with no background dimming, no proper sizing, and no visual example of the QTE bar — it does not match the size/style of other tutorials in the game

### Expected Behavior (Correct)

2.1 WHEN the direction arrow CTA is active THEN the system SHALL render the `task_bg` normally (no alpha flashing) and only flash the `direction_arrow` label element

2.2 WHEN a task workstation is NOT the currently active task THEN the system SHALL NOT show the yellow highlight glow; the glow SHALL only appear on the workstation whose `task_id` matches `GameManager.get_current_task_id()`

2.3 WHEN the player is on the same floor as the task target room THEN the system SHALL show a left (←) or right (→) arrow pointing toward the target room's horizontal position relative to the player — the elevator direction arrow SHALL only show up (↑) or down (↓) when the player needs to change floors (i.e. player floor ≠ task target floor)

2.4 WHEN the game initializes or resets inconveniences THEN the system SHALL NOT contain any "Stopped Clock" inconvenience logic — the `is_clock_stopped` variable, its HUD freeze behavior, and its revert logic SHALL be removed entirely

2.5 WHEN the "keybind" (Control Reverse) inconvenience triggers THEN the system SHALL randomly remap all remappable input actions (move_left, move_right, interact, and a new "qte_confirm" action) to random keys excluding ESC and numpad keys; the "qte_confirm" action SHALL have a default binding of Space AND SHALL have a visible, rebindable row labeled "QTE Confirm" in the Settings → Keybinds UI screen (not just an InputMap addition — the player must be able to see and rebind it from the settings menu)

2.6 WHEN the player presses the pause key THEN the system SHALL roll a chance (scaling with loop number) to trigger the "unpause_hack" inconvenience; it SHALL NOT trigger from the task-completion inconvenience pool

2.7 WHEN the "time_stop" inconvenience is active THEN the system SHALL keep the deadline timer running AND SHALL prevent the player from interacting with ANY task workstation (the prompt SHALL show `[TIME FROZEN]` immediately without requiring the player to press E, or the prompt SHALL be hidden entirely)

2.8 WHEN the "gibberish" (text scramble) inconvenience activates THEN the system SHALL replace each label's text with a random string of the same length composed of a random mix of uppercase/lowercase alphabet characters and symbols (e.g. `@`, `#`, `$`, `%`, `^`, `&`, `*`, `!`, `?`, `~`)

2.9 WHEN the "time_reverse" inconvenience triggers THEN the system SHALL undo the last completed task by decrementing `current_task_index`, marking the objective incomplete, AND resetting the corresponding `InteractableObject.task_completed` flag so the workstation becomes interactable again

2.10 WHEN the "time_erase" inconvenience triggers from the MAJOR pool THEN the system SHALL correctly set `is_time_erased = true` for 7 seconds, during which any task completed by the player SHALL NOT count (objective not recorded, workstation resets to allow retry), and the flag SHALL auto-revert after timeout

2.11 WHEN a developer activates the admin/debug panel (via a debug key combo or debug flag) THEN the system SHALL display a panel with a dropdown list of ALL inconveniences in the game, and selecting one from the dropdown SHALL immediately trigger that inconvenience as if it were rolled from the pool — this is a development/testing tool only

2.12 WHEN the Arrow_Sprite (ARROW.png) is displayed on the HUD THEN the rotations SHALL be corrected so that the arrow visually points in the correct direction; additionally, the code SHALL include comments next to each rotation value explaining how to adjust the position/rotation for tweaking (e.g. `# Adjust rotation_degrees here: 0 = right, 180 = left, 270 = up, 90 = down`)

2.13 WHEN the Skill Check tutorial appears THEN the Tutorial_Overlay SHALL be the same size and style as other tutorials in the game (full-screen or near-full-screen centered panel); it SHALL have a semi-transparent dark background dim (black at ~85% opacity), centered tutorial text, and a visual example of the QTE bar showing a successful state; the layout SHALL match the existing tutorial system (e.g. LoopTutorial) in terms of sizing, centering, and background treatment

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the player completes a task THEN the system SHALL CONTINUE TO animate the task label sliding out and the next task sliding in via `_animate_task_complete()`

3.2 WHEN the player is in the same room as the active task THEN the system SHALL CONTINUE TO hide the direction arrow entirely

3.3 WHEN the player is on a different floor than the task target THEN the system SHALL CONTINUE TO show an arrow pointing toward the elevator on the current floor

3.4 WHEN the player is inside the elevator and the task is on a different floor THEN the system SHALL CONTINUE TO show an up (↑) or down (↓) arrow indicating which floor to go to

3.5 WHEN the active task workstation is in range and the task is available THEN the system SHALL CONTINUE TO show the "Press [E]" prompt and allow interaction

3.6 WHEN inconveniences trigger from the task-completion chance system THEN the system SHALL CONTINUE TO respect loop quotas, difficulty tiers, and accumulated chance mechanics

3.7 WHEN the "time_accelerate" inconvenience triggers THEN the system SHALL CONTINUE TO set `Engine.time_scale = 4.0` for 2 seconds and revert

3.8 WHEN the player completes tasks within the deadline THEN the system SHALL CONTINUE TO award productivity bonuses for consecutive completions

3.9 WHEN the QTE skill check is active THEN the system SHALL CONTINUE TO use the `qte_confirm` action (Space by default) to confirm timing, not the `interact` action

3.10 WHEN the "fake_ad" or "blur" inconveniences trigger THEN the system SHALL CONTINUE TO display and auto-fix them according to existing timeout logic

3.11 WHEN the admin/debug panel is NOT active (debug flag disabled or key combo not pressed) THEN the system SHALL CONTINUE TO hide the debug panel entirely and the game SHALL behave identically to a release build with no debug UI visible

3.12 WHEN the arrow is hidden (player in same room as task or all tasks complete) THEN the Arrow_Sprite SHALL CONTINUE TO be hidden regardless of rotation values

3.13 WHEN other tutorials (loop tutorial, retaliation tutorial) are displayed THEN they SHALL CONTINUE TO render with their existing correct layout and styling
