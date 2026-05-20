extends CanvasLayer

## PauseMenu — ESC to toggle. Shows Resume, Options, Leave.
## Contains full settings with Audio, Graphic, Keybinds, Accessibility tabs.

var is_paused: bool = false
@onready var click_sfx: AudioStreamPlayer2D = $ClickSFX
@onready var hover_sfx: AudioStreamPlayer2D = $HoverSFX

# UI references
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var pause_panel: VBoxContainer = $PausePanel
@onready var settings_panel: Control = $SettingsPanel

# Buttons
@onready var btn_resume: TextureButton = $PausePanel/BtnResume
@onready var btn_options: TextureButton = $PausePanel/BtnOptions
@onready var btn_leave: TextureButton = $PausePanel/BtnLeave
@onready var close_btn: TextureButton = $SettingsPanel/CloseBtn
@onready var reset_btn: TextureButton = $SettingsPanel/MainBox/Footer/ResetBtn
@onready var apply_btn: TextureButton = $SettingsPanel/MainBox/Footer/ApplyBtn

# Settings controls
@onready var master_slider: HSlider = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/MasterVolRow/MasterSlider
@onready var master_val: Label = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/MasterVolRow/MasterVal
@onready var music_slider: HSlider = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/MusicVolRow/MusicSlider
@onready var music_val: Label = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/MusicVolRow/MusicVal
@onready var sfx_slider: HSlider = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/SfxVolRow/SfxSlider
@onready var sfx_val: Label = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/SfxVolRow/SfxVal
@onready var audio_type_dropdown: OptionButton = $SettingsPanel/MainBox/Tabs/AUDIO/VBox/AudioTypeRow/AudioTypeDropdown

@onready var fps_input: SpinBox = $SettingsPanel/MainBox/Tabs/GRAPHICS/VBox/FpsRow/FpsInput
@onready var brightness_slider: HSlider = $SettingsPanel/MainBox/Tabs/GRAPHICS/VBox/BrightRow/BrightnessSlider
@onready var brightness_val: Label = $SettingsPanel/MainBox/Tabs/GRAPHICS/VBox/BrightRow/BrightnessVal

@onready var keybinds_vbox: VBoxContainer = $SettingsPanel/MainBox/Tabs/KEYBINDS/VBox
@onready var tabs: TabContainer = $SettingsPanel/MainBox/Tabs

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
	_connect_signals()
	_build_keybind_ui()
	load_settings()
	visible = false

func _connect_signals() -> void:
	btn_resume.pressed.connect(_resume)
	btn_options.pressed.connect(_open_settings)
	btn_leave.pressed.connect(_leave_game)
	close_btn.pressed.connect(_close_settings)
	reset_btn.pressed.connect(_reset_settings)
	apply_btn.pressed.connect(_apply_settings)
	
	btn_resume.mouse_entered.connect(_on_button_hover)
	btn_options.mouse_entered.connect(_on_button_hover)
	btn_leave.mouse_entered.connect(_on_button_hover)
	close_btn.mouse_entered.connect(_on_button_hover)
	reset_btn.mouse_entered.connect(_on_button_hover)
	apply_btn.mouse_entered.connect(_on_button_hover)
	
	master_slider.value_changed.connect(_on_master_changed)
	master_slider.value_changed.connect(func(val): master_val.text = str(int(val)))
	music_slider.value_changed.connect(_on_music_changed)
	music_slider.value_changed.connect(func(val): music_val.text = str(int(val)))
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_slider.value_changed.connect(func(val): sfx_val.text = str(int(val)))
	audio_type_dropdown.item_selected.connect(_on_audio_type_changed)
	
	brightness_slider.value_changed.connect(_on_brightness_changed)
	brightness_slider.value_changed.connect(func(val): brightness_val.text = str(int(val)))

func _build_keybind_ui() -> void:
	for child in keybinds_vbox.get_children():
		child.queue_free()
		
	for action in keybind_actions:
		var row = HBoxContainer.new()
		keybinds_vbox.add_child(row)
		
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
	keybinds_vbox.add_child(pause_row)
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

func _unhandled_input(event: InputEvent) -> void:
	# If we're waiting for a keybind, handle it specially
	if awaiting_rebind != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_rebind(event)
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause"):
		if get_tree().current_scene.get_node_or_null("LoopTutorial") != null:
			return # Ignore pause menu inputs when the loop tutorial is active!
			
		if settings_panel.visible:
			settings_panel.visible = false
			pause_panel.visible = true
		elif is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _on_button_hover():
	UISoundManager.play_hover()

func _pause() -> void:
	is_paused = true
	get_tree().paused = true
	visible = true
	pause_panel.visible = true
	settings_panel.visible = false
	InconvenienceManager.try_pause_inconvenience()

func _resume() -> void:
	UISoundManager.play_click()
	is_paused = false
	get_tree().paused = false
	visible = false
	awaiting_rebind = ""

func _open_settings() -> void:
	UISoundManager.play_click()
	pause_panel.visible = false
	settings_panel.visible = true

func _leave_game() -> void:
	UISoundManager.play_click()
	get_tree().paused = false
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _close_settings() -> void:
	UISoundManager.play_click()
	settings_panel.visible = false
	pause_panel.visible = true
	awaiting_rebind = ""

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
	var overlay = get_tree().current_scene.get_node_or_null("BrightnessOverlay")
	if overlay and overlay is CanvasModulate:
		overlay.color = Color(brightness, brightness, brightness, 1.0)

func _apply_settings() -> void:
	UISoundManager.play_click()
	Engine.max_fps = int(fps_input.value)

	print("[Settings] Applied: %dfps" % [
		int(fps_input.value)
	])
	save_settings()

func _reset_settings() -> void:
	UISoundManager.play_click()
	master_slider.value = DEFAULTS["master_vol"]
	music_slider.value = DEFAULTS["music_vol"]
	sfx_slider.value = DEFAULTS["sfx_vol"]
	audio_type_dropdown.selected = DEFAULTS["audio_type"]
	fps_input.value = DEFAULTS["fps_cap"]
	brightness_slider.value = DEFAULTS["brightness"]
	_apply_settings()
	_on_brightness_changed(DEFAULTS["brightness"])
	
	InputMap.load_from_project_settings()
	_build_keybind_ui()
	
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
	config.set_value("Graphic", "brightness", brightness_slider.value)
	
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
		_apply_settings()
		return
		
	master_slider.value = config.get_value("Audio", "master_vol", DEFAULTS["master_vol"])
	music_slider.value = config.get_value("Audio", "music_vol", DEFAULTS["music_vol"])
	sfx_slider.value = config.get_value("Audio", "sfx_vol", DEFAULTS["sfx_vol"])
	audio_type_dropdown.selected = config.get_value("Audio", "audio_type", DEFAULTS["audio_type"])
	
	fps_input.value = config.get_value("Graphic", "fps_cap", DEFAULTS["fps_cap"])
	brightness_slider.value = config.get_value("Graphic", "brightness", DEFAULTS["brightness"])

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
				
	_apply_settings()
	_on_brightness_changed(brightness_slider.value)
	_on_audio_type_changed(audio_type_dropdown.selected)
	print("[Settings] Loaded from ", SETTINGS_PATH)
