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
var is_sprite_flipped: bool = false
var is_unpause_hack: bool = false
var is_upside_down: bool = false
var is_task_deception: bool = false
var is_stuck_99: bool = false
var is_time_stopped: bool = false
var is_time_accelerated: bool = false
var is_time_erased: bool = false
var is_room_locked: bool = false
var is_reverse_controls: bool = false
var reverse_controls_direction: int = -1  # -1 = invert to left, 1 = invert to right
var pending_reverse_task_id: String = ""  # Track reversed task for cross-room reset

# Jumpscare state (loop 10+)
var _jumpscare_task_index: int = -1  # Which task index triggers the jumpscare this loop
var _jumpscare_triggered_this_loop: bool = false

var red_ambience_rect: ColorRect = null
var blur_rect: ColorRect = null
var time_stop_overlay: CanvasLayer = null

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
	# Time Reverse: reset workstations in newly loaded room if they match the reversed task
	if pending_reverse_task_id != "":
		var interactables = get_tree().get_nodes_in_group("interactables")
		for obj in interactables:
			if obj.task_id == pending_reverse_task_id and obj.task_completed:
				obj.task_completed = false
				if obj.has_node("PromptLabel"):
					obj.get_node("PromptLabel").modulate.a = 1.0
				obj._update_glow_state()
				if obj.player_in_range:
					obj._update_prompt_visibility()
				print("[InconvenienceManager] Time Reverse (room load): Reset workstation '%s'" % obj.task_id)
		# Clear the pending flag once the workstation is found and reset
		var found = false
		for obj in interactables:
			if obj.task_id == pending_reverse_task_id:
				found = true
				break
		if found:
			pending_reverse_task_id = ""

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
	# Jumpscare: pick a random task index for this loop (loop 10 only)
	_jumpscare_triggered_this_loop = false
	if loop_num == 10:
		_jumpscare_task_index = randi_range(0, GameManager.objectives.size() - 1)
	else:
		_jumpscare_task_index = -1

func _reset_permanent_inconveniences() -> void:
	is_shaky = false
	is_sprite_flipped = false
	is_unpause_hack = false
	is_upside_down = false
	is_task_deception = false
	is_stuck_99 = false
	is_time_stopped = false
	is_time_accelerated = false
	is_time_erased = false
	is_room_locked = false
	is_reverse_controls = false
	pending_reverse_task_id = ""
	_hide_time_stop_overlay()

