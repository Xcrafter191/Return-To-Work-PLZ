extends CanvasLayer

@onready var text_label: Label = $ColorRect/VBoxContainer/TextLabel
@onready var continue_label: Label = $ColorRect/VBoxContainer/ContinueLabel

var current_step: int = 0
var dialogues: Array = [
	"YOUR CHARACTER HAS GAINED SENTIENCE.\nFROM NOW ON, HE WILL RESIST YOU!",
	"YOU HAVE BEEN HINDERED BY YOUR CHARACTER.\nSOME OF THESE ATTACKS CAN BE COUNTERED\nFROM INTERACTING WITH THE SETTINGS"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# Release any active UI focus so Space doesn't activate other buttons
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
		
	_show_current_dialogue()
	_animate_continue_label()

func _show_current_dialogue() -> void:
	if current_step < dialogues.size():
		text_label.text = dialogues[current_step]
		# Soft fade-in animation
		text_label.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(text_label, "modulate:a", 1.0, 0.35)
	else:
		_finish_tutorial()

func _animate_continue_label() -> void:
	continue_label.modulate.a = 1.0
	var tween = create_tween().set_loops()
	tween.tween_property(continue_label, "modulate:a", 0.15, 0.6)
	tween.tween_property(continue_label, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			# Release focus again just in case a control stole it in the meantime
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
				
			UISoundManager.play_click()
			current_step += 1
			_show_current_dialogue()
			get_viewport().set_input_as_handled()

func _finish_tutorial() -> void:
	get_tree().paused = false
	queue_free()
