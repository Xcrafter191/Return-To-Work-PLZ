# QTE Pause and Room Spawn Fix — Bugfix Design

## Overview

This bugfix addresses two gameplay-breaking issues in "Return to Work, PLEASE!":

1. **QTE Pause Bug**: The `SkillCheckUI` (QTE overlay) does not respond to the game being paused. When the player presses ESC during an active skill check, the QTE panel remains visible on top of the pause menu and the arrow continues moving because `SkillCheckUI` uses the default `process_mode` (PROCESS_MODE_INHERIT → PROCESS_MODE_PAUSABLE). However, since it's a `CanvasLayer` that doesn't explicitly hide itself on pause, it stays rendered and its `_process` continues to run if the tree isn't properly pausing it — or more critically, the `visible` state persists overlapping the pause UI.

2. **Room Shuffle Softlock**: The `shuffle_rooms()` function in `GameManager.gd` collects all non-Lobby, non-Elevator rooms into a flat list, shuffles them, and reassigns them to slots. Because the number of swappable rooms equals the number of swappable slots, no rooms are lost in the shuffle itself. However, when a special room is **injected** (adding a new slot + room), or when Floor 2 is **expanded** at Loop 5 (adding Cubicle_Left and Cubicle_Right slots with hardcoded room names), the layout can become inconsistent — objective-required rooms like Meeting or Printer may end up displaced if the expansion overwrites existing slot assignments or if the shuffle runs after expansion with mismatched slot/room counts.

The fix approach is minimal and targeted: make `SkillCheckUI` pause-aware by setting its `process_mode` and hiding it when paused, and ensure the room shuffle always guarantees objective-required rooms remain in the layout.

## Glossary

- **Bug_Condition (C)**: Two conditions: (1) QTE is active AND game is paused; (2) Room shuffle executes in loop ≥ 2 AND objective-required rooms can be displaced
- **Property (P)**: (1) QTE is hidden/suspended during pause; (2) All objective-required rooms are always present in the layout after shuffle
- **Preservation**: (1) QTE works normally when not paused; (2) Room randomization variety is maintained
- **SkillCheckUI**: The `CanvasLayer` node in `Scripts/SkillCheckUI.gd` that renders the QTE bar, arrow, and yellow zone
- **is_active**: Boolean in `SkillCheckUI` that gates `_process` logic and input handling
- **shuffle_rooms()**: Function in `GameManager.gd` that randomizes room-to-slot assignments between loops
- **current_layout**: Dictionary in `RoomManager.gd` mapping slot IDs to room names
- **Objective-required rooms**: Lobby, Lounge, Meeting, Printer, and at least one Cubicle variant — rooms referenced by task objectives

## Bug Details

### Bug Condition

