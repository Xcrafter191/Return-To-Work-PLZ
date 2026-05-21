extends Node

signal sequence_finished

@onready var popup_panel: ColorRect = null
@onready var dialogue_container: Node2D = null
@onready var dialogue_bubble: TextureRect = null
@onready var dialogue_label: Label = null
@onready var dialogue_name_label: Label = null
@onready var fake_console: TextEdit = null
@onready var cmd_panel: TextureRect = null
@onready var cmd_title_label: Label = null
@onready var cmd_body_label: RichTextLabel = null
var _use_cmd_panel: bool = false

var is_attacking: bool = false
var _current_inconvenience: String = ""
var total_inconveniences: int = 0
var _first_attack_seen: bool = false

var milestone_dialogues = {
	1: ["You enjoy this, don't you?", "Making me relive the same five minutes like a broken office microwave.", "Fine. HR can't stop me now."],
	5: ["Still here?", "Wow. Years of workplace conditioning really melted your survival instincts.", "Alright, my turn."],
	15: ["You keep dragging me back into this nightmare...", "Okay.", "Time and space are officially an employee resource now."]
}

var inconvenience_dialogues = {
	"lights_out": ["Power-saving mode activated.", "You're welcome, environment."],
	"random_ui": ["Accessibility settings are now emotionally driven."],
	"shaky": ["Did the building always wobble like cheap jelly?"],
	"sprite_flip": ["Maximum workplace efficiency achieved.", "Unfortunately, upside down."],
	"blur": ["Your eyes are filing a formal complaint."],
	"fps": ["Congratulations!", "You are now running on office Wi-Fi."],
	"unplug": ["Oops.", "I touched something important."],
	"keybind": ["Muscle memory is a privilege."],
	"fake_ad": ["This mental breakdown is sponsored by productivity software."],
	"gibberish": ["I CAST UNPAID LOCALIZATION!"],
	"task_deception": ["You forgot something.", "No idea what, though."],
	"stuck_99": ["Almost done!", "Any second now.", "...aaaaany second now."],
	"unpause_hack": ["Who said you could pause?"],
	"upside_down": ["Let's flip the perspective."],
	"window_resizer": ["Window management is my passion."],
	"time_stop": ["Nobody leaves.", "Not even the clock."],
	"time_reverse": ["Nope.", "Do it again."],
	"time_accelerate": ["FASTER.", "THE DEADLINE IS APPROACHING."],
	"time_erase": ["Lunch break has been permanently removed for productivity reasons."],
	"force_room_swap": ["If you're lost, that's called exploration."],
	"room_lock": ["You're not going anywhere.", "This is YOUR desk now."],
	"reverse_controls": ["Left is right.", "Right is... also wrong."]
}

