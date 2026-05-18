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

var red_ambience_rect: ColorRect = null
var blur_rect: ColorRect = null

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
			# Re-scramble new room
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
		base_chance = 0.05
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 3:
		base_chance = 0.10
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 4:
		base_chance = 0.12
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num == 5:
		base_chance = 0.15
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num == 6:
		base_chance = 0.20 # Smoothed curve instead of jumping to 0.50
		quotas = { Difficulty.MINOR: 3, Difficulty.MEDIUM: 2, Difficulty.MAJOR: 1 }
	elif loop_num >= 7 and loop_num <= 10:
		base_chance = 0.50
		quotas = { Difficulty.MINOR: 5, Difficulty.MEDIUM: 4, Difficulty.MAJOR: 2 }
	elif loop_num >= 11 and loop_num <= 20:
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
		accumulated_chance = base_chance # Reset after trigger
	else:
		accumulated_chance += base_chance # Accumulate chance over time

func _trigger_random_inconvenience() -> void:
	var pool = []
	for diff in quotas:
		if triggered[diff] < quotas[diff]:
			pool.append(diff)
			
	if pool.is_empty(): return
	
	var chosen_diff = pool.pick_random()
	triggered[chosen_diff] += 1
	
	print("[InconvenienceManager] Triggered inconvenience of difficulty: ", chosen_diff)
	
	var diff_str = ""
	match chosen_diff:
		Difficulty.MINOR: diff_str = "minor_annoyance"
		Difficulty.MEDIUM: diff_str = "medium_disruption"
		Difficulty.MAJOR: diff_str = "major_failure"
		
	AttackSequenceManager.trigger_attack(diff_str)
	AttackSequenceManager.sequence_finished.connect(func():
		match chosen_diff:
			Difficulty.MINOR: _execute_minor()
			Difficulty.MEDIUM: _execute_medium()
			Difficulty.MAJOR: _execute_major()
	, CONNECT_ONE_SHOT)

# ── MINOR ──
func _execute_minor() -> void:
	var options = ["lights_out", "random_ui", "shaky", "clock_stop", "sprite_flip", "blur"]
	var choice = options.pick_random()
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

# ── MEDIUM ──
func _execute_medium() -> void:
	var options = ["fps", "unplug", "keybind", "unpause_hack", "upside_down", "window_resizer"]
	var choice = options.pick_random()
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
			
	elif choice == "unpause_hack":
		is_unpause_hack = true
		
	elif choice == "upside_down":
		is_upside_down = true
		var main_cam = get_tree().current_scene.get_node_or_null("Camera2D")
		if main_cam:
			main_cam.rotation = PI
			
	elif choice == "window_resizer":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(640, 360))

func _spawn_unplug_fake() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	get_tree().current_scene.add_child(canvas)
	
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(canvas): canvas.queue_free())

# ── MAJOR ──
func _execute_major() -> void:
	var options = ["fake_ad", "gibberish", "task_deception", "stuck_99"]
	var choice = options.pick_random()
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

func _spawn_fake_ad() -> void:
	if fake_ads_container == null:
		fake_ads_container = CanvasLayer.new()
		fake_ads_container.layer = 101
		get_tree().current_scene.add_child(fake_ads_container)
	
	var num_ads = randi_range(5, 15)
	for i in num_ads:
		var panel = Panel.new()
		var w = randf_range(200, 600)
		var h = randf_range(150, 400)
		panel.custom_minimum_size = Vector2(w, h)
		panel.position = Vector2(randf_range(0, 1920 - w), randf_range(0, 1080 - h))
		
		var label = Label.new()
		label.text = "BUY MORE COFFEE!\nUnskippable Ad"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		panel.add_child(label)
		
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_fake_ad_gui_input.bind(panel))
		
		fake_ads_container.add_child(panel)

func _on_fake_ad_gui_input(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		panel.position += event.relative
		var bounds = panel.get_rect()
		if bounds.position.x > 1600 or bounds.position.y > 900 or bounds.end.x < 300 or bounds.end.y < 200:
			panel.queue_free()

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
