extends CanvasLayer

## DebugPanel — Developer tool for manually triggering inconveniences.
## Toggle with Ctrl+Shift+D. Only visible when GameManager.debug_mode is true.
## When debug_mode is false, this panel is completely hidden and the game
## behaves identically to a release build.

const ALL_INCONVENIENCES: Array = [
	"time_accelerate",
	"fake_ad",
	"blur",
	"gibberish",
	"keybind",
	"unpause_hack",
	"time_stop",
	"time_reverse",
	"time_erase",
	"force_room_swap",
]

var panel: PanelContainer
var dropdown: OptionButton
var is_visible: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200  # Above everything else

	_build_ui()
	_hide_panel()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 180)
	panel.position = Vector2(20, 20)  # Top-left corner with padding

	# Style the panel with a dark semi-transparent background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = Color(1.0, 0.4, 0.0, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG: Inconvenience Tester"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "(Ctrl+Shift+D to toggle)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Dropdown with all inconveniences
	var dropdown_label = Label.new()
	dropdown_label.text = "Select Inconvenience:"
	dropdown_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(dropdown_label)

	dropdown = OptionButton.new()
	for i in ALL_INCONVENIENCES.size():
		dropdown.add_item(ALL_INCONVENIENCES[i], i)
	dropdown.item_selected.connect(_on_inconvenience_selected)
	vbox.add_child(dropdown)

	# Trigger button as alternative to dropdown selection
	var trigger_btn = Button.new()
	trigger_btn.text = "Trigger Selected"
	trigger_btn.pressed.connect(_on_trigger_pressed)
	vbox.add_child(trigger_btn)

	add_child(panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Ctrl+Shift+D to toggle debug panel
		if event.keycode == KEY_D and event.ctrl_pressed and event.shift_pressed:
			if not GameManager.debug_mode:
				# Enable debug mode and show panel
				GameManager.debug_mode = true
				_show_panel()
			else:
				# Toggle visibility
				if is_visible:
					_hide_panel()
				else:
					_show_panel()
			get_viewport().set_input_as_handled()

func _show_panel() -> void:
	if not GameManager.debug_mode:
		return
	is_visible = true
	panel.visible = true

func _hide_panel() -> void:
	is_visible = false
	panel.visible = false

func _on_inconvenience_selected(index: int) -> void:
	if not GameManager.debug_mode:
		return
	var choice = ALL_INCONVENIENCES[index]
	_trigger_inconvenience(choice)

func _on_trigger_pressed() -> void:
	if not GameManager.debug_mode:
		return
	var index = dropdown.selected
	if index >= 0 and index < ALL_INCONVENIENCES.size():
		var choice = ALL_INCONVENIENCES[index]
		_trigger_inconvenience(choice)

func _trigger_inconvenience(choice: String) -> void:
	## Triggers the selected inconvenience as if it were rolled from the pool.
	## Routes to the correct difficulty execution function in InconvenienceManager.
	var inc_mgr = get_node_or_null("/root/InconvenienceManager")
	if not inc_mgr:
		push_warning("[DebugPanel] InconvenienceManager not found!")
		return

	print("[DebugPanel] Triggering inconvenience: %s" % choice)

	match choice:
		"time_accelerate":
			inc_mgr._execute_medium("time_accelerate")
		"fake_ad":
			inc_mgr._execute_major("fake_ad")
		"blur":
			inc_mgr._execute_minor("blur")
		"gibberish":
			inc_mgr._execute_major("gibberish")
		"keybind":
			inc_mgr._execute_medium("keybind")
		"unpause_hack":
			inc_mgr.is_unpause_hack = true
			inc_mgr._auto_fix("unpause_hack", inc_mgr.AUTOFIX_NO_SOLUTION)
			print("[DebugPanel] Unpause hack activated!")
		"time_stop":
			inc_mgr._execute_medium("time_stop")
		"time_reverse":
			inc_mgr._execute_major("time_reverse")
		"time_erase":
			inc_mgr._execute_major("time_erase")
		"force_room_swap":
			inc_mgr._execute_medium("force_room_swap")
		_:
			push_warning("[DebugPanel] Unknown inconvenience: %s" % choice)