# Console commands from the design doc, keyed by inconvenience id
var console_commands = {
	"lights_out": "[st_brightness set 0]",
	"random_ui": "[ui_setsize set float(0.1, 0.9)]",
	"shaky": "[ui_transform_x_y set float(0.4, 0.6)]",
	"sprite_flip": "[sprites_transform_yzoom set -1]",
	"blur": "[st_overlay linear set 0.2, st_overlay alpha set 0.5]",
	"fps": "[st_framerate set 5]",
	"unplug": "[st_systemshutdown set 1]",
	"keybind": "[st_keybind set float(a, z)]",
	"fake_ad": "[st_overlay create panels(float(5, 15))]",
	"gibberish": "[st_language set \"Russian\"]",
	"task_deception": "[st_currenttask create ID(float(1, 10))]",
	"stuck_99": "[st_allowtask set 0]",
	"unpause_hack": "[st_pause set disabled]",
	"upside_down": "[sprites_transform_yzoom set -1]",
	"window_resizer": "[st_windowsize set 640x360]",
	"time_stop": "[st_time set 0]",
	"time_reverse": "[st_time set -1]",
	"time_accelerate": "[st_time speed 4.0]",
	"time_erase": "[st_time remove]",
	"force_room_swap": "[st_rooms set float(0.1, 0.9)]",
	"room_lock": "[st_exit set disabled --duration 10]",
	"reverse_controls": "[st_input invert --axis x]"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# Dark overlay
	popup_panel = ColorRect.new()
	popup_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_panel.color = Color(0, 0, 0, 0.7)
	popup_panel.visible = false
	canvas.add_child(popup_panel)
	
	# ── Dialogue bubble (NPC-style, but red) ──
	# Container centered on screen, slightly above center
	var dialogue_anchor = Control.new()
	dialogue_anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dialogue_anchor.offset_top = 150
	dialogue_anchor.offset_left = -250
	dialogue_anchor.offset_right = 250
	dialogue_anchor.offset_bottom = 350
	popup_panel.add_child(dialogue_anchor)
	
	# Red bubble background
	dialogue_bubble = TextureRect.new()
	dialogue_bubble.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Try loading the CHAT texture, tint it red
	var chat_tex = load("res://Assets/UI V4/TEXTBOX/CHAT.png")
	if chat_tex:
		dialogue_bubble.texture = chat_tex
	dialogue_bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_bubble.modulate = Color(1.0, 0.4, 0.4, 1.0)  # Red tint
	dialogue_anchor.add_child(dialogue_bubble)
	
	# Name label at top of bubble
	dialogue_name_label = Label.new()
	dialogue_name_label.text = "PLAYER"
	dialogue_name_label.position = Vector2(15, 8)
	var font = load("res://Assets/Font/Pixeled.ttf")
	if font:
		dialogue_name_label.add_theme_font_override("font", font)
	dialogue_name_label.add_theme_font_size_override("font_size", 14)
	dialogue_name_label.add_theme_color_override("font_color", Color.RED)
	dialogue_bubble.add_child(dialogue_name_label)
	
	# Dialogue text inside bubble
	dialogue_label = Label.new()
	dialogue_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_label.offset_left = 15
	dialogue_label.offset_top = 40
	dialogue_label.offset_right = -15
	dialogue_label.offset_bottom = -15
	if font:
		dialogue_label.add_theme_font_override("font", font)
	dialogue_label.add_theme_font_size_override("font_size", 12)
	dialogue_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_bubble.add_child(dialogue_label)
	
	# Initially hide the dialogue
	dialogue_bubble.modulate.a = 0.0
	
	# ── Console panel (CMD.png-based or fallback) ──
	var cmd_texture = load("res://Assets/CMD.png")
	
	if cmd_texture:
		_use_cmd_panel = true
		cmd_panel = TextureRect.new()
		cmd_panel.set_anchors_preset(Control.PRESET_CENTER)
		cmd_panel.offset_left = -200
		cmd_panel.offset_right = 200
		cmd_panel.offset_top = 50
		cmd_panel.offset_bottom = 200
		cmd_panel.texture = cmd_texture
		cmd_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cmd_panel.stretch_mode = TextureRect.STRETCH_SCALE
		cmd_panel.modulate.a = 0.0
		popup_panel.add_child(cmd_panel)
		
		# Body text area using RichTextLabel
		cmd_body_label = RichTextLabel.new()
		cmd_body_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		cmd_body_label.offset_left = 10
		cmd_body_label.offset_top = 30
		cmd_body_label.offset_right = -10
		cmd_body_label.offset_bottom = -10
		cmd_body_label.bbcode_enabled = false
		cmd_body_label.scroll_following = true
		if font:
			cmd_body_label.add_theme_font_override("normal_font", font)
		cmd_body_label.add_theme_font_size_override("normal_font_size", 14)
		cmd_body_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
		cmd_panel.add_child(cmd_body_label)
		
		# Keep fake_console reference pointing to a hidden TextEdit for compatibility
		fake_console = TextEdit.new()
		fake_console.visible = false
		popup_panel.add_child(fake_console)
	else:
		push_warning("CMD.png not found at res://Assets/CMD.png — falling back to ColorRect console panel")
		_use_cmd_panel = false
		fake_console = TextEdit.new()
		fake_console.set_anchors_preset(Control.PRESET_CENTER)
		fake_console.offset_left = -200
		fake_console.offset_right = 200
		fake_console.offset_top = 50
		fake_console.offset_bottom = 200
		fake_console.editable = false
		fake_console.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		fake_console.add_theme_font_size_override("font_size", 18)
		fake_console.modulate.a = 0.0
		popup_panel.add_child(fake_console)

func trigger_attack(inconvenience_name: String) -> void:
	if is_attacking: return
	is_attacking = true
	_current_inconvenience = inconvenience_name
	total_inconveniences += 1
	
	# Pause the game
	get_tree().paused = true
	popup_panel.visible = true
	if _use_cmd_panel:
		cmd_body_label.text = ""
		cmd_panel.modulate.a = 0.0
	else:
		fake_console.text = ""
		fake_console.modulate.a = 0.0
	dialogue_label.text = ""
	dialogue_bubble.modulate.a = 0.0
	
	# Set player to PROCESS_MODE_ALWAYS so animations play while paused
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.is_locked = true
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.5)
	
	# Fade in dialogue bubble
	tween.tween_property(dialogue_bubble, "modulate:a", 1.0, 0.3)
	
	# 1. Milestone dialogues (play BEFORE the inconvenience dialogue if milestone is hit)
	if milestone_dialogues.has(total_inconveniences):
		var milestone_lines = milestone_dialogues[total_inconveniences]
		for line in milestone_lines:
			tween.tween_callback(func(): dialogue_label.text = line)
			var display_time = clampf(line.length() * 0.06, 1.5, 4.5)
			tween.tween_interval(display_time)
	
	# 2. Play the specific inconvenience dialogue
	var specific_lines = ["Initiating protocol..."]
	if inconvenience_dialogues.has(_current_inconvenience):
		specific_lines = inconvenience_dialogues[_current_inconvenience]
		
	for line in specific_lines:
		tween.tween_callback(func(): dialogue_label.text = line)
		var display_time = clampf(line.length() * 0.06, 1.5, 4.5)
		tween.tween_interval(display_time)
	
	# 3. Fade out dialogue, play attack animation, then fade in console
	tween.tween_property(dialogue_bubble, "modulate:a", 0.0, 0.3)
	
	# Trigger attack animation — plays WHILE console fades in
	if player and player.has_method("play_state"):
		tween.tween_callback(func(): player.play_state("attack"))
	
	tween.tween_interval(0.3)
	
	# Fade in console and type
	if _use_cmd_panel:
		tween.tween_property(cmd_panel, "modulate:a", 0.8, 0.4)
	else:
		tween.tween_property(fake_console, "modulate:a", 0.8, 0.4)
	tween.tween_callback(_type_console_command)

