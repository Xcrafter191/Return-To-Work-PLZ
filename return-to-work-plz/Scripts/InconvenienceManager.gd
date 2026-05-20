extends Node

## Autoload for managing UX Inconveniences.

enum Difficulty { MINOR, MEDIUM, MAJOR }

var quotas = {
	Difficulty.MINOR: 0,
	Difficulty.MEDIUM: 0,
	Difficulty.MAJOR: 0
}

var triggered = {
	Difficulty.MINOR: 0,
	Difficulty.MEDIUM: 0,
	Difficulty.MAJOR: 0
}

var base_chance: float = 0.0
var accumulated_chance: float = 0.0

# Active permanent inconveniences
var is_shaky: bool = false
var is_gibberish: bool = false
var fake_ads_container: CanvasLayer = null

# New Inconveniences
var is_clock_stopped: bool = false
var is_sprite_flipped: bool = false
var is_unpause_hack: bool = false
var is_upside_down: bool = false
var is_task_deception: bool = false
var is_stuck_99: bool = false
var is_time_stopped: bool = false
var is_time_accelerated: bool = false
var is_time_erased: bool = false

var red_ambience_rect: ColorRect = null
var blur_rect: ColorRect = null

# Auto-fix timer constants
const AUTOFIX_NO_SOLUTION: float = 10.0
const AUTOFIX_HAS_SOLUTION: float = 30.0

func _process(_delta: float) -> void:
	if is_unpause_hack and get_tree().paused:
		get_tree().paused = false
		print("[InconvenienceManager] Hacker un-paused the game!")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.objective_completed.connect(_on_objective_completed)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	RoomManager.room_changed.connect(_on_room_changed)
	_setup_red_ambience()
	_setup_loop_quotas(GameManager.current_loop)

func _on_room_changed(_room_name: String) -> void:
	if is_gibberish:
		var scene = get_tree().current_scene
		if scene:
			_scramble_all_labels(scene)

func _setup_red_ambience() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10 # Below most UI, above world
	red_ambience_rect = ColorRect.new()
	red_ambience_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	red_ambience_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_ambience_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(red_ambience_rect)
	add_child(canvas)

func _update_red_ambience(loop_num: int) -> void:
	if red_ambience_rect:
		var alpha = clampf((loop_num - 1) * 0.05, 0.0, 0.6)
		red_ambience_rect.color.a = alpha

