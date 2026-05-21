# Implementation Plan: UI Polish and Tutorials

## Overview

This plan implements seven UI improvements for "Return to Work, PLEASE!" in Godot 4 / GDScript: main menu darkening overlay, always-on workstation glow, sprite-based direction arrow, animated clock deadline indicator, skill check tutorial overlay, retaliation tutorial trigger change, and CMD panel restyling. Each task builds incrementally, starting with static scene changes and progressing to scripted behavior modifications.

## Tasks

- [x] 1. Main Menu Dark Overlay
  - [x] 1.1 Add DarkOverlay ColorRect to MainMenu.tscn
    - Open `MainMenu.tscn` and add a `ColorRect` node named `DarkOverlay`
    - Position it in the scene tree after `BackgroundRect` and before `LogoRect`
    - Set `anchors_preset = PRESET_FULL_RECT`
    - Set `color = Color(0, 0, 0, 0.4)`
    - No script changes required — purely a scene tree addition
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Workstation Always-On Glow
  - [x] 2.1 Modify InteractableObject.gd to glow based on active task
    - Connect to `GameManager.current_task_changed` signal in `_ready()`
    - Connect to `GameManager.all_objectives_completed` signal in `_ready()`
    - Add `_update_glow_state()` helper that checks if `task_id == GameManager.get_current_task_id()`
    - Modify `_on_task_changed(idx)` to call `_update_glow_state()` — start glow if match, stop otherwise
    - Add `_on_all_completed()` handler that calls `_stop_glow()`
    - Remove glow start/stop logic from `_on_body_entered` / `_on_body_exited` (keep prompt visibility logic only)
    - Ensure glow alpha oscillates between 0.05 and 0.45 as per existing animation
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 3. Checkpoint - Verify menu and glow changes
  - Ensure all changes compile without errors, ask the user if questions arise.

- [x] 4. Sprite-Based Direction Arrow
  - [x] 4.1 Replace direction arrow Label with TextureRect in HUD.gd
    - In `_ready()`, replace `Label` creation for `direction_arrow` with a `TextureRect`
    - Load `res://Assets/ARROW.png` as the texture
    - Set `custom_minimum_size = Vector2(48, 48)`, `expand_mode = EXPAND_KEEP_SIZE`
    - Set `pivot_offset` to center of the texture for correct rotation
    - _Requirements: 3.1_

  - [x] 4.2 Implement rotation-based direction logic in HUD.gd
    - Modify `_set_arrow_side(is_left)` to set `rotation_degrees` (0° right, 180° left) instead of `.text`
    - Modify `_update_direction_arrow()` to set `rotation_degrees` for elevator cases (270° up, 90° down)
    - Preserve hide logic when player is in the same room or all tasks complete
    - Preserve flash animation (modulate alpha 0.4 → 1.0 over 0.9s cycle) targeting the TextureRect
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 5. Animated Clock Deadline Indicator
  - [x] 5.1 Replace deadline Label with TextureRect in HUD.gd
    - In `_ready()`, replace `deadline_label` Label creation with a `TextureRect` named `clock_rect`
    - Position at top-center using `PRESET_CENTER_TOP` anchors, `offset_top = 20`
    - Add `_clock_frames_cache: Dictionary = {}` for optional texture caching
    - Add `_get_clock_frame(index: int) -> Texture2D` helper that loads `res://Assets/clock/time/time_%03d.png % index`
    - _Requirements: 4.1, 4.6_

  - [x] 5.2 Implement frame-based clock animation in HUD.gd _process
    - In `_process(delta)`, calculate `elapsed = total_deadline - remaining`
    - Compute `frame_idx = clampi(int((elapsed / total) * 240), 0, 240)`
    - Update `clock_rect.texture` with the loaded frame
    - Hide `clock_rect` when `!GameManager.is_deadline_active`
    - Show `clock_rect` when deadline is active
    - Handle missing texture gracefully (hide clock, print warning)
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.7_

- [x] 6. Checkpoint - Verify HUD changes
  - Ensure all changes compile without errors, ask the user if questions arise.

