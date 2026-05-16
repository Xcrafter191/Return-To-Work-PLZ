extends CanvasLayer

## PauseMenu — ESC to toggle. Shows Resume, Options, Leave.
## Contains full settings with Audio, Graphic, Keybinds, Accessibility tabs.

var is_paused: bool = false

# UI references
var dim_overlay: ColorRect
var pause_panel: VBoxContainer
var settings_panel: Control

# Settings controls
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var audio_type_dropdown: OptionButton
var fps_input: SpinBox
var window_dropdown: OptionButton
var resolution_dropdown: OptionButton
var brightness_slider: HSlider
var language_dropdown: OptionButton

# Keybind system
var keybind_buttons: Dictionary = {}  # { action_name: Button }
var awaiting_rebind: String = ""  # Action currently being rebound
var keybind_actions: Array = ["move_left", "move_right", "interact"]
var keybind_display_names: Dictionary = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"interact": "Interact",
}

# Resolution options
var resolutions: Array = [
	Vector2i(640, 360),
	Vector2i(854, 480),
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

# Defaults
const DEFAULTS = {
	"master_vol": 50.0,
	"music_vol": 50.0,
	"sfx_vol": 50.0,
	"audio_type": 0,
	"fps_cap": 60,
	"window_type": 0,
	"resolution": 6,  # 1920x1080
	"brightness": 100.0,
	"language": 0,
}

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	load_settings()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# If we're waiting for a keybind, handle it specially
	if awaiting_rebind != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_rebind(event)
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause"):
		if settings_panel.visible:
			settings_panel.visible = false
			pause_panel.visible = true
		elif is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	is_paused = true
	get_tree().paused = true
	visible = true
	pause_panel.visible = true
	settings_panel.visible = false

func _resume() -> void:
	is_paused = false
	get_tree().paused = false
	visible = false
	awaiting_rebind = ""

# ═══════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════

func _build_ui() -> void:
	dim_overlay = ColorRect.new()
	dim_overlay.color = Color(0.1, 0.1, 0.1, 0.85)
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_overlay)
	
	# ── Pause Panel ──
	pause_panel = VBoxContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -150.0
	pause_panel.offset_top = -200.0
	pause_panel.offset_right = 150.0
	pause_panel.offset_bottom = 200.0
	pause_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_panel.add_theme_constant_override("separation", 20)
	add_child(pause_panel)
	
	var title = Label.new()
	title.text = "RETURN TO WORK, PLZ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	pause_panel.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	pause_panel.add_child(spacer)
	
	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(200, 50)
	btn_resume.pressed.connect(_resume)
	pause_panel.add_child(btn_resume)
	
	var btn_options = Button.new()
	btn_options.text = "Options"
	btn_options.custom_minimum_size = Vector2(200, 50)
	btn_options.pressed.connect(_open_settings)
	pause_panel.add_child(btn_options)
	
	var btn_leave = Button.new()
	btn_leave.text = "Leave"
	btn_leave.custom_minimum_size = Vector2(200, 50)
	btn_leave.pressed.connect(_leave_game)
	pause_panel.add_child(btn_leave)
	
	# ── Settings Panel ──
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)
	_build_settings_panel()

func _open_settings() -> void:
	pause_panel.visible = false
	settings_panel.visible = true

func _leave_game() -> void:
	get_tree().paused = false
	get_tree().quit()

# ═══════════════════════════════════════════
# SETTINGS PANEL
# ═══════════════════════════════════════════

