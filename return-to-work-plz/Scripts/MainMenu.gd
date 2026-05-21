extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var options_button = $VBoxContainer/OptionsButton
@onready var about_button = $VBoxContainer/AboutButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var logo_rect = $LogoRect
@onready var background_rect = $BackgroundRect

var about_panel: ColorRect = null

#suara hoover + click
@onready var click_sfx: AudioStreamPlayer2D = $ClickSFX
@onready var hover_sfx: AudioStreamPlayer2D = $HoverSFX


# Settings panel references
@onready var settings_panel = $SettingsPanel
@onready var close_btn = $SettingsPanel/CloseBtn
@onready var reset_btn = $SettingsPanel/MainBox/Footer/ResetBtn
@onready var apply_btn = $SettingsPanel/MainBox/Footer/ApplyBtn

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

# Keybind system
var keybind_buttons: Dictionary = {}
var awaiting_rebind: String = ""
var keybind_actions: Array = ["move_left", "move_right", "interact"]
var keybind_display_names: Dictionary = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"interact": "Interact",
}

# Defaults (same as PauseMenu)
const DEFAULTS = {
	"master_vol": 50.0,
	"music_vol": 50.0,
	"sfx_vol": 50.0,
	"audio_type": 0,
	"fps_cap": 60,
	"brightness": 100.0,
}
const SETTINGS_PATH = "user://settings.cfg"

var stationary_npcs = []
var moving_npcs = []
var backgrounds = []
var active_moving_npcs = []

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	about_button.pressed.connect(_on_about_pressed)
	
	# Hubungkan fungsi hover (mouse masuk ke area button)
	play_button.mouse_entered.connect(_on_button_hover)
	exit_button.mouse_entered.connect(_on_button_hover)
	options_button.mouse_entered.connect(_on_button_hover)
	about_button.mouse_entered.connect(_on_button_hover)
	
	# Settings signals
	close_btn.pressed.connect(_close_settings)
	reset_btn.pressed.connect(_reset_settings)
	apply_btn.pressed.connect(_apply_settings)
	
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
	
	_build_keybind_ui()
	load_settings()
	settings_panel.visible = false
	
	_load_resources()
	_setup_random_menu()
	
	# Putar animasi intro UI
	_play_intro_animation()