- [x] 7. Skill Check Tutorial Overlay
  - [x] 7.1 Add tutorial state and entry point to SkillCheckUI.gd
    - Add `var _skill_check_tutorial_seen: bool = false` flag
    - Add `begin_skill_check(base_speed: float = 400.0)` as the new public entry point
    - In `begin_skill_check()`, check flag: if not seen → `_show_tutorial(base_speed)`, else → `start_skill_check(base_speed)`
    - Add `reset_tutorial_state()` method that sets `_skill_check_tutorial_seen = false`
    - Update callers of `start_skill_check()` to call `begin_skill_check()` instead
    - _Requirements: 5.1, 5.7, 5.8_

  - [x] 7.2 Implement tutorial overlay display and dismissal in SkillCheckUI.gd
    - Implement `_show_tutorial(pending_speed: float)` that creates a `CanvasLayer` with:
      - Full-screen `ColorRect` with `Color(0, 0, 0, 0.85)`
      - Centered instructional text label with the specified tutorial text
      - Static visual example of the QTE bar with indicator in yellow zone
      - "Press Space to continue" prompt at bottom
    - Set tutorial node `process_mode = PROCESS_MODE_ALWAYS`
    - Pause the scene tree (`get_tree().paused = true`)
    - Implement `_dismiss_tutorial()` that frees the tutorial node, unpauses, sets flag to true, and calls `start_skill_check(pending_speed)`
    - Handle Space/Enter input in `_input()` or `_unhandled_input()` to trigger dismissal
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 7.3 Connect tutorial reset to GameManager.reset_game_state()
    - In `GameManager.reset_game_state()`, call `SkillCheckUI.reset_tutorial_state()` (or emit a signal that SkillCheckUI listens to)
    - Ensure the flag resets on return to main menu or game over
    - _Requirements: 5.8_

- [x] 8. Retaliation Tutorial Trigger Change
  - [x] 8.1 Add first-attack tracking to AttackSequenceManager.gd
    - Add `var _first_attack_seen: bool = false` flag
    - Add `reset_attack_state()` method that sets `_first_attack_seen = false`
    - In `_finish_attack()`, after `sequence_finished.emit()`, check if `!_first_attack_seen`
    - If first attack: set flag to true, call `_show_retaliation_tutorial()`
    - _Requirements: 6.1, 6.3, 6.5_

  - [x] 8.2 Implement retaliation tutorial display with delay
    - Implement `_show_retaliation_tutorial()` that creates a 0.3s timer
    - On timer timeout, instantiate `LoopTutorial.tscn` and add to scene tree
    - _Requirements: 6.1_

  - [x] 8.3 Remove old loop 2 tutorial trigger and connect reset
    - Find and remove the existing loop 2 start trigger for `LoopTutorial` (likely in `Main.gd` or loop restart handler)
    - In `GameManager.reset_game_state()`, call `AttackSequenceManager.reset_attack_state()`
    - Verify the retaliation tutorial no longer appears at loop 2 start
    - _Requirements: 6.2, 6.4_

- [x] 9. Checkpoint - Verify tutorials
  - Ensure all changes compile without errors, ask the user if questions arise.

- [x] 10. Attack Sequence CMD Panel
  - [x] 10.1 Replace fake_console UI with CMD.png TextureRect in AttackSequenceManager.gd
    - In `_setup_ui()`, replace `ColorRect` overlay and `TextEdit` creation with:
      - A `TextureRect` loading `res://Assets/CMD.png` as background
      - Same screen positioning and proportions as the previous panel
    - Add a `Label` or `RichTextLabel` for the title bar text "COMMAND PROMPT" in white pixel font
    - Add a `Label` or `RichTextLabel` for the body text area
    - Handle missing CMD.png gracefully (fall back to existing ColorRect panel, print warning)
    - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6_

  - [x] 10.2 Update text rendering to use white color in CMD panel
    - Change all text color references from green to `Color(1, 1, 1, 1)` (white)
    - Update the typing/animation logic to target the new `Label`/`RichTextLabel` instead of `TextEdit`
    - Ensure title text, attack descriptions, and command text all render in white
    - _Requirements: 7.4_

- [x] 11. Final Checkpoint - Ensure all changes compile and integrate
  - Ensure all changes compile without errors, ask the user if questions arise.

## Notes

- No property-based tests are included because this feature consists entirely of UI rendering changes, visual animations, and event-driven tutorial triggers with no pure algorithmic logic suitable for PBT.
- Each task references specific requirements for traceability.
- Checkpoints ensure incremental validation between logical groups of changes.
- All asset paths (`ARROW.png`, `CMD.png`, `clock/time/` frames) must exist before implementation.
- Tutorial state flags reset via `GameManager.reset_game_state()` to ensure clean state on replay.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "4.1"] },
    { "id": 1, "tasks": ["4.2", "5.1"] },
    { "id": 2, "tasks": ["5.2", "7.1", "8.1"] },
    { "id": 3, "tasks": ["7.2", "8.2"] },
    { "id": 4, "tasks": ["7.3", "8.3", "10.1"] },
    { "id": 5, "tasks": ["10.2"] }
  ]
}
```
