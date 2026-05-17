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
var is_gibberish: bool = false
var fake_ads_container: CanvasLayer = null

func _process(_delta: float) -> void:
	if is_gibberish:
		var scene = get_tree().current_scene
		if scene:
			_scramble_all_labels(scene)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	
	if is_gibberish:
		is_gibberish = false
		var scene = get_tree().current_scene
		if scene:
			_unscramble_all_labels(scene)
			
	if is_instance_valid(fake_ads_container):
		fake_ads_container.queue_free()
		fake_ads_container = null
	
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
		is_shaky = true # Camera shaky logic handled in Player.gd

# ── MEDIUM ──
func _execute_medium() -> void:
	var options = ["fps", "unplug", "keybind"]
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
	var options = ["fake_ad", "gibberish"]
	var choice = options.pick_random()
	print("[InconvenienceManager] Major Executing: ", choice)
	
	if choice == "fake_ad":
		_spawn_fake_ad()
	elif choice == "gibberish":
		is_gibberish = true

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
		fake_ads_container.add_child(panel)

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
