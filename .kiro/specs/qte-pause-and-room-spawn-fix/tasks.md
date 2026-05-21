# Implementation Plan

## Overview

This task list implements fixes for two gameplay-breaking bugs: (1) the QTE (skill check) UI remaining active and visible when the player pauses the game, and (2) the room shuffle logic displacing objective-required rooms causing softlocks in later loops. The workflow follows the bug condition methodology: first write exploration tests to confirm bugs exist on unfixed code, then write preservation tests to capture baseline behavior, then implement fixes, and finally verify all tests pass.

## Tasks

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - QTE Visible During Pause & Room Shuffle Missing Objective Rooms
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate both bugs exist
  - **Scoped PBT Approach**: For the QTE bug, scope to: QTE is active AND tree is paused → assert panel is hidden and arrow does not move. For the room shuffle bug, scope to: loop ≥ 2 with Floor 2 expansion → assert all objective rooms present.
  - Test QTE Bug Condition: Start a skill check (`is_active = true`), set `get_tree().paused = true`, assert `SkillCheckUI.visible == false` (from `isBugCondition_QTE` in design)
  - Test QTE Arrow Freeze: With QTE active and tree paused, advance frames, assert `arrow.position.x` has NOT changed
  - Test QTE Input Ignored: With QTE active and tree paused, simulate Space press, assert QTE does not register success/fail
  - Test Room Shuffle Bug Condition: Run `shuffle_rooms()` 100 times at loop 5+ with Floor 2 expansion, assert all objective-required rooms (`Lobby`, `Lounge`, `Meeting`, `Printer`, and at least one `Cubicle` variant) are present in `current_layout.values()` every time (from `isBugCondition_RoomShuffle` in design)
  - Test Room Shuffle Duplicates: Run `shuffle_rooms()` at loop 5 after a previous shuffle moved `Cubicle_Left`, assert no duplicate room names in layout values
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves the bugs exist)
  - Document counterexamples found:
    - QTE panel remains visible when tree is paused (no hide-on-pause logic exists)
    - At Loop 5+, `Cubicle_Left`/`Cubicle_Right` can appear twice in layout if already shuffled to other slots
    - Objective rooms can be missing from layout after expansion + shuffle
  - Mark task complete when tests are written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - QTE Normal Operation & Room Shuffle Variety
  - **IMPORTANT**: Follow observation-first methodology
  - **Observe QTE Normal Flow on UNFIXED code**:
    - Observe: Starting a QTE with `start_skill_check()` sets `is_active = true`, `visible = true`, arrow begins moving
    - Observe: Arrow moves at `arrow_speed` per frame in `arrow_direction`, bouncing at boundaries
    - Observe: Pressing Space during active QTE triggers success/fail based on arrow position relative to yellow zone
    - Observe: After pause+unpause (when no QTE fix exists), arrow position and direction values persist in memory
  - **Observe Room Shuffle on UNFIXED code**:
    - Observe: `shuffle_rooms()` at loop 3 produces varied layouts across multiple calls (not deterministic)
    - Observe: Lobby always remains at `Slot_F1_Left` after any shuffle
    - Observe: Elevator rooms (`Elevator_F1`, `Elevator_F2`) remain at their fixed slots after any shuffle
    - Observe: Special room injection adds a new slot to Floor 2 without overwriting existing slots
  - **Write property-based tests capturing observed behavior**:
    - Property: For all game states where `get_tree().paused == false` and QTE is active, arrow moves at `arrow_speed` per frame and Space input triggers result evaluation
    - Property: For all calls to `shuffle_rooms()` at loop ≥ 2, Lobby is at `Slot_F1_Left` and Elevators are at fixed slots
    - Property: For 50 consecutive shuffles at loop 3, not all layouts are identical (randomization preserved)
    - Property: Special room injection into Floor 2 does not remove any existing room from the layout
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [ ] 3. Fix for QTE pause visibility and room shuffle softlock

  - [x] 3.1 Implement QTE pause-awareness in `Scripts/SkillCheckUI.gd`
    - Set `process_mode = Node.PROCESS_MODE_PAUSABLE` explicitly in `_ready()` to document intent
    - Add `_notification(what)` handler: when `NOTIFICATION_PAUSED` received and `is_active == true`, set `visible = false` (hide panel)
    - Add `_notification(what)` handler: when `NOTIFICATION_UNPAUSED` received and `is_active == true`, set `visible = true` (restore panel)
    - Add early return guard in `_process()`: if `get_tree().paused` is true, return immediately (defensive against `is_unpause_hack`)
    - Arrow position and direction naturally persist across hide/show — no explicit save/restore needed
    - _Bug_Condition: isBugCondition_QTE(input) where input.skillCheckUI.is_active == true AND input.tree.paused == true AND input.skillCheckUI.visible == true_
    - _Expected_Behavior: When paused and QTE active → panel hidden, arrow frozen, input ignored. When unpaused → panel restored, QTE resumes from same state_
    - _Preservation: QTE arrow movement, input handling, and success/fail logic unchanged when game is not paused_
    - _Requirements: 2.1, 2.2, 3.1, 3.2_

  - [x] 3.2 Implement room shuffle safety in `Scripts/GameManager.gd`
    - Define constant: `const OBJECTIVE_REQUIRED_ROOMS = ["Lobby", "Lounge", "Meeting", "Printer", "Cubicle_Middle"]`
    - Reorder Floor 2 expansion logic (Loop 5+ cubicle slot addition) to execute BEFORE collecting swappable rooms
    - Add deduplication check: before adding `Cubicle_Left`/`Cubicle_Right` slots at Loop 5, check if those rooms already exist in `current_layout.values()` — skip insertion if duplicate
    - Add post-shuffle validation: after reassigning rooms to slots, verify all `OBJECTIVE_REQUIRED_ROOMS` are present in `current_layout.values()`
    - If any objective room is missing after shuffle, swap it back in by replacing a non-objective room in an appropriate slot
    - Add defensive check on special room injection: ensure injected slot does not overwrite a slot containing an objective-required room
    - _Bug_Condition: isBugCondition_RoomShuffle(input) where input.current_loop >= 2 AND NOT all objective rooms in layout_
    - _Expected_Behavior: After shuffle, all of Lobby, Lounge, Meeting, Printer, and at least one Cubicle variant are present in current_layout.values()_
    - _Preservation: Room randomization variety maintained, Lobby/Elevator fixed positions unchanged, special room injection still works_
    - _Requirements: 2.3, 2.4, 3.3, 3.4, 3.5, 3.6_

  - [ ] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - QTE Hidden During Pause & Objective Rooms Always Present
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior for both bugs
    - When this test passes, it confirms:
      - QTE panel is hidden when paused, arrow does not move, input is ignored
      - All objective-required rooms are present in layout after any shuffle at any loop
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - QTE Normal Operation & Room Shuffle Variety
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm QTE still works normally when not paused (arrow moves, input accepted, success/fail works)
    - Confirm room shuffle still produces varied layouts, Lobby/Elevator stay fixed, special rooms inject correctly

- [ ] 4. Checkpoint - Ensure all tests pass
  - Run full test suite (bug condition + preservation tests)
  - Verify all property-based tests pass on the fixed code
  - Verify no regressions in QTE normal operation
  - Verify no regressions in room shuffle variety and fixed-position rooms
  - Ensure all tests pass, ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    ["1", "2"],
    ["3.1", "3.2"],
    ["3.3"],
    ["3.4"],
    ["4"]
  ]
}
```

## Notes

- Tasks 1 and 2 can be done in parallel since they are independent (exploration vs preservation tests)
- Implementation sub-tasks 3.1 and 3.2 can be done in parallel after tasks 1 and 2 complete
- Verification tasks (3.3, 3.4) must run sequentially after all implementation is complete
- This is a Godot 4 GDScript project — tests should use GUT framework or manual test scenes
- The QTE fix is minimal: add pause notification handling and a defensive guard in `_process()`
- The room shuffle fix requires reordering expansion logic and adding post-shuffle validation
- Arrow state (position, direction) naturally persists across hide/show — no explicit save/restore needed
- The `is_unpause_hack` inconvenience can unpause the tree mid-frame, hence the defensive `_process()` guard