func _setup_loop_quotas(loop_num: int) -> void:
	triggered = { Difficulty.MINOR: 0, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	
	if loop_num == 1:
		base_chance = 0.0
		quotas = { Difficulty.MINOR: 0, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 2:
		base_chance = 0.10
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 3:
		base_chance = 0.15
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 4:
		base_chance = 0.25
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num == 5:
		base_chance = 0.35
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num == 6:
		base_chance = 0.40 # Smoothed curve instead of jumping to 0.50
		quotas = { Difficulty.MINOR: 3, Difficulty.MEDIUM: 2, Difficulty.MAJOR: 1 }
	elif loop_num >= 7 and loop_num <= 10:
		base_chance = 0.50
		quotas = { Difficulty.MINOR: 5, Difficulty.MEDIUM: 4, Difficulty.MAJOR: 2 }
	elif loop_num >= 11 and loop_num <= 15:
		base_chance = 0.80
		quotas = { Difficulty.MINOR: 8, Difficulty.MEDIUM: 5, Difficulty.MAJOR: 3 }
	else:
		base_chance = 1.00
		quotas = { Difficulty.MINOR: 99, Difficulty.MEDIUM: 99, Difficulty.MAJOR: 99 }
	
	accumulated_chance = base_chance

func _on_loop_restarted(loop_num: int) -> void:
	_setup_loop_quotas(loop_num)
	_update_red_ambience(loop_num)
	_reset_permanent_inconveniences()

func _reset_permanent_inconveniences() -> void:
	is_shaky = false
	is_clock_stopped = false
	is_sprite_flipped = false
	is_unpause_hack = false
	is_upside_down = false
	is_task_deception = false
	is_stuck_99 = false
	is_time_stopped = false
	is_time_accelerated = false
	is_time_erased = false
	
	if is_gibberish:
		is_gibberish = false
		var scene = get_tree().current_scene
		if scene:
			_unscramble_all_labels(scene)
			
	if is_instance_valid(fake_ads_container):
		fake_ads_container.queue_free()
		fake_ads_container = null
		
	if is_instance_valid(blur_rect):
		blur_rect.queue_free()
		blur_rect = null
	
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.scale = Vector2.ONE
		
	var main_cam = get_tree().current_scene.get_node_or_null("Camera2D")
	if main_cam:
		main_cam.rotation = 0.0
		
	var pm = get_tree().current_scene.get_node_or_null("PauseMenu")
	if pm:
		InputMap.load_from_project_settings()
		for action in pm.keybind_actions:
			if action in pm.keybind_buttons:
				pm.keybind_buttons[action].text = pm._get_action_key_name(action)
		
	# Reset window resizer if it was triggered
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_objective_completed(_task_id: String) -> void:
	if base_chance <= 0.0: return
	
	# Don't trigger inconveniences when player is about to clock out
	if GameManager.get_current_task_id() == "clock_out":
		return
	
	var all_met = true
	for diff in quotas:
		if triggered[diff] < quotas[diff]:
			all_met = false
			break
	
	if all_met:
		base_chance = 0.0
		accumulated_chance = 0.0
		print("[InconvenienceManager] All quotas met. Chance dropped to 0.")
		return
		
	if randf() <= accumulated_chance:
		_trigger_random_inconvenience()
		accumulated_chance = base_chance
	else:
		accumulated_chance += base_chance

## Called by PauseMenu when the player tries to pause — chance scales with loop
func try_pause_inconvenience() -> void:
	if GameManager.current_loop <= 1: return
	if is_unpause_hack: return  # Already active
	
	var pause_chance = clampf((GameManager.current_loop - 1) * 0.05, 0.0, 0.50)
	if randf() <= pause_chance:
		is_unpause_hack = true
		print("[InconvenienceManager] Unpause hack triggered on pause!")
		_auto_fix("unpause_hack", AUTOFIX_NO_SOLUTION)

func _trigger_random_inconvenience() -> void:
	var pool = []
	for diff in quotas:
		if triggered[diff] < quotas[diff]:
			pool.append(diff)
			
	if pool.is_empty(): return
	
	var chosen_diff = pool.pick_random()
	triggered[chosen_diff] += 1
	
	print("[InconvenienceManager] Triggered inconvenience of difficulty: ", chosen_diff)
	
	var specific_choice = ""
	match chosen_diff:
		Difficulty.MINOR: 
			specific_choice = ["lights_out", "random_ui", "shaky", "sprite_flip", "blur"].pick_random()
		Difficulty.MEDIUM: 
			specific_choice = ["fps", "unplug", "keybind", "time_stop", "time_accelerate", "force_room_swap"].pick_random()
		Difficulty.MAJOR: 
			specific_choice = ["fake_ad", "gibberish", "task_deception", "stuck_99", "time_reverse", "time_erase"].pick_random()
		
	AttackSequenceManager.trigger_attack(specific_choice)
	AttackSequenceManager.sequence_finished.connect(func():
		match chosen_diff:
			Difficulty.MINOR: _execute_minor(specific_choice)
			Difficulty.MEDIUM: _execute_medium(specific_choice)
			Difficulty.MAJOR: _execute_major(specific_choice)
	, CONNECT_ONE_SHOT)

# ── AUTO-FIX SYSTEM ──
# All inconveniences auto-resolve after a timeout so the player isn't stuck.
# No-solution: 5 seconds. Has-solution: 30 seconds.

func _auto_fix(choice: String, timeout: float) -> void:
	var timer = get_tree().create_timer(timeout)
	timer.timeout.connect(func(): _revert_inconvenience(choice))

func _revert_inconvenience(choice: String) -> void:
	print("[InconvenienceManager] Auto-fixing: ", choice)
	match choice:
		"lights_out":
			var main = get_tree().current_scene
			var pm = main.get_node_or_null("PauseMenu") if main else null
			if pm:
				pm.brightness_slider.value = 1.0
				pm._apply_settings()
				pm.save_settings()
		"random_ui":
			var hud = get_tree().current_scene.get_node_or_null("HUD")
			if hud:
				hud.scale = Vector2.ONE
		"shaky":
			is_shaky = false
		"clock_stop":
			is_clock_stopped = false
		"sprite_flip":
			is_sprite_flipped = false
			var players = get_tree().get_nodes_in_group("player")
			for p in players:
				if p.has_node("AnimSprite"):
					p.get_node("AnimSprite").scale.y = abs(p.get_node("AnimSprite").scale.y)
		"blur":
			if is_instance_valid(blur_rect):
				blur_rect.get_parent().queue_free()
				blur_rect = null
		"fps":
			var main = get_tree().current_scene
			var pm = main.get_node_or_null("PauseMenu") if main else null
			if pm:
				pm.fps_input.value = 60.0
				pm._apply_settings()
				pm.save_settings()
		"unpause_hack":
			is_unpause_hack = false
		"upside_down":
			is_upside_down = false
			var main_cam = get_tree().current_scene.get_node_or_null("Camera2D")
			if main_cam:
				main_cam.rotation = 0.0
		"window_resizer":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"keybind":
			var main = get_tree().current_scene
			var pm = main.get_node_or_null("PauseMenu") if main else null
			if pm:
				InputMap.load_from_project_settings()
				for action in pm.keybind_actions:
					if action in pm.keybind_buttons:
						pm.keybind_buttons[action].text = pm._get_action_key_name(action)
				pm.save_settings()
		"gibberish":
			if is_gibberish:
				is_gibberish = false
				var scene = get_tree().current_scene
				if scene:
					_unscramble_all_labels(scene)
		"fake_ad":
			if is_instance_valid(fake_ads_container):
				fake_ads_container.queue_free()
				fake_ads_container = null
		"task_deception":
			is_task_deception = false
		"stuck_99":
			is_stuck_99 = false
		"time_stop":
			is_time_stopped = false
		"time_accelerate":
			is_time_accelerated = false
		"time_erase":
			is_time_erased = false

# ── MINOR ──
func _execute_minor(choice: String) -> void:
	print("[InconvenienceManager] Minor Executing: ", choice)
	
	if choice == "lights_out":
		var main = get_tree().current_scene
		var pm = main.get_node_or_null("PauseMenu")
		if pm:
			pm.brightness_slider.value = 0.0
			pm._apply_settings()
			pm.save_settings()
	
	elif choice == "random_ui":
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud:
			hud.scale = Vector2(randf_range(0.5, 1.8), randf_range(0.5, 1.8))
	
	elif choice == "shaky":
		is_shaky = true
		
	elif choice == "clock_stop":
		is_clock_stopped = true
		
	elif choice == "sprite_flip":
		is_sprite_flipped = true
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p.has_node("AnimSprite"):
				p.get_node("AnimSprite").scale.y = -abs(p.get_node("AnimSprite").scale.y)
				
	elif choice == "blur":
		if not is_instance_valid(blur_rect):
			var canvas = CanvasLayer.new()
			canvas.layer = 99
			blur_rect = ColorRect.new()
			blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var mat = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	COLOR = textureLod(screen_texture, SCREEN_UV, 4.0);
}
"""
			mat.shader = shader
			blur_rect.material = mat
			canvas.add_child(blur_rect)
			get_tree().current_scene.add_child(canvas)

	# Auto-fix: all minor inconveniences have no solution → 5 seconds
	_auto_fix(choice, AUTOFIX_NO_SOLUTION)

# ── MEDIUM ──
func _execute_medium(choice: String) -> void:
	print("[InconvenienceManager] Medium Executing: ", choice)
	
	if choice == "fps":
		var main = get_tree().current_scene
		var pm = main.get_node_or_null("PauseMenu")
		if pm:
			pm.fps_input.value = 5.0
			pm._apply_settings()
			pm.save_settings()
	
	elif choice == "unplug":
		_spawn_unplug_fake()
		# unplug already has its own 5s timer, no extra auto-fix needed
		return
	
	elif choice == "keybind":
		var main = get_tree().current_scene
		var pm = main.get_node_or_null("PauseMenu")
		if pm:
			var left_events = InputMap.action_get_events("move_left")
			var right_events = InputMap.action_get_events("move_right")
			InputMap.action_erase_events("move_left")
			InputMap.action_erase_events("move_right")
			for ev in right_events:
				InputMap.action_add_event("move_left", ev)
			for ev in left_events:
				InputMap.action_add_event("move_right", ev)
			
			pm.keybind_buttons["move_left"].text = pm._get_action_key_name("move_left")
			pm.keybind_buttons["move_right"].text = pm._get_action_key_name("move_right")
			pm.save_settings()
		# keybind has a solution (player can fix in settings) → 30s
		_auto_fix(choice, AUTOFIX_HAS_SOLUTION)
		return
			
	elif choice == "unpause_hack":
		is_unpause_hack = true
	
	elif choice == "time_stop":
		is_time_stopped = true
		print("[InconvenienceManager] Time stopped! Player can move but can't interact for 5s.")
		_auto_fix("time_stop", 5.0)
		return
	
	elif choice == "time_accelerate":
		is_time_accelerated = true
		Engine.time_scale = 4.0
		print("[InconvenienceManager] Time accelerated 4x for 2 seconds!")
		var accel_timer = get_tree().create_timer(2.0, true, false, true)  # process_always
		accel_timer.timeout.connect(func():
			is_time_accelerated = false
			Engine.time_scale = 1.0
			print("[InconvenienceManager] Time acceleration ended.")
		)
		return
	
	elif choice == "force_room_swap":
		GameManager.force_inject_special_room()
		return

	# Auto-fix: most medium inconveniences have no solution → 5 seconds
	_auto_fix(choice, AUTOFIX_NO_SOLUTION)

func _spawn_unplug_fake() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	get_tree().current_scene.add_child(canvas)
	
	# Play the unplug sound effect
	var sfx = AudioStreamPlayer.new()
	var audio = load("res://Assets/Audio/SFX/Unplug_Sound.MP3")
	if audio:
		sfx.stream = audio
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())
	
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(canvas): canvas.queue_free())

# ── MAJOR ──
func _execute_major(choice: String) -> void:
	print("[InconvenienceManager] Major Executing: ", choice)
	
	if choice == "fake_ad":
		_spawn_fake_ad()
	elif choice == "gibberish":
		is_gibberish = true
		var scene = get_tree().current_scene
		if scene:
			_scramble_all_labels(scene)
	elif choice == "task_deception":
		is_task_deception = true
	elif choice == "stuck_99":
		is_stuck_99 = true
	elif choice == "time_reverse":
		GameManager.reverse_last_task()
		# No auto-fix needed — it's a one-shot effect
		return
	elif choice == "time_erase":
		is_time_erased = true
		print("[InconvenienceManager] Time erased! Tasks completed in next 7s won't count.")
		_auto_fix("time_erase", 7.0)
		return

	# Auto-fix: all major inconveniences have solutions → 30 seconds
	_auto_fix(choice, AUTOFIX_HAS_SOLUTION)

func _spawn_fake_ad() -> void:
	if fake_ads_container == null:
		fake_ads_container = CanvasLayer.new()
		fake_ads_container.layer = 101
		get_tree().current_scene.add_child(fake_ads_container)
	
	var num_ads = randi_range(5, 15)
	for i in num_ads:
		var tex_rect = TextureRect.new()
		var tex = load("res://Assets/UI V4/IKLAN SCAM/IKLAN_%d.png" % randi_range(1, 7))
		tex_rect.texture = tex
		
		# Ukuran random, biar ngasal
		var scale_factor = randf_range(0.4, 1.2)
		var w = tex.get_width() * scale_factor
		var h = tex.get_height() * scale_factor
		
		tex_rect.expand_mode = 1 # EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(w, h)
		tex_rect.size = Vector2(w, h)
		tex_rect.position = Vector2(randf_range(0, 1920 - w), randf_range(0, 1080 - h))
		
		tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		tex_rect.gui_input.connect(_on_fake_ad_gui_input.bind(tex_rect))
		
		fake_ads_container.add_child(tex_rect)

func _on_fake_ad_gui_input(event: InputEvent, ad_node: Control) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		ad_node.position += event.relative
		var bounds = ad_node.get_rect()
		if bounds.position.x > 1600 or bounds.position.y > 900 or bounds.end.x < 300 or bounds.end.y < 200:
			ad_node.queue_free()

func _scramble_all_labels(node: Node) -> void:
	if node is Label or node is RichTextLabel or node is Button:
		if node.text != "!@#$%^&*()_+":
			node.set_meta("orig_text", node.text)
			node.text = "!@#$%^&*()_+"
	elif node is OptionButton:
		for i in node.item_count:
			var txt = node.get_item_text(i)
			if txt != "!@#$%^&*()_+":
				node.set_meta("orig_text_" + str(i), txt)
				node.set_item_text(i, "!@#$%^&*()_+")
	for child in node.get_children():
		_scramble_all_labels(child)

func _unscramble_all_labels(node: Node) -> void:
	if node is Label or node is RichTextLabel or node is Button:
		if node.has_meta("orig_text"):
			node.text = node.get_meta("orig_text")
			node.remove_meta("orig_text")
	elif node is OptionButton:
		for i in node.item_count:
			if node.has_meta("orig_text_" + str(i)):
				node.set_item_text(i, node.get_meta("orig_text_" + str(i)))
				node.remove_meta("orig_text_" + str(i))
	for child in node.get_children():
		_unscramble_all_labels(child)