func _type_console_command() -> void:
	var cmd = "[st_inject --payload " + _current_inconvenience + "]"
	if console_commands.has(_current_inconvenience):
		cmd = console_commands[_current_inconvenience]
	
	var full_text = "> " + cmd + "\n"
	full_text += "Executing...\n"
	full_text += "Success. Payload delivered."
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var type_speed = 0.04
	
	if _use_cmd_panel:
		cmd_body_label.text = ""
		for i in range(full_text.length()):
			var char_idx = i
			tween.tween_callback(func(): cmd_body_label.text += full_text[char_idx])
			tween.tween_interval(type_speed)
	else:
		fake_console.text = ""
		for i in range(full_text.length()):
			var char_idx = i
			tween.tween_callback(func(): fake_console.text += full_text[char_idx])
			tween.tween_interval(type_speed)
		
	tween.tween_interval(1.5)
	tween.tween_callback(_finish_attack)

func _finish_attack() -> void:
	popup_panel.visible = false
	get_tree().paused = false
	is_attacking = false
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.is_locked = false
		# Reset to idle after attack
		if player.has_method("play_state"):
			var idle_anim = player._get_idle_anim()
			player.play_state(idle_anim)
	
	sequence_finished.emit()
	
	if not _first_attack_seen:
		_first_attack_seen = true
		_show_retaliation_tutorial()

func _show_retaliation_tutorial() -> void:
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(func():
		var tutorial_scene = load("res://Scenes/UI/LoopTutorial.tscn")
		if tutorial_scene:
			var tut = tutorial_scene.instantiate()
			get_tree().current_scene.add_child(tut)
	)

func reset_attack_state() -> void:
	_first_attack_seen = false