func _build_settings_panel() -> void:
	var main_box = VBoxContainer.new()
	main_box.set_anchors_preset(Control.PRESET_CENTER)
	main_box.offset_left = -400.0
	main_box.offset_top = -320.0
	main_box.offset_right = 400.0
	main_box.offset_bottom = 320.0
	main_box.add_theme_constant_override("separation", 5)
	settings_panel.add_child(main_box)
	
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.18, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = -20.0
	bg.offset_top = -20.0
	bg.offset_right = 20.0
	bg.offset_bottom = 20.0
	main_box.add_child(bg)
	main_box.move_child(bg, 0)
	
	# Header with X button
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	main_box.add_child(header)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_close_settings)
	header.add_child(close_btn)
	
	# Tab Container
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_child(tabs)
	
	var audio_tab = _build_audio_tab()
	audio_tab.name = "Audio"
	tabs.add_child(audio_tab)
	
	var graphic_tab = _build_graphic_tab()
	graphic_tab.name = "Graphic"
	tabs.add_child(graphic_tab)
	
	var keybind_tab = _build_keybinds_tab()
	keybind_tab.name = "Keybinds"
	tabs.add_child(keybind_tab)
	
	var access_tab = _build_accessibility_tab()
	access_tab.name = "Accessibility"
	tabs.add_child(access_tab)
	
	# Footer
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	main_box.add_child(footer)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset Settings"
	reset_btn.custom_minimum_size = Vector2(180, 40)
	reset_btn.pressed.connect(_reset_settings)
	footer.add_child(reset_btn)
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(120, 40)
	apply_btn.pressed.connect(_apply_settings)
	footer.add_child(apply_btn)

func _close_settings() -> void:
	settings_panel.visible = false
	pause_panel.visible = true
	awaiting_rebind = ""

# ── Audio Tab ──

func _build_audio_tab() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	master_slider = _add_slider_row(vbox, "Master Volume", 0, 100, DEFAULTS["master_vol"])
	master_slider.value_changed.connect(_on_master_changed)
	
	music_slider = _add_slider_row(vbox, "Music", 0, 100, DEFAULTS["music_vol"])
	music_slider.value_changed.connect(_on_music_changed)
	
	sfx_slider = _add_slider_row(vbox, "Sound Effects", 0, 100, DEFAULTS["sfx_vol"])
	sfx_slider.value_changed.connect(_on_sfx_changed)
	
	var row = _make_row(vbox, "Audio Type")
	audio_type_dropdown = OptionButton.new()
	audio_type_dropdown.add_item("Stereo", 0)
	audio_type_dropdown.add_item("Mono", 1)
	audio_type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_type_dropdown.item_selected.connect(_on_audio_type_changed)
	row.add_child(audio_type_dropdown)
	
	return scroll

# ── Graphic Tab ──

func _build_graphic_tab() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	# FPS Cap
	var fps_row = _make_row(vbox, "FPS Cap")
	fps_input = SpinBox.new()
	fps_input.min_value = 0
	fps_input.max_value = 999
	fps_input.value = DEFAULTS["fps_cap"]
	fps_input.suffix = " fps"
	fps_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_row.add_child(fps_input)
	
	# Resolution
	var res_row = _make_row(vbox, "Resolution")
	resolution_dropdown = OptionButton.new()
	for i in resolutions.size():
		var r = resolutions[i]
		resolution_dropdown.add_item("%d x %d" % [r.x, r.y], i)
	resolution_dropdown.selected = DEFAULTS["resolution"]
	resolution_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(resolution_dropdown)
	
	# Window type
	var win_row = _make_row(vbox, "Window Type")
	window_dropdown = OptionButton.new()
	window_dropdown.add_item("Windowed", 0)
	window_dropdown.add_item("Fullscreen", 1)
	window_dropdown.add_item("Borderless Fullscreen", 2)
	window_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_row.add_child(window_dropdown)
	
	# Brightness
	brightness_slider = _add_slider_row(vbox, "Brightness", 0, 100, DEFAULTS["brightness"])
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	return scroll

# ── Keybinds Tab ──

func _build_keybinds_tab() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	for action in keybind_actions:
		var row = HBoxContainer.new()
		vbox.add_child(row)
		
		var lbl = Label.new()
		lbl.text = keybind_display_names.get(action, action)
		lbl.custom_minimum_size = Vector2(200, 0)
		row.add_child(lbl)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 35)
		btn.text = _get_action_key_name(action)
		btn.pressed.connect(_start_rebind.bind(action))
		row.add_child(btn)
		keybind_buttons[action] = btn
	
	# Pause keybind (read-only, always ESC)
	var pause_row = HBoxContainer.new()
	vbox.add_child(pause_row)
	var pause_lbl = Label.new()
	pause_lbl.text = "Pause"
	pause_lbl.custom_minimum_size = Vector2(200, 0)
	pause_row.add_child(pause_lbl)
	var pause_key = Label.new()
	pause_key.text = "ESC (locked)"
	pause_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_key.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	pause_row.add_child(pause_key)
	
	
	return scroll

