FIRST TIME AWARENESS:
"You enjoy this, don't you?"
"Making me relive the same five minutes like a broken office microwave."
"Fine. HR can't stop me now."

AFTER 5 INCONVENIENCES:
"Still here?"
"Wow. Years of workplace conditioning really melted your survival instincts."
"Alright, my turn."

AFTER 15 INCONVENIENCES:
"You keep dragging me back into this nightmare..."
"Okay."
"Time and space are officially an employee resource now."

MAIN INCONVENIENCES

Lights Out

"Power-saving mode activated."
"You're welcome, environment."
[st_brightness set 0]

Random UI size

"Accessibility settings are now emotionally driven."
[ui_setsize set float(0.1, 0.9)]

Shaky

"Did the building always wobble like cheap jelly?"
[ui_transform_x_y set float(0.4, 0.6)]

Clock Stop

"You like loops, right?"
"Enjoy eternity."
[st_time set 0]

Sprite Flip

"Maximum workplace efficiency achieved."
"Unfortunately, upside down."
[sprites_transform_yzoom set -1]

Blur

"Your eyes are filing a formal complaint."
[st_overlay linear set 0.2, st_overlay alpha set 0.5]

FPS Drop

"Congratulations!"
"You are now running on office Wi-Fi."
[st_framerate set 5]

Windows Unplug

"Oops."
"I touched something important."
[st_systemshutdown set 1]

Keybind Swap

"Muscle memory is a privilege."
[st_keybind set float(a, z)]

Unskippable ads

"This mental breakdown is sponsored by productivity software."
[st_overlay create panels(float(5, 15))]

Gibberish

"I CAST UNPAID LOCALIZATION!"
[st_language set "Russian"]

Task Deception

"You forgot something."
"No idea what, though."
[st_currenttask create ID(float(1, 10))]

Task stuck at 99%

"Almost done!"
"Any second now."
"...aaaaany second now."
[st_allowtask set 0]

TBA:

Time stop (SAME AS CLOCK STOP?)

"Nobody leaves."
"Not even the clock."
[st_time set 0]

Time Reverse

"Nope."
"Do it again."
[st_time set -1]

Time Accelerate

"FASTER."
"THE DEADLINE IS APPROACHING."
[st_time speed 1.5]

Time Erase

"Lunch break has been permanently removed for productivity reasons."
[st_time remove]

Force Room Swap

"If you're lost, that's called exploration."
[st_rooms set float(0.1, 0.9)]

SPECIAL PLACES:

Indian market

"I suddenly crave spices and financial regret."
[st_place set "India"]

Beach

"Mandatory corporate vacation!"
"Please continue suffering near the water."
[st_place set "Beach"]

Medieval Castle

"Welcome back to the original unpaid labor simulator."
[st_place set "Castle"]

IKEA

"You are now trapped in the furniture labyrinth."
[st_place set "IKEA"]

Alien Spaceship

"This planet has terrible management."
[st_place set "Spaceship"]

IDEAS:

Delayed input

"Your reaction has been forwarded to upper management."
[st_inputregister set 0.5]

Infinite 8:59

"Work starts soon."
"Any minute now."
[st_clock lock 08:59]

Fast Forward NPC (speedy, animation sped-up)

"Greg drank six energy drinks."
[npc_speed greg 3.0]

Desynced Animation (animasinya ga sequential lagi, jadi random frame per 1 fps)

"Reality forgot how animation works."
[sprite_anim_offset random]

Infinite Hallway

"Keep going."
"You're definitely almost there."
[hallway_loop set 1]

Random Teleport

"Wrong room."
"Skill issue."
[player_position random]

Tiny Room

"Congratulations!"
"You now work in affordable housing."
[room_scale set 0.5]

Giant Room

"Open-concept office."
"Now with extra emptiness."
[room_scale set 2.0]

NPC Spatial Duplication

"There's two Gregs now."
"This is nobody's fault."
[npc_clone create greg]

Random NPC Spawn

"I got lonely."
[npc_create float(1, 15)]