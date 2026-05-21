# Bugfix Requirements Document

## Introduction

This document addresses two bugs in "Return to Work, PLEASE!" that impact gameplay stability. The first bug causes the QTE (skill check) UI to remain active and visible when the player pauses the game, overlapping with the pause menu and allowing unintended input. The second bug causes a softlock in later loops because the room shuffle logic can displace rooms that contain required objectives (e.g., Meeting room for "Give paper to Manager"), making it impossible for the player to progress.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the player pauses the game while a QTE (skill check) is active THEN the system continues to display the SkillCheckUI panel overlapping the pause menu

1.2 WHEN the player pauses the game while a QTE is active THEN the system continues to move the QTE arrow and process QTE input during the paused state

1.3 WHEN the game enters loop 2 or later and rooms are shuffled THEN the system may assign objective-required rooms (Meeting, Lounge, Printer, Cubicle variants) to no slot, making them unreachable

1.4 WHEN the Meeting room is not present in any slot after a room shuffle THEN the system softlocks because the player cannot complete the "Give paper to Manager" or "Present to Manager" objectives

### Expected Behavior (Correct)

2.1 WHEN the player pauses the game while a QTE is active THEN the system SHALL hide or suspend the SkillCheckUI so it does not overlap with the pause menu

2.2 WHEN the player pauses the game while a QTE is active THEN the system SHALL pause the QTE arrow movement and ignore QTE input until the game is unpaused

2.3 WHEN the game enters any loop and rooms are shuffled THEN the system SHALL guarantee that all rooms referenced by objectives (Lobby, Lounge, Meeting, Printer, and at least one Cubicle variant) are always assigned to a slot in the layout

2.4 WHEN rooms are shuffled between loops THEN the system SHALL only randomize the placement/position of objective rooms across available slots, not exclude them from the layout entirely

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the game is not paused and a QTE is active THEN the system SHALL CONTINUE TO move the arrow at the correct speed and accept QTE input normally

3.2 WHEN the player unpauses the game after a QTE was suspended THEN the system SHALL CONTINUE TO resume the QTE from where it left off (arrow position and direction preserved)

3.3 WHEN the game is in loop 1 (no shuffle) THEN the system SHALL CONTINUE TO use the default room layout with all rooms in their original positions

3.4 WHEN rooms are shuffled THEN the system SHALL CONTINUE TO randomize room positions so that gameplay variety is preserved across loops

3.5 WHEN rooms are shuffled THEN the system SHALL CONTINUE TO keep Lobby at Slot_F1_Left and Elevator rooms at their fixed slots

3.6 WHEN special rooms are injected during later loops THEN the system SHALL CONTINUE TO insert them into Floor 2 without displacing objective-required rooms