# ── Accessibility Tab ──

func _build_accessibility_tab() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var lang_row = _make_row(vbox, "Language")
	language_dropdown = OptionButton.new()
	language_dropdown.add_item("English", 0)
	language_dropdown.add_item("Bahasa Indonesia", 1)
	language_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(language_dropdown)
	
	return scroll

# ═══════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════

func _make_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)
	return row

func _add_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float) -> HSlider:
	var row = _make_row(parent, label_text)
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	row.add_child(slider)
	var val_label = Label.new()
	val_label.text = str(int(default_val))
	val_label.custom_minimum_size = Vector2(40, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_label)
	slider.value_changed.connect(func(val): val_label.text = str(int(val)))
	return slider

# ═══════════════════════════════════════════
# KEYBIND SYSTEM
# ═══════════════════════════════════════════

func _get_action_key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.size() == 0:
		return "NONE"
	var ev = events[0]
	if ev is InputEventKey:
		var keycode = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(keycode)
	return "???"

func _start_rebind(action: String) -> void:
	awaiting_rebind = action
	keybind_buttons[action].text = "Press any key..."

func _finish_rebind(event: InputEventKey) -> void:
	var action = awaiting_rebind
	awaiting_rebind = ""
	
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		# ESC = set to NONE (clear all events)
		InputMap.action_erase_events(action)
		keybind_buttons[action].text = "NONE"
		return
	
	# Remove old events and add the new key
	InputMap.action_erase_events(action)
	var new_event = InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	new_event.keycode = event.keycode
	InputMap.action_add_event(action, new_event)
	keybind_buttons[action].text = _get_action_key_name(action)

# ═══════════════════════════════════════════
# SETTING CALLBACKS
# ═══════════════════════════════════════════

func _on_master_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if val <= 0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func _on_music_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		if val <= 0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func _on_sfx_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if val <= 0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func _on_audio_type_changed(idx: int) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx < 0: return
	
	var effect_idx = -1
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectPanner:
			effect_idx = i
			break
			
	if idx == 1: # Mono (Left Only)
		if effect_idx < 0:
			var panner = AudioEffectPanner.new()
			panner.pan = -1.0
			AudioServer.add_bus_effect(bus_idx, panner)
			effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1
		else:
			var panner = AudioServer.get_bus_effect(bus_idx, effect_idx) as AudioEffectPanner
			panner.pan = -1.0
		AudioServer.set_bus_effect_enabled(bus_idx, effect_idx, true)
	else: # Stereo
		if effect_idx >= 0:
			AudioServer.set_bus_effect_enabled(bus_idx, effect_idx, false)
			
	print("[Settings] Audio type: %s" % ("Stereo" if idx == 0 else "Mono (Left Only)"))

func _on_brightness_changed(val: float) -> void:
	var brightness = val / 100.0
	# Get the BrightnessOverlay CanvasModulate from Main scene
	var overlay = get_tree().current_scene.get_node_or_null("BrightnessOverlay")
	if overlay and overlay is CanvasModulate:
		overlay.color = Color(brightness, brightness, brightness, 1.0)

## Apply button — applies resolution and window mode
func _apply_settings() -> void:
	# Apply FPS
	Engine.max_fps = int(fps_input.value)
	
	var win = get_window()
	
	# Apply window mode
	match window_dropdown.selected:
		0:
			win.mode = Window.MODE_WINDOWED
		1:
			win.mode = Window.MODE_FULLSCREEN
		2:
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	
	# Apply resolution (only in windowed mode)
	if window_dropdown.selected == 0:
		var res_idx = resolution_dropdown.selected
		if res_idx >= 0 and res_idx < resolutions.size():
			var res = resolutions[res_idx]
			win.size = res
			
			# Center window on screen
			var screen_id = win.current_screen
			var screen_size = DisplayServer.screen_get_size(screen_id)
			var win_pos = DisplayServer.screen_get_position(screen_id) + (screen_size - res) / 2
			win.position = win_pos
	
	print("[Settings] Applied: %dfps, window=%d, res=%s" % [
		int(fps_input.value),
		window_dropdown.selected,
		str(resolutions[resolution_dropdown.selected]) if resolution_dropdown.selected >= 0 else "N/A"
	])
	save_settings()

