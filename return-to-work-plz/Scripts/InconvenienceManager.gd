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

var current_chance: float = 0.0

# Active permanent inconveniences
var is_shaky: bool = false
var is_offset_movement: bool = false
var is_gibberish: bool = false

func _ready() -> void:
	GameManager.objective_completed.connect(_on_objective_completed)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	_setup_loop_quotas(GameManager.current_loop)

func _setup_loop_quotas(loop_num: int) -> void:
	triggered = { Difficulty.MINOR: 0, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	
	if loop_num == 1:
		current_chance = 0.0
		quotas = { Difficulty.MINOR: 0, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 2:
		current_chance = 0.05
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 3:
		current_chance = 0.10
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 0, Difficulty.MAJOR: 0 }
	elif loop_num == 4:
		current_chance = 0.12
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num == 5:
		current_chance = 0.15
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 0 }
	elif loop_num >= 6 and loop_num <= 10:
		current_chance = 0.20
		quotas = { Difficulty.MINOR: 0, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 1 }
	elif loop_num >= 11 and loop_num <= 20:
		current_chance = 0.40
		quotas = { Difficulty.MINOR: 1, Difficulty.MEDIUM: 1, Difficulty.MAJOR: 1 }
	else:
		current_chance = 0.50
		quotas = { Difficulty.MINOR: 2, Difficulty.MEDIUM: 2, Difficulty.MAJOR: 1 }

func _on_loop_restarted(loop_num: int) -> void:
	_setup_loop_quotas(loop_num)
	_reset_permanent_inconveniences()

func _reset_permanent_inconveniences() -> void:
	is_shaky = false
	is_offset_movement = false
	is_gibberish = false
	Engine.max_fps = 0
	
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.scale = Vector2.ONE

func _on_objective_completed(_task_id: String) -> void:
	if current_chance <= 0.0: return
	
	var all_met = true
	for diff in quotas:
		if triggered[diff] < quotas[diff]:
			all_met = false
			break
	
	if all_met:
		current_chance = 0.0
		print("[InconvenienceManager] All quotas met. Chance dropped to 0.")
		return
		
	if randf() <= current_chance:
		_trigger_random_inconvenience()

func _trigger_random_inconvenience() -> void:
	var pool = []
	for diff in quotas:
		if triggered[diff] < quotas[diff]:
			pool.append(diff)
			
	if pool.is_empty(): return
	
	var chosen_diff = pool.pick_random()
	triggered[chosen_diff] += 1
	
	print("[InconvenienceManager] Triggered inconvenience of difficulty: ", chosen_diff)
	
	match chosen_diff:
		Difficulty.MINOR: _execute_minor()
		Difficulty.MEDIUM: _execute_medium()
		Difficulty.MAJOR: _execute_major()

# ── MINOR ──
func _execute_minor() -> void:
	var options = ["lights_out", "random_ui", "shaky"]
	var choice = options.pick_random()
	print("[InconvenienceManager] Minor Executing: ", choice)
	
	if choice == "lights_out":
		var main = get_tree().current_scene
		if main.has_node("BrightnessOverlay"):
			# Forces pitch black until user opens settings and clicks Apply!
			main.get_node("BrightnessOverlay").color = Color(0.0, 0.0, 0.0, 1.0) 
	
	elif choice == "random_ui":
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud:
			hud.scale = Vector2(randf_range(0.5, 1.8), randf_range(0.5, 1.8))
			var timer = get_tree().create_timer(30.0)
			timer.timeout.connect(func(): if is_instance_valid(hud): hud.scale = Vector2.ONE)
	
	elif choice == "shaky":
		is_shaky = true # Camera shaky logic handled in Player.gd

# ── MEDIUM ──
func _execute_medium() -> void:
	var options = ["fps", "unplug", "keybind"]
	var choice = options.pick_random()
	print("[InconvenienceManager] Medium Executing: ", choice)
	
	if choice == "fps":
		Engine.max_fps = 5
		var timer = get_tree().create_timer(30.0)
		timer.timeout.connect(func(): Engine.max_fps = 0)
	
	elif choice == "unplug":
		_spawn_unplug_fake()
	
	elif choice == "keybind":
		is_offset_movement = true # Movement swapped in Player.gd

func _spawn_unplug_fake() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)
	get_tree().current_scene.add_child(canvas)
	
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): if is_instance_valid(canvas): canvas.queue_free())

# ── MAJOR ──
func _execute_major() -> void:
	var options = ["fake_ad", "gibberish"]
	var choice = options.pick_random()
	print("[InconvenienceManager] Major Executing: ", choice)
	
	if choice == "fake_ad":
		_spawn_fake_ad()
	elif choice == "gibberish":
		is_gibberish = true # HUD and Dialogues will scramble
		_scramble_all_labels(get_tree().current_scene)
		
func _spawn_fake_ad() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 101
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.custom_minimum_size = Vector2(800, 600)
	panel.position = Vector2(560, 240)
	
	var label = Label.new()
	label.text = "BUY MORE COFFEE!\nUnskippable Ad\nPlease wait 5 seconds..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.theme_override_font_sizes.font_size = 48
	
	panel.add_child(label)
	canvas.add_child(panel)
	get_tree().current_scene.add_child(canvas)
	
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(canvas): canvas.queue_free())

func _scramble_all_labels(node: Node) -> void:
	if node is Label or node is RichTextLabel:
		node.text = "!@#$%^&*()_+"
	for child in node.get_children():
		_scramble_all_labels(child)