func _play_intro_animation():
	# Persiapan state awal
	logo_rect.pivot_offset = logo_rect.size / 2.0
	logo_rect.scale = Vector2.ZERO
	
	var vbox = $VBoxContainer
	var vbox_original_y = vbox.position.y
	vbox.position.y = vbox_original_y - 200 # Posisikan di balik logo
	
	for btn in vbox.get_children():
		btn.modulate.a = 0.0 # Tombol transparan di awal
		
	var tween = create_tween()
	
	# 1. Fase Kemunculan Logo (00:00 - 00:01)
	# Membesar dari 0 ke 1 dengan overshoot (bounce / spring)
	tween.tween_property(logo_rect, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Fase Kemunculan Tombol (00:01 - 00:02)
	# VBox turun ke bawah (drop-down)
	tween.tween_property(vbox, "position:y", vbox_original_y, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Tombol muncul satu per satu (cascade)
	var delay = 0.0
	for btn in vbox.get_children():
		tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(delay)
		delay += 0.2
		
	# Lanjut ke animasi idle (00:02 - dst)
	tween.tween_callback(_start_idle_animation)

func _start_idle_animation():
	var idle_tween = create_tween().set_loops()
	# Breathing / Pulsing animation (membesar-mengecil perlahan)
	idle_tween.tween_property(logo_rect, "scale", Vector2(1.05, 1.05), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(logo_rect, "scale", Vector2(1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta):
	for data in active_moving_npcs:
		var npc = data.npc
		var speed = data.speed
		if data.moving_right:
			npc.position.x += speed * delta
			if npc.position.x > data.right_bound:
				data.moving_right = false
				# Langsung pakai variabel data.moving_right (nilainya sekarang false)
				_flip_npc(npc, data.moving_right) 
		else:
			npc.position.x -= speed * delta
			if npc.position.x < data.left_bound:
				data.moving_right = true
				# Langsung pakai variabel data.moving_right (nilainya sekarang true)
				_flip_npc(npc, data.moving_right)

func _unhandled_input(event: InputEvent) -> void:
	if awaiting_rebind != "":
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_rebind(event)
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause") and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()

func _flip_npc(npc: Node, moving_right: bool):
	var sprite = npc.get_node_or_null("Sprite")
	if sprite: sprite.scale.x = (-1.0 if moving_right else 1.0) * abs(sprite.scale.x)
	var anim_sprite = npc.get_node_or_null("AnimSprite")
	if anim_sprite: anim_sprite.scale.x = (-1.0 if moving_right else 1.0) * abs(anim_sprite.scale.x)

func _load_resources():
	# Load backgrounds
	var bg_dir = DirAccess.open("res://Assets/Rooms")
	if bg_dir:
		bg_dir.list_dir_begin()
		var file_name = bg_dir.get_next()
		while file_name != "":
			# Bersihkan suffix .import kalau ada
			var clean_name = file_name.trim_suffix(".import")
			
			if not bg_dir.current_is_dir() and clean_name.ends_with(".png"):
				backgrounds.append("res://Assets/Rooms/" + clean_name)
			file_name = bg_dir.get_next()
			
	# Load NPCs
	var npc_dir = DirAccess.open("res://Scenes/NPCs")
	if npc_dir:
		npc_dir.list_dir_begin()
		var file_name = npc_dir.get_next()
		while file_name != "":
			# Bersihkan suffix .remap kalau ada
			var clean_name = file_name.trim_suffix(".remap")
			
			if not npc_dir.current_is_dir() and clean_name.ends_with(".tscn") and clean_name != "StationaryNPC.tscn" and clean_name != "MovingNPC.tscn":
				var path = "res://Scenes/NPCs/" + clean_name
				var scene = load(path)
				if scene:
					var inst = scene.instantiate()
					if inst and inst.get_script():
						var script_path = inst.get_script().resource_path
						if "NPCStationary.gd" in script_path:
							stationary_npcs.append(scene)
						elif "NPCMoving.gd" in script_path:
							moving_npcs.append(scene)
					if inst:
						inst.queue_free()
			file_name = npc_dir.get_next()

func _setup_random_menu():
	randomize()
	
	# 1. Random Background
	if backgrounds.size() > 0:
		var random_bg = backgrounds[randi() % backgrounds.size()]
		var tex = load(random_bg)
		if tex and background_rect != null:
			background_rect.texture = tex
	
	# 2. Randomize NPCs
	stationary_npcs.shuffle()
	moving_npcs.shuffle()
	
	var screen_size = get_viewport_rect().size
	var ground_y = screen_size.y * 0.9
	if ground_y < 800:
		ground_y = 950 # Fallback for 1080p
		
	var npc_container = Node2D.new()
	npc_container.name = "NPCs"
	add_child(npc_container)
	move_child(npc_container, 1) # Behind UI
	# Di dalam fungsi _setup_random_menu()
	# Stationary NPCs (Left and Right edges)
	# Stationary NPCs (Kiri dan Kanan)
	if stationary_npcs.size() >= 1:
		var left_npc = _spawn_npc(stationary_npcs[0], Vector2(screen_size.x * 0.15, ground_y), false, npc_container)
		if left_npc:
			_flip_npc(left_npc, true) # Bikin NPC kiri ngadep kanan (ke logo)
			
	if stationary_npcs.size() >= 2:
		var right_npc = _spawn_npc(stationary_npcs[1], Vector2(screen_size.x * 0.85, ground_y), false, npc_container)
		if right_npc:
			_flip_npc(right_npc, false) # Bikin NPC kanan ngadep kiri (ke logo)
			
	# Moving NPCs (Middle area)
	if moving_npcs.size() >= 1:
		_spawn_npc(moving_npcs[0], Vector2(screen_size.x * 0.35, ground_y), true, npc_container)
	if moving_npcs.size() >= 2:
		_spawn_npc(moving_npcs[1], Vector2(screen_size.x * 0.65, ground_y), true, npc_container)

func _spawn_npc(scene: PackedScene, pos: Vector2, is_moving: bool, parent: Node) -> Node:
	var inst = scene.instantiate()
	parent.add_child(inst)
	inst.position = pos
	
	# Disable physics processing and standard processing
	inst.set_physics_process(false)
	inst.set_process(false)
	
	# Disable collisions and dialogue
	for child in inst.get_children():
		if child is CollisionShape2D or child is Area2D:
			child.queue_free()
	
	if inst.has_node("DialogueBox"):
		inst.get_node("DialogueBox").visible = false
		inst.get_node("DialogueBox").queue_free()
		
	if is_moving:
		# Extract speed if it exists, otherwise use default
		var speed = 80.0
		if "move_speed" in inst:
			speed = inst.move_speed
			
		var screen_w = get_viewport_rect().size.x
		var patrol_range = 300.0
		var left_b = pos.x - patrol_range
		var right_b = pos.x + patrol_range
		
		# Keep within screen bounds (roughly)
		left_b = max(left_b, screen_w * 0.2)
		right_b = min(right_b, screen_w * 0.8)
		
		active_moving_npcs.append({
			"npc": inst,
			"speed": speed,
			"moving_right": true,
			"left_bound": left_b,
			"right_bound": right_b
		})
		_flip_npc(inst, true)
	var anim_sprite = inst.get_node_or_null("AnimSprite")
	if anim_sprite:
		anim_sprite.frame = randi() % anim_sprite.sprite_frames.get_frame_count(anim_sprite.animation)

		
	return inst

# ═══════════════════════════════════════════
# MENU BUTTONS
# ═══════════════════════════════════════════

func _on_button_hover():
	UISoundManager.play_hover()

func play_click():
	UISoundManager.play_click()

func _on_play_pressed():
	UISoundManager.play_click()
	if has_node("/root/GameManager"):
		GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_options_pressed():
	UISoundManager.play_click()
	settings_panel.visible = true

func _on_exit_pressed():
	UISoundManager.play_click()
	print("Exit button pressed")
	get_tree().quit()

func _create_about_button() -> void:
	about_button = Button.new()
	about_button.text = "ABOUT"
	about_button.custom_minimum_size = Vector2(400, 70)
	
	# Style to match the menu aesthetic
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(8)
	about_button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.25, 0.25, 0.95)
	hover_style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)
	about_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	pressed_style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(8)
	about_button.add_theme_stylebox_override("pressed", pressed_style)
	
	about_button.add_theme_font_size_override("font_size", 20)
	about_button.add_theme_color_override("font_color", Color.WHITE)
	about_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	
	# Insert between Options and Exit in VBoxContainer
	var vbox = $VBoxContainer
	vbox.add_child(about_button)
	vbox.move_child(about_button, options_button.get_index() + 1)
	
	about_button.pressed.connect(_on_about_pressed)
	about_button.mouse_entered.connect(_on_button_hover)

func _on_about_pressed() -> void:
	UISoundManager.play_click()
	_show_about_panel()

func _show_about_panel() -> void:
	if about_panel and is_instance_valid(about_panel):
		about_panel.visible = true
		return
	
	about_panel = ColorRect.new()
	about_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	about_panel.color = Color(0, 0, 0, 0.0)
	about_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(about_panel)
	
	# Animate: slide menu items up and fade in background
	var vbox = $VBoxContainer
	var logo = logo_rect
	
	var tween = create_tween()
	tween.tween_property(about_panel, "color:a", 0.85, 0.3)
	tween.parallel().tween_property(vbox, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(logo, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): _build_about_content())

func _build_about_content() -> void:
	# Center container for all about text
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	about_panel.add_child(container)
	
	var font = load("res://Assets/Font/Pixeled.ttf")
	
	# "Game by RUI" header
	var header = Label.new()
	header.text = "Game by RUI"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_theme_font_size_override("font_size", 28)
	if font: header.add_theme_font_override("font", font)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(header)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer1)
	
	# Credits
	var credits_data = [
		"Audrick Estrello - Lead Programmer",
		"Nathanael Wijaya - Programmer, UI Designer",
		"Nathaniel Dustin H. - 2D Artist, Animator",
		"Evan Radithya G. - Environment Artist",
	]
	
	for line in credits_data:
		var lbl = Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 16)
		if font: lbl.add_theme_font_override("font", font)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 25)
	container.add_child(spacer2)
	
	# Music credit
	var music_lbl = Label.new()
	music_lbl.text = "Music by Eric Matyas - www.soundimage.org"
	music_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	music_lbl.add_theme_font_size_override("font_size", 14)
	if font: music_lbl.add_theme_font_override("font", font)
	music_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(music_lbl)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer3)
	
	# Back button
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.add_theme_font_size_override("font_size", 18)
	if font: back_btn.add_theme_font_override("font", font)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	btn_style.border_color = Color(1.0, 1.0, 1.0, 0.4)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)
	back_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.3, 0.3, 0.95)
	btn_hover.border_color = Color(1.0, 1.0, 1.0, 0.7)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(8)
	back_btn.add_theme_stylebox_override("hover", btn_hover)
	
	back_btn.pressed.connect(_close_about)
	back_btn.mouse_entered.connect(_on_button_hover)
	container.add_child(back_btn)
	
	# Fade in content
	container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)