## Full reset — clears everything including red ambience. Call on game over / exit to menu.
func full_reset() -> void:
	_reset_permanent_inconveniences()
	if red_ambience_rect:
		red_ambience_rect.color.a = 0.0
	
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
	# Jumpscare: loop 10+, triggers once per loop on a random task
	if GameManager.current_loop == 10 and not _jumpscare_triggered_this_loop:
		# Check if this is the chosen task
		if GameManager.current_task_index - 1 == _jumpscare_task_index:
			_jumpscare_triggered_this_loop = true
			_show_jumpscare()
	
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
			specific_choice = ["lights_out", "random_ui", "sprite_flip", "blur"].pick_random()
		Difficulty.MEDIUM: 
			specific_choice = ["fps", "unplug", "keybind", "time_stop", "time_accelerate", "force_room_swap", "room_lock", "reverse_controls"].pick_random()

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
	# Use process_always so timer ticks even if tree is paused (e.g. during attack sequences)
	var timer = get_tree().create_timer(timeout, true, false, true)
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
			_hide_time_stop_overlay()
		"time_accelerate":
			is_time_accelerated = false
		"time_erase":
			is_time_erased = false
		"room_lock":
			is_room_locked = false
		"reverse_controls":
			is_reverse_controls = false

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
			var remappable_actions = ["move_left", "move_right", "interact", "qte_confirm"]
			# Collect current key events for all remappable actions, excluding ESC and numpad keys
			var collected_events: Array = []
			for action in remappable_actions:
				var events = InputMap.action_get_events(action)
				for ev in events:
					if ev is InputEventKey:
						var kc = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
						# Exclude ESC and numpad keys from the pool
						if kc == KEY_ESCAPE:
							continue
						if kc >= KEY_KP_0 and kc <= KEY_KP_9:
							continue
						if kc in [KEY_KP_MULTIPLY, KEY_KP_SUBTRACT, KEY_KP_ADD, KEY_KP_PERIOD, KEY_KP_DIVIDE, KEY_KP_ENTER]:
							continue
						collected_events.append(ev)
			
			# Shuffle collected events for random reassignment
			collected_events.shuffle()
			
			# Erase all events from remappable actions
			for action in remappable_actions:
				InputMap.action_erase_events(action)
			
			# Reassign shuffled events to actions in order
			for i in range(min(collected_events.size(), remappable_actions.size())):
				InputMap.action_add_event(remappable_actions[i], collected_events[i])
			
			# Update keybind button display text for all affected actions
			for action in remappable_actions:
				if action in pm.keybind_buttons:
					pm.keybind_buttons[action].text = pm._get_action_key_name(action)
			pm.save_settings()
		# keybind has a solution (player can fix in settings) → 30s
		_auto_fix(choice, AUTOFIX_HAS_SOLUTION)
		return
			
	elif choice == "time_stop":
		is_time_stopped = true
		_show_time_stop_overlay()
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
	
	elif choice == "room_lock":
		is_room_locked = true
		_auto_fix("room_lock", 10.0)
		return
	
	elif choice == "reverse_controls":
		is_reverse_controls = true
		# Random direction: player always moves this way regardless of input
		reverse_controls_direction = [-1, 1].pick_random()
		_auto_fix("reverse_controls", 8.0)
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
		# Store the reversed task ID so workstations in other rooms can reset when loaded
		var reversed_task_id = GameManager.get_current_task_id()
		pending_reverse_task_id = reversed_task_id
		# Explicit group query to reset workstation task_completed for the reversed task
		# This ensures the reset happens even if the signal path doesn't reach all workstations
		if reversed_task_id != "":
			var interactables = get_tree().get_nodes_in_group("interactables")
			for obj in interactables:
				if obj.task_id == reversed_task_id and obj.task_completed:
					obj.task_completed = false
					if obj.has_node("PromptLabel"):
						obj.get_node("PromptLabel").modulate.a = 1.0
					print("[InconvenienceManager] Time Reverse: Reset workstation '%s' task_completed" % obj.task_id)
		# No auto-fix needed — it's a one-shot effect
		return
	elif choice == "time_erase":
		is_time_erased = true
		_auto_fix("time_erase", 10.0)
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

func _generate_random_string(length: int) -> String:
	const CHAR_POOL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@#$%^&*!?~"
	var result = ""
	for i in length:
		result += CHAR_POOL[randi() % CHAR_POOL.length()]
	return result

func _scramble_all_labels(node: Node) -> void:
	if node is Label or node is RichTextLabel or node is Button:
		if not node.has_meta("orig_text"):
			node.set_meta("orig_text", node.text)
			node.text = _generate_random_string(node.get_meta("orig_text").length())
	elif node is OptionButton:
		for i in node.item_count:
			var meta_key = "orig_text_" + str(i)
			if not node.has_meta(meta_key):
				var txt = node.get_item_text(i)
				node.set_meta(meta_key, txt)
				node.set_item_text(i, _generate_random_string(txt.length()))
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

# ── TIME STOP VISUAL OVERLAY ──
func _show_time_stop_overlay() -> void:
	if time_stop_overlay != null:
		return
	time_stop_overlay = CanvasLayer.new()
	time_stop_overlay.layer = 9  # Below UI, above world
	var rect = ColorRect.new()
	rect.name = "TimeStopTint"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.3, 0.5, 0.8, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_stop_overlay.add_child(rect)
	add_child(time_stop_overlay)
	# Fade in the tint
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.25, 0.3)

func _hide_time_stop_overlay() -> void:
	if time_stop_overlay == null:
		return
	var rect = time_stop_overlay.get_node_or_null("TimeStopTint")
	if rect:
		var tween = create_tween()
		tween.tween_property(rect, "color:a", 0.0, 0.3)
		tween.tween_callback(func():
			if is_instance_valid(time_stop_overlay):
				time_stop_overlay.queue_free()
				time_stop_overlay = null
		)
	else:
		time_stop_overlay.queue_free()
		time_stop_overlay = null

# ── JUMPSCARE (Loop 10+) ──
func _show_jumpscare() -> void:
	var tex = load("res://Assets/jumpscare.png")
	if not tex:
		return
	
	var canvas = CanvasLayer.new()
	canvas.layer = 150  # Above everything
	
	var img_rect = TextureRect.new()
	img_rect.texture = tex
	img_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_SCALE
	img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(img_rect)
	
	add_child(canvas)
	
	# Remove after 0.1 seconds (subliminal flash)
	var timer = get_tree().create_timer(0.1, true, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)