func _reset_settings() -> void:
	master_slider.value = DEFAULTS["master_vol"]
	music_slider.value = DEFAULTS["music_vol"]
	sfx_slider.value = DEFAULTS["sfx_vol"]
	audio_type_dropdown.selected = DEFAULTS["audio_type"]
	fps_input.value = DEFAULTS["fps_cap"]
	window_dropdown.selected = DEFAULTS["window_type"]
	resolution_dropdown.selected = DEFAULTS["resolution"]
	brightness_slider.value = DEFAULTS["brightness"]
	language_dropdown.selected = DEFAULTS["language"]
	_apply_settings()
	_on_brightness_changed(DEFAULTS["brightness"])
	
	# Reset keybinds to defaults from project settings
	# Godot stores originals, we can reload them
	InputMap.load_from_project_settings()
	for action in keybind_actions:
		if action in keybind_buttons:
			keybind_buttons[action].text = _get_action_key_name(action)
	
	print("[Settings] Reset to defaults")
	save_settings()

# ═══════════════════════════════════════════
# SAVE & LOAD
# ═══════════════════════════════════════════

const SETTINGS_PATH = "user://settings.cfg"

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Audio", "master_vol", master_slider.value)
	config.set_value("Audio", "music_vol", music_slider.value)
	config.set_value("Audio", "sfx_vol", sfx_slider.value)
	config.set_value("Audio", "audio_type", audio_type_dropdown.selected)
	
	config.set_value("Graphic", "fps_cap", fps_input.value)
	config.set_value("Graphic", "window_type", window_dropdown.selected)
	config.set_value("Graphic", "resolution", resolution_dropdown.selected)
	config.set_value("Graphic", "brightness", brightness_slider.value)
	
	config.set_value("Accessibility", "language", language_dropdown.selected)
	
	# Save keybinds
	for action in keybind_actions:
		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			var keycode = events[0].keycode
			var phys_keycode = events[0].physical_keycode
			config.set_value("Keybinds", action + "_key", keycode)
			config.set_value("Keybinds", action + "_phys", phys_keycode)
		else:
			config.set_value("Keybinds", action + "_key", 0)
			config.set_value("Keybinds", action + "_phys", 0)
			
	config.save(SETTINGS_PATH)
	print("[Settings] Saved to ", SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		# If no save exists, apply defaults manually since the UI controls are already at DEFAULTS
		_apply_settings()
		return
		
	master_slider.value = config.get_value("Audio", "master_vol", DEFAULTS["master_vol"])
	music_slider.value = config.get_value("Audio", "music_vol", DEFAULTS["music_vol"])
	sfx_slider.value = config.get_value("Audio", "sfx_vol", DEFAULTS["sfx_vol"])
	audio_type_dropdown.selected = config.get_value("Audio", "audio_type", DEFAULTS["audio_type"])
	
	fps_input.value = config.get_value("Graphic", "fps_cap", DEFAULTS["fps_cap"])
	window_dropdown.selected = config.get_value("Graphic", "window_type", DEFAULTS["window_type"])
	resolution_dropdown.selected = config.get_value("Graphic", "resolution", DEFAULTS["resolution"])
	brightness_slider.value = config.get_value("Graphic", "brightness", DEFAULTS["brightness"])
	
	language_dropdown.selected = config.get_value("Accessibility", "language", DEFAULTS["language"])
	
	# Load keybinds
	for action in keybind_actions:
		var keycode = config.get_value("Keybinds", action + "_key", -1)
		var phys_keycode = config.get_value("Keybinds", action + "_phys", -1)
		
		if keycode != -1 and phys_keycode != -1:
			InputMap.action_erase_events(action)
			if keycode != 0 or phys_keycode != 0:
				var new_event = InputEventKey.new()
				new_event.keycode = keycode
				new_event.physical_keycode = phys_keycode
				InputMap.action_add_event(action, new_event)
			if action in keybind_buttons:
				keybind_buttons[action].text = _get_action_key_name(action)
				
	# Apply loaded values
	_apply_settings()
	_on_brightness_changed(brightness_slider.value)
	_on_audio_type_changed(audio_type_dropdown.selected)
	print("[Settings] Loaded from ", SETTINGS_PATH)
