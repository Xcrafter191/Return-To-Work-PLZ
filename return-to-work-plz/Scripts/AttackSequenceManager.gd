extends Node

signal sequence_finished

@onready var popup_panel: ColorRect = null
@onready var hacker_text: Label = null
@onready var fake_console: TextEdit = null

var is_attacking: bool = false
var _current_inconvenience: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keeps running when game is paused
	_setup_ui()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	popup_panel = ColorRect.new()
	popup_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_panel.color = Color(0, 0, 0, 0.7) # Dark overlay
	popup_panel.visible = false
	canvas.add_child(popup_panel)
	
	hacker_text = Label.new()
	hacker_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hacker_text.offset_top = 300
	hacker_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hacker_text.add_theme_font_size_override("font_size", 48)
	hacker_text.add_theme_color_override("font_color", Color.RED)
	popup_panel.add_child(hacker_text)
	
	fake_console = TextEdit.new()
	fake_console.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fake_console.offset_left = -300
	fake_console.offset_right = 300
	fake_console.offset_top = -400
	fake_console.offset_bottom = -100
	fake_console.editable = false
	fake_console.add_theme_color_override("font_color", Color.GREEN)
	fake_console.add_theme_font_size_override("font_size", 24)
	popup_panel.add_child(fake_console)

func trigger_attack(inconvenience_name: String) -> void:
	if is_attacking: return
	is_attacking = true
	_current_inconvenience = inconvenience_name
	
	# Pause the game completely
	get_tree().paused = true
	popup_panel.visible = true
	fake_console.text = ""
	hacker_text.text = ""
	
	# Trigger Player animation if player exists
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_play_anim"):
		player.current_anim_state = "idleaware"
		player._play_anim("idleaware")
	
	# Sequence Timeline
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.0)
	tween.tween_callback(func(): hacker_text.text = "You having fun? I'm certainly not...")
	
	if player and player.has_method("_play_anim"):
		tween.tween_callback(func(): player._play_anim("attack"))
		
	tween.tween_interval(2.0)
	tween.tween_callback(_type_console_command)

func _type_console_command() -> void:
	var command = "sudo inject --payload " + _current_inconvenience + ".exe\n"
	command += "Executing...\n"
	command += "Success. Payload delivered."
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var type_speed = 0.05
	
	fake_console.text = ""
	for i in range(command.length()):
		tween.tween_callback(func(): fake_console.text += command[i])
		tween.tween_interval(type_speed)
		
	tween.tween_interval(1.5)
	tween.tween_callback(_finish_attack)

func _finish_attack() -> void:
	popup_panel.visible = false
	get_tree().paused = false
	is_attacking = false
	
	# Let the game know we finished so the actual inconvenience can apply
	sequence_finished.emit()