func _close_about() -> void:
	UISoundManager.play_click()
	if about_panel and is_instance_valid(about_panel):
		var vbox = $VBoxContainer
		var logo = logo_rect
		var tween = create_tween()
		tween.tween_property(about_panel, "color:a", 0.0, 0.3)
		tween.parallel().tween_property(vbox, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.3)
		tween.tween_callback(func():
			about_panel.queue_free()
			about_panel = null
		)

func _close_settings():
	settings_panel.visible = false
	awaiting_rebind = ""

# ═══════════════════════════════════════════
# KEYBIND SYSTEM
# ═══════════════════════════════════════════

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
		InputMap.action_erase_events(action)
		keybind_buttons[action].text = "NONE"
		return
	
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

func _on_brightness_changed(_val: float) -> void:
	# No BrightnessOverlay in MainMenu, just store the value
	pass

func _apply_settings() -> void:
	Engine.max_fps = int(fps_input.value)
	save_settings()

func _reset_settings() -> void:
	master_slider.value = DEFAULTS["master_vol"]
	music_slider.value = DEFAULTS["music_vol"]
	sfx_slider.value = DEFAULTS["sfx_vol"]
	audio_type_dropdown.selected = DEFAULTS["audio_type"]
	fps_input.value = DEFAULTS["fps_cap"]
	brightness_slider.value = DEFAULTS["brightness"]
	_apply_settings()
	
	InputMap.load_from_project_settings()
	_build_keybind_ui()
	
	print("[MainMenu Settings] Reset to defaults")
	save_settings()

# ═══════════════════════════════════════════
# SAVE & LOAD
# ═══════════════════════════════════════════

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
	print("[MainMenu Settings] Saved to ", SETTINGS_PATH)

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
	_on_audio_type_changed(audio_type_dropdown.selected)
	print("[MainMenu Settings] Loaded from ", SETTINGS_PATH)
