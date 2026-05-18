# Implementation Plan: Room Swapping & Retaliation System

This plan outlines the architecture for the dynamic Room Swapping system and the Time Manipulation retaliation attacks.

## User Review Required
> [!IMPORTANT]
> **Cubicle Split:** Per your feedback, I will duplicate `Cubicle.tscn` into `Cubicle_Left.tscn`, `Cubicle_Middle.tscn`, and `Cubicle_Right.tscn`. The total layout for Floor 2 will increase by 2 extra rooms. The Room Swapper will shuffle all of them!

## 1. Dynamic Room Swapping
**Concept:** Floors are composed of "Slots". We randomize which room goes into which slot.
- **Floor 1 Slots:** `Slot_F1_Left` (Lobby), `Slot_Elevator_F1`, `Slot_F1_Right`.
- **Floor 2 Slots:** `Slot_F2_FarLeft`, `Slot_F2_Left`, `Slot_Elevator_F2`, `Slot_F2_Right`, `Slot_F2_FarRight`.

**Changes:**
1. Update `RoomManager.gd` to maintain a `current_layout` dictionary mapping Slots to Room Scenes.
2. Modify all Room `.tscn` files (including the 3 new Cubicle segments) to standardize their Exits (`ExitLeft`, `ExitRight`) and Spawn Points (`SpawnLeft`, `SpawnRight`).
3. When `RoomManager` loads a room, it will look at the Slot's requirements. If the Slot is at the end of a hallway, it will enable the Wall and disable the Exit. If it's in the middle, it will enable the Exit and disable the Wall.
4. Update `RoomExit.gd` to simply tell `RoomManager` which direction the player walked (e.g., `RoomManager.go_left()`), decoupling the rooms from each other.
5. Create a `shuffle_rooms()` function in `GameManager` triggered by the Inconvenience system.

## 2. Retaliation System (Animation & Time Attacks)
**Concept:** Low morale triggers an angry idle animation and random time-bending punishments after tasks.

**Changes:**
1. **Animation State:** Update `Player.gd` to check `GameManager.morale`. If it is low (< 33), replace the `"idle"` animation state with `"idleaware"`.
2. **Inconvenience Attack Hook:** Hook into `InconvenienceManager._trigger_random_inconvenience()`. Before applying the inconvenience, pause the game slightly, force the player to play the `"attack"` animation, and apply a dramatic camera zoom/shake effect via a Tween.
3. **Attack Trigger:** After a task is completed, if morale is low, there is a % chance to trigger a specific Time Attack (separate from UI inconveniences). The player will forcefully play the `"attack"` animation, locking controls for a moment, before casting the Time effect.
4. **Time Effects:**
   - **Time Stop:** Implemented as a new `InconvenienceManager` state. Players are completely frozen (cannot start tasks). A new task `fix_clock` is dynamically injected into the Lobby. Once completed, Time Stop ends.
   - **Time Reverse:** Reverts `GameManager.current_task_index` by 1. The deadline timer is NOT reset.
   - **Time Accelerate (6X):** When player velocity > 0, `Engine.time_scale` is set to `6.0`. When they stop, it returns to `1.0`. Triggered randomly without the attack animation.
   - **Time Erase:** Applies a glitch/flicker shader to the screen. For 7 seconds, any task completed advances the HUD, but a shadow copy of the task state is kept. After 7 seconds, the real state overwrites the fake state, undoing their progress.
   - **Room Swap:** Calls the `shuffle_rooms()` function (with the attack animation).

## Verification Plan
1. Test swapping `Bathroom` into `Cubicle`'s slot to ensure the walls correctly transform into doors so the player isn't trapped.
2. Lower morale to <33 via admin panel and verify `idleaware` plays.
3. Trigger each of the 5 Time effects manually to ensure they don't break the core game loop.
