# Requirements Document

## Introduction

This document specifies UI polish improvements and tutorial enhancements for "Return to Work, PLEASE!" — a Godot 4 game where the player completes office tasks while an NPC throws escalating inconveniences at them. The changes improve visual clarity (main menu readability, animated clock, sprite-based arrows), add a first-time skill check tutorial, and fix the retaliation tutorial trigger timing.

## Glossary

- **Main_Menu**: The initial screen displayed when the game launches, containing the background image, logo, and Play/Options/Exit buttons (scene: `MainMenu.tscn`)
- **HUD**: The in-game heads-up display overlay showing productivity bar, morale bar, current task, deadline indicator, and direction arrow (scene: `HUD.tscn`, script: `HUD.gd`)
- **Direction_Arrow**: A UI element on the HUD that points the player toward the room where the current active task must be completed
- **Workstation_Hitbox**: The Area2D detection zone on an InteractableObject that defines where the player can interact with a task workstation; visually highlighted with a yellow ColorRect glow
- **Clock_Animation**: A frame-based sprite animation using 241 PNG frames (`Assets/clock/time/time_000.png` through `time_240.png`) representing deadline progress from start to expiry
- **Skill_Check**: A Quick Time Event (QTE) minigame where a white indicator bar bounces across a track and the player must press Space when the indicator is within the yellow zone (scene: `SkillCheckUI.tscn`)
- **Tutorial_Overlay**: A CanvasLayer-based full-screen UI that dims the game background and displays instructional text, pausing gameplay until the player dismisses it
- **Retaliation_Tutorial**: The tutorial overlay that warns the player about NPC attacks/inconveniences, currently triggered at the start of loop 2 (scene: `LoopTutorial.tscn`)
- **Attack_Sequence**: The cinematic sequence triggered by InconvenienceManager when the NPC executes an inconvenience against the player, managed by AttackSequenceManager
- **GameManager**: The autoload singleton tracking objectives, loops, deadlines, and game state
- **Arrow_Sprite**: The pixelated yellow arrow image located at `Assets/ARROW.png`
- **CMD_Panel**: The command prompt-styled UI panel used during the Attack_Sequence, visually based on the `Assets/CMD.png` asset featuring a black background, white border, "COMMAND PROMPT" title bar, and white text

## Requirements

### Requirement 1: Main Menu Background Darkening

**User Story:** As a player, I want the main menu background to be slightly darkened, so that the logo and button text are easier to read against the background image.

#### Acceptance Criteria

1. THE Main_Menu SHALL display a semi-transparent dark overlay between the BackgroundRect and the logo/button elements
2. WHEN the Main_Menu scene loads, THE dark overlay SHALL render with a color of black at 40% opacity (Color(0, 0, 0, 0.4))
3. THE dark overlay SHALL cover the full screen area using the PRESET_FULL_RECT anchor configuration
4. THE dark overlay SHALL be positioned in the scene tree after BackgroundRect and before LogoRect so that it darkens only the background without affecting UI element rendering

### Requirement 2: Workstation Hitbox Always-On Glow

**User Story:** As a player, I want the active task's workstation hitbox to glow yellow at all times (regardless of my proximity), so that I can see where I need to go to complete the current task.

#### Acceptance Criteria

1. WHILE a task is the currently active task (matching `GameManager.get_current_task_id()`), THE Workstation_Hitbox highlight rectangle SHALL flash yellow regardless of whether the player is within the DetectionArea
2. WHEN the player is NOT within the DetectionArea of the active task's workstation, THE Workstation_Hitbox SHALL still display the flashing yellow glow animation (alpha oscillating between 0.05 and 0.45)
3. WHEN the active task changes (via `current_task_changed` signal), THE previously active Workstation_Hitbox SHALL stop glowing AND THE newly active Workstation_Hitbox SHALL start glowing
4. WHEN a task workstation is NOT the currently active task, THE Workstation_Hitbox SHALL NOT display the yellow glow
5. WHEN all objectives are completed, THE Workstation_Hitbox glow SHALL stop on all workstations

### Requirement 3: Sprite-Based Direction Arrow

**User Story:** As a player, I want the direction arrow to use the pixelated yellow arrow sprite instead of text characters, so that the navigation indicator matches the game's pixel art style.

#### Acceptance Criteria

1. THE HUD SHALL use the Arrow_Sprite texture (`res://Assets/ARROW.png`) loaded into a TextureRect node instead of a Label node for the Direction_Arrow
2. WHEN the active task is to the left of the player's current room, THE Arrow_Sprite SHALL be rotated 180 degrees to point left
3. WHEN the active task is to the right of the player's current room, THE Arrow_Sprite SHALL be rotated 0 degrees (default orientation pointing right)
4. WHEN the player is in an elevator and the active task is on a higher floor, THE Arrow_Sprite SHALL be rotated 270 degrees to point upward
5. WHEN the player is in an elevator and the active task is on a lower floor, THE Arrow_Sprite SHALL be rotated 90 degrees to point downward
6. THE Arrow_Sprite SHALL retain the existing flash animation (modulate alpha oscillating between 0.4 and 1.0 over 0.9 seconds total cycle)
7. WHEN the player is in the same room as the active task OR all tasks are completed, THE Arrow_Sprite SHALL be hidden