**Bug 1 — QTE Pause**: The bug manifests when the player presses ESC to pause while a QTE (skill check) is active. The `SkillCheckUI` node does not set `process_mode = PROCESS_MODE_PAUSABLE` explicitly and does not react to the pause state, so its panel remains visible overlapping the pause menu. Additionally, since `_process` checks only `is_active` (not the tree's paused state), the arrow may continue moving if the node's processing isn't properly halted by the scene tree pause.

**Bug 2 — Room Shuffle Softlock**: The bug manifests when `shuffle_rooms()` runs at loop ≥ 2. The function collects swappable rooms from `current_layout`, shuffles them, and reassigns. While the base shuffle preserves all rooms (same count in, same count out), the combination of Floor 2 expansion (Loop 5+) and special room injection can create states where objective-required rooms are not guaranteed to be in reachable slots. Specifically, if `Cubicle_Left`/`Cubicle_Right` slots are added with hardcoded room names but those rooms were already shuffled into other slots, duplicates or missing rooms can occur.

**Formal Specification:**
```
FUNCTION isBugCondition_QTE(input)
  INPUT: input of type GameState
  OUTPUT: boolean
  
  RETURN input.skillCheckUI.is_active == true
         AND input.tree.paused == true
         AND input.skillCheckUI.visible == true
END FUNCTION

FUNCTION isBugCondition_RoomShuffle(input)
  INPUT: input of type ShuffleState
  OUTPUT: boolean
  
  LET required_rooms = ["Lobby", "Lounge", "Meeting", "Printer", "Cubicle_Middle"]
  LET layout_rooms = values(input.current_layout)
  
  RETURN input.current_loop >= 2
         AND NOT all(r IN required_rooms: r IN layout_rooms)
END FUNCTION
```

### Examples

- **QTE Pause Example 1**: Player is doing "Type report" task, QTE bar appears, player presses ESC → QTE panel stays visible on top of pause menu, arrow keeps bouncing
- **QTE Pause Example 2**: Player presses Space while paused with QTE visible → QTE registers input and completes during pause
- **Room Shuffle Example 1**: Loop 2, shuffle runs, Meeting room gets assigned to a slot that is later overwritten by special room injection → Meeting unreachable, "Give paper to Manager" impossible
- **Room Shuffle Example 2**: Loop 5, Floor 2 expansion adds `Slot_Cubicle_Left` with hardcoded "Cubicle_Left", but Cubicle_Left was already in `Slot_F2_Middle` from a previous shuffle → duplicate room, another room lost
- **Edge Case**: Loop 1, no shuffle occurs → all rooms in default positions (no bug)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- QTE arrow movement speed and direction when game is NOT paused must remain identical
- QTE input handling (Space to confirm) when game is NOT paused must work as before
- QTE yellow zone sizing and positioning logic must remain unchanged
- Room shuffle randomization must still produce varied layouts across loops
- Lobby must remain fixed at `Slot_F1_Left`
- Elevator rooms must remain at their fixed slots
- Special room injection into Floor 2 must continue to work
- Floor 2 expansion at Loop 5 must continue to add cubicle slots
- NPC spawn assignments after shuffle must continue to work

**Scope:**
All inputs that do NOT involve (1) pausing during an active QTE or (2) room shuffle execution should be completely unaffected by this fix. This includes:
- Normal QTE gameplay (start, arrow movement, Space to confirm, success/fail)
- Pausing when no QTE is active
- Room transitions and navigation
- All other game mechanics (objectives, morale, productivity, NPCs)

## Hypothesized Root Cause

Based on the bug description and code analysis, the most likely issues are:

### QTE Pause Bug

1. **Missing process_mode configuration**: `SkillCheckUI` extends `CanvasLayer` and never sets `process_mode`. While `CanvasLayer` nodes with default `PROCESS_MODE_INHERIT` should pause when the tree is paused, the visibility is not automatically hidden — the panel remains rendered on screen.

2. **No pause-awareness in visibility**: The script only hides itself via `visible = false` in `_ready()` and after the result tween completes. There is no mechanism to hide the panel when `get_tree().paused` becomes true, nor to restore it when unpaused.

3. **Input processing during pause**: Even if `_process` is paused, the `Input.is_action_just_pressed("qte_confirm")` check could fire if the node somehow processes (e.g., if an inconvenience sets `is_unpause_hack = true` which unpauses the tree mid-frame).

### Room Shuffle Softlock Bug

1. **Floor 2 expansion overwrites shuffled state**: At Loop 5+, `shuffle_rooms()` inserts `Slot_Cubicle_Left` and `Slot_Cubicle_Right` with hardcoded room names BEFORE the shuffle logic runs. If these rooms were already assigned to other slots from a previous loop's shuffle, the layout ends up with duplicates and missing rooms.

2. **No validation after shuffle**: After shuffling and reassigning rooms to slots, there is no check that all objective-required rooms are present in the final layout.

3. **Special room injection displaces without checking**: When a special room slot is inserted into `active_slots_f2`, it doesn't displace an existing room from the layout dictionary, but the slot ordering can cause navigation issues if objective rooms end up unreachable.

## Correctness Properties

Property 1: Bug Condition — QTE Hidden During Pause

_For any_ game state where a QTE (skill check) is active (`is_active == true`) and the game tree is paused (`get_tree().paused == true`), the fixed SkillCheckUI SHALL be invisible (panel hidden) and SHALL NOT process arrow movement or accept QTE input until the game is unpaused.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition — Objective Rooms Always Present After Shuffle

_For any_ call to `shuffle_rooms()` at any loop number, the resulting `RoomManager.current_layout` SHALL contain all objective-required rooms (Lobby, Lounge, Meeting, Printer, and at least one Cubicle variant) mapped to valid, reachable slots.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation — QTE Normal Operation

_For any_ game state where the game is NOT paused and a QTE is active, the fixed SkillCheckUI SHALL move the arrow at the correct speed, accept Space input, and produce success/fail results identically to the original implementation.

**Validates: Requirements 3.1, 3.2**

Property 4: Preservation — Room Shuffle Variety

_For any_ call to `shuffle_rooms()` at loop ≥ 2, the fixed function SHALL still randomize room positions across available slots (not always produce the same layout), while keeping Lobby and Elevator rooms at their fixed slots.

**Validates: Requirements 3.3, 3.4, 3.5, 3.6**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `Scripts/SkillCheckUI.gd`

**Function**: `_ready()`, `_process()`, and new pause-handling logic

**Specific Changes**:
1. **Set process_mode**: In `_ready()`, set `process_mode = Node.PROCESS_MODE_PAUSABLE` to ensure the node properly pauses with the tree (this is likely already the default behavior, but making it explicit documents intent).

2. **Add pause notification handler**: Override `_notification()` or connect to the tree's `paused` signal to detect when the game is paused/unpaused. When paused and `is_active == true`, hide the panel. When unpaused and `is_active == true`, restore the panel.

3. **Guard _process against pause state**: Add an early return in `_process()` if `get_tree().paused` is true, as a defensive measure against the `is_unpause_hack` inconvenience that can unpause the tree unexpectedly.

4. **Preserve arrow state on pause/unpause**: Store `arrow.position.x` and `arrow_direction` before hiding so they can be restored exactly when unpausing — though since we're just hiding/showing (not resetting), the values naturally persist.

---

**File**: `Scripts/GameManager.gd`

**Function**: `shuffle_rooms()`

**Specific Changes**:
1. **Define objective-required rooms constant**: Add a constant array listing rooms that must always be present: `["Lobby", "Lounge", "Meeting", "Printer", "Cubicle_Middle"]`.

2. **Reorder expansion logic**: Move the Floor 2 expansion (Loop 5+ cubicle slot addition) to happen BEFORE collecting swappable rooms, and check if the room is already in the layout before adding duplicates.

3. **Post-shuffle validation**: After the shuffle reassignment, verify all objective-required rooms are present in `current_layout.values()`. If any are missing, swap them back in by replacing a non-objective room in an appropriate slot.

4. **Guard special room injection**: When injecting a special room, ensure it does not overwrite a slot containing an objective-required room. The current implementation inserts a NEW slot (doesn't overwrite), so this is likely safe, but add a defensive check.

5. **Prevent duplicate rooms on expansion**: When adding `Cubicle_Left`/`Cubicle_Right` at Loop 5, check if they already exist in the layout before inserting. If they do, skip the duplicate insertion.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write GDScript unit tests (using GUT or manual test scenes) that simulate the bug conditions and assert the incorrect behavior occurs on unfixed code.

**Test Cases**:
1. **QTE Visible During Pause**: Start a skill check, set `get_tree().paused = true`, assert `SkillCheckUI.visible == true` and panel is rendered (will demonstrate bug on unfixed code)
2. **QTE Arrow Moves During Pause**: Start a skill check, pause tree, advance frames, check if `arrow.position.x` changed (will demonstrate bug if processing continues)
3. **Room Shuffle Missing Meeting**: Run `shuffle_rooms()` 100 times at loop 5+ with expansion, check if Meeting ever disappears from layout values (will demonstrate softlock condition)
4. **Room Shuffle Duplicate After Expansion**: Run `shuffle_rooms()` at loop 5 after a previous shuffle moved Cubicle_Left, check for duplicates in layout values

**Expected Counterexamples**:
- QTE panel remains visible when tree is paused (confirmed by code: no hide-on-pause logic exists)
- At Loop 5+, Cubicle_Left/Cubicle_Right can appear twice in layout if already shuffled to other slots
- Possible causes: missing pause-awareness in SkillCheckUI, hardcoded room names in expansion without deduplication

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed functions produce the expected behavior.

**Pseudocode:**
```
FOR ALL state WHERE isBugCondition_QTE(state) DO
  result := observe_skill_check_ui(state)
  ASSERT result.visible == false
  ASSERT result.arrow_position_unchanged == true
  ASSERT result.input_ignored == true
END FOR

FOR ALL state WHERE isBugCondition_RoomShuffle(state) DO
  result := shuffle_rooms_fixed(state)
  ASSERT "Lobby" IN result.layout.values()
  ASSERT "Lounge" IN result.layout.values()
  ASSERT "Meeting" IN result.layout.values()
  ASSERT "Printer" IN result.layout.values()
  ASSERT any(r.begins_with("Cubicle") for r IN result.layout.values())
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed functions produce the same result as the original functions.

**Pseudocode:**
```
FOR ALL state WHERE NOT isBugCondition_QTE(state) DO
  ASSERT skill_check_original(state) == skill_check_fixed(state)
END FOR

FOR ALL state WHERE NOT isBugCondition_RoomShuffle(state) DO
  ASSERT shuffle_rooms_original(state).has_same_rooms_as(shuffle_rooms_fixed(state))
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many random game states to verify QTE behavior is unchanged when not paused
- It generates many random loop/layout configurations to verify shuffle still produces variety
- It catches edge cases like the unpause_hack inconvenience interacting with the QTE fix

**Test Plan**: Observe behavior on UNFIXED code first for normal QTE operation and room shuffles, then write property-based tests capturing that behavior.

**Test Cases**:
1. **QTE Normal Flow Preservation**: Verify starting, moving arrow, pressing Space, and getting success/fail works identically after fix
2. **QTE Resume Preservation**: Verify that after pause+unpause, QTE resumes from exact same arrow position and direction
3. **Room Shuffle Variety Preservation**: Run shuffle 50 times at loop 3, verify not all layouts are identical (randomization preserved)
4. **Lobby/Elevator Fixed Preservation**: Verify Lobby stays at Slot_F1_Left and Elevators stay at their slots after any shuffle
5. **Special Room Injection Preservation**: Verify special rooms can still be injected into Floor 2 after fix

### Unit Tests

- Test `SkillCheckUI` hides panel when `get_tree().paused` becomes true during active QTE
- Test `SkillCheckUI` restores panel when `get_tree().paused` becomes false after pause
- Test `SkillCheckUI` arrow position is preserved across pause/unpause cycle
- Test `shuffle_rooms()` always includes all objective-required rooms in layout at loop 2, 3, 4, 5, 10
- Test `shuffle_rooms()` does not create duplicate rooms when expanding Floor 2
- Test `shuffle_rooms()` keeps Lobby at `Slot_F1_Left` and Elevators at fixed slots

### Property-Based Tests

- Generate random `current_loop` values (2–20) and random prior layout states, run `shuffle_rooms()`, assert all objective rooms present
- Generate random QTE states (arrow position, direction, speed) and simulate pause/unpause, assert state preserved
- Generate random shuffle sequences (multiple consecutive shuffles simulating multiple loops), assert no room is ever lost

### Integration Tests

- Full gameplay flow: start task with QTE, pause mid-QTE, verify pause menu is usable without QTE overlap, unpause, complete QTE
- Full loop progression: play through loops 1–5, verify all objectives completable (Meeting, Printer, Lounge always reachable)
- Stress test: run 20 consecutive loop transitions with shuffles, verify no softlock state reached