### Requirement 4: Animated Clock Deadline Indicator

**User Story:** As a player, I want the deadline timer to display as an animated clock sprite instead of text, so that I can quickly gauge remaining time through a visual indicator that fits the game's art style.

#### Acceptance Criteria

1. THE HUD SHALL replace the text-based deadline Label with a TextureRect node displaying the Clock_Animation frames
2. WHEN a task deadline is active, THE Clock_Animation SHALL display the frame corresponding to the proportion of elapsed time: frame index = floor((elapsed_time / total_deadline_time) * 240)
3. WHEN the deadline starts (elapsed time = 0), THE Clock_Animation SHALL display frame 0 (`time_000.png`)
4. WHEN the deadline expires (elapsed time >= total_deadline_time), THE Clock_Animation SHALL display frame 240 (`time_240.png`)
5. WHEN no deadline is active, THE Clock_Animation SHALL be hidden
6. THE Clock_Animation SHALL be positioned at the top-center of the screen where the text-based deadline label previously appeared
7. THE Clock_Animation frame index SHALL be clamped between 0 and 240 to prevent out-of-bounds access

### Requirement 5: Skill Check Tutorial Overlay

**User Story:** As a player encountering a skill check for the first time, I want a tutorial overlay explaining the QTE mechanic, so that I understand what to do before attempting it.

#### Acceptance Criteria

1. WHEN the player encounters a Skill_Check for the first time in a game session, THE Tutorial_Overlay SHALL appear before the Skill_Check begins
2. THE Tutorial_Overlay SHALL display a semi-transparent dark background (black at 85% opacity) covering the full screen
3. THE Tutorial_Overlay SHALL display the text: "During some tasks, you will have to face 'Focus Timing,' in which you have to stop the white bar at the yellow zone as shown below."
4. THE Tutorial_Overlay SHALL display a static visual example showing the QTE bar with the white indicator positioned within the yellow zone (successful state)
5. THE Tutorial_Overlay SHALL pause the game tree while displayed (process_mode = PROCESS_MODE_ALWAYS on the tutorial node itself)
6. WHEN the player presses Space or Enter, THE Tutorial_Overlay SHALL dismiss and the Skill_Check SHALL begin
7. WHEN the player has already seen the Skill_Check tutorial in the current game session, THE Tutorial_Overlay SHALL NOT appear on subsequent Skill_Check encounters
8. WHEN the game state is reset (return to main menu or game over), THE tutorial-seen flag SHALL reset so the tutorial appears again in the next session

### Requirement 6: Retaliation Tutorial Trigger Change

**User Story:** As a player, I want the retaliation warning tutorial to appear after I first experience an NPC attack, so that the warning is contextually relevant rather than appearing before I understand what it refers to.

#### Acceptance Criteria

1. WHEN the first Attack_Sequence completes (AttackSequenceManager.sequence_finished emitted for the first time), THE Retaliation_Tutorial SHALL appear after a 0.3 second delay
2. THE Retaliation_Tutorial SHALL NOT appear at the start of loop 2
3. THE Retaliation_Tutorial SHALL only appear once per game session (first attack only)
4. WHEN the game state is reset (return to main menu or game over), THE first-attack-seen flag SHALL reset so the tutorial can appear again in the next session
5. IF the player reaches loop 2 without any Attack_Sequence having triggered, THEN THE Retaliation_Tutorial SHALL appear after the first Attack_Sequence that eventually occurs (regardless of which loop)

### Requirement 7: Attack Sequence Command Prompt UI Replacement

**User Story:** As a player, I want the attack sequence panel to look like a retro command prompt window, so that the NPC's attacks feel like system intrusions that match the game's office-computer theme.

#### Acceptance Criteria

1. WHEN an Attack_Sequence is triggered, THE Attack_Sequence UI panel SHALL display using the CMD.png asset (`res://Assets/CMD.png`) as the panel background texture
2. THE Attack_Sequence UI panel SHALL render with a black background, a thin white/light border, a title bar area at the top displaying "COMMAND PROMPT" text in a white pixel font, and a horizontal separator line between the title bar and the body area
3. THE Attack_Sequence UI body area SHALL be a large black rectangle where attack text and commands appear
4. WHILE the Attack_Sequence UI is visible, ALL text rendered within the panel (including title text, attack descriptions, and command text) SHALL use white color (Color(1, 1, 1, 1))
5. THE Attack_Sequence UI panel SHALL replace the previously used attack sequence panel visual appearance entirely (no elements of the old panel style shall remain visible)
6. THE Attack_Sequence UI panel layout and sizing SHALL maintain the same screen positioning and proportions as the previous attack sequence panel to preserve gameplay readability
