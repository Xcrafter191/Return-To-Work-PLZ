extends CanvasLayer

signal skill_check_completed(success: bool)

@onready var panel = $Panel
@onready var yellow_zone = $Panel/BarBackground/YellowZone
@onready var arrow = $Panel/BarBackground/Arrow
@onready var bar_bg = $Panel/BarBackground
@onready var result_label = $Panel/ResultLabel
@onready var prompt_label = $Panel/PromptLabel

@onready var success_sfx: AudioStreamPlayer2D = $SuccessSFX
@onready var fail_sfx: AudioStreamPlayer2D = $FailedSFX

var is_active: bool = false
var arrow_speed: float = 400.0
var arrow_direction: int = 1
var bar_width: float = 460.0
var _skill_check_tutorial_seen: bool = false
var _tutorial_node: CanvasLayer = null
var _tutorial_pending_speed: float = 400.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = false

func begin_skill_check(base_speed: float = 400.0) -> void:
	if not _skill_check_tutorial_seen:
		_show_tutorial(base_speed)
	else:
		start_skill_check(base_speed)

func _show_tutorial(pending_speed: float) -> void:
	_tutorial_pending_speed = pending_speed

	# Create CanvasLayer for the tutorial overlay
	_tutorial_node = CanvasLayer.new()
	_tutorial_node.layer = 100
	_tutorial_node.process_mode = Node.PROCESS_MODE_ALWAYS

	# Full-screen dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_node.add_child(bg)

	# Container for centered content
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_node.add_child(container)

	# Title label
	var title_label = Label.new()
	title_label.text = "TUTORIAL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title_label)

	# Spacer
	var spacer_title = Control.new()
	spacer_title.custom_minimum_size = Vector2(0, 15)
	container.add_child(spacer_title)

	# Instructional text label
	var text_label = Label.new()
	text_label.text = "During some tasks, you will have to face\n\"Focus Timing,\" in which you have to\nstop the white bar at the yellow zone\nas shown below."
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(text_label)

	# Spacer before QTE example
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer_top)

	# Animated QTE bar example (centered)
	var bar_container = CenterContainer.new()
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bar_container)

	var bar_bg_example = ColorRect.new()
	bar_bg_example.name = "BarBgExample"
	bar_bg_example.custom_minimum_size = Vector2(460, 30)
	bar_bg_example.color = Color(0.2, 0.2, 0.2, 1.0)
	bar_bg_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg_example)

	# Red zone (fills entire bar)
	var red_zone = ColorRect.new()
	red_zone.position = Vector2(0, 0)
	red_zone.size = Vector2(460, 30)
	red_zone.color = Color(0.878431, 0.117647, 0.117647, 1.0)
	red_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg_example.add_child(red_zone)

	# Yellow zone (success area)
	var yellow_zone_example = ColorRect.new()
	yellow_zone_example.name = "YellowZoneExample"
	yellow_zone_example.position = Vector2(180, 0)
	yellow_zone_example.size = Vector2(100, 30)
	yellow_zone_example.color = Color(0.917647, 0.639216, 0.160784, 1.0)
	yellow_zone_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg_example.add_child(yellow_zone_example)

	# White indicator (animated — starts at left, will move)
	var indicator = ColorRect.new()
	indicator.name = "TutorialIndicator"
	indicator.position = Vector2(0, -5)
	indicator.size = Vector2(6, 40)
	indicator.color = Color.WHITE
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg_example.add_child(indicator)

	# Spacer before prompt
	var spacer_bottom = Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer_bottom)

	# "Press Space to continue" prompt (hidden initially, shown after demo)
	var prompt = Label.new()
	prompt.name = "TutorialPrompt"
	prompt.text = "Press [SPACE] to continue"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	container.add_child(prompt)

	# Add tutorial to the tree and pause the game
	add_child(_tutorial_node)
	# Temporarily allow this node to process while paused so animation and input work
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# Animate the white bar: move across, stop at yellow zone, then show prompt
	_animate_tutorial_bar(indicator, prompt)

var _tutorial_ready_for_dismiss: bool = false

func _animate_tutorial_bar(indicator: ColorRect, prompt: Label) -> void:
	_tutorial_ready_for_dismiss = false
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Move indicator from left to the yellow zone center (position 220)
	var yellow_center_x = 180.0 + (100.0 / 2.0) - (indicator.size.x / 2.0)  # ~227
	# First sweep: move from 0 to end
	tween.tween_property(indicator, "position:x", 460.0, 1.2)
	# Bounce back
	tween.tween_property(indicator, "position:x", 0.0, 1.2)
	# Second sweep: move toward yellow zone and stop
	tween.tween_property(indicator, "position:x", yellow_center_x, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Pause briefly to show "this is success"
	tween.tween_interval(0.5)
	# Flash the indicator to show success
	tween.tween_property(indicator, "color", Color.GREEN, 0.2)
	tween.tween_interval(0.8)
	tween.tween_property(indicator, "color", Color.WHITE, 0.2)
	# Show the continue prompt and allow dismissal
	tween.tween_callback(func():
		prompt.visible = true
		_tutorial_ready_for_dismiss = true
		# Animate prompt blinking
		var blink = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		blink.tween_property(prompt, "modulate:a", 0.3, 0.5)
		blink.tween_property(prompt, "modulate:a", 1.0, 0.5)
	)

func _dismiss_tutorial() -> void:
	if _tutorial_node:
		_tutorial_node.queue_free()
		_tutorial_node = null
	_tutorial_ready_for_dismiss = false
	get_tree().paused = false
	# Restore normal process mode
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_skill_check_tutorial_seen = true
	# Delay starting the real QTE by 1 frame so the Space press doesn't register
	await get_tree().process_frame
	start_skill_check(_tutorial_pending_speed)

func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_node == null:
		return
	if not _tutorial_ready_for_dismiss:
		# Tutorial animation still playing, consume input but don't dismiss
		if event.is_action_pressed("qte_confirm") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("qte_confirm") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_dismiss_tutorial()

func reset_tutorial_state() -> void:
	_skill_check_tutorial_seen = false

func start_skill_check(base_speed: float = 400.0) -> void:
	is_active = true
	visible = true
	prompt_label.visible = true
	result_label.text = ""
	
	# Yellow zone width shrinks each loop, capped at minimum 25px
	var base_width = 100.0 - (GameManager.current_loop * 5.0)
	var zone_width = clampf(base_width, 15.0, 100.0)
	var max_x = bar_width - zone_width
	var zone_x = randf_range(0, max_x)
	
	arrow_speed = base_speed
	
	yellow_zone.position.x = zone_x
	yellow_zone.size.x = zone_width
	
	# Reset arrow
	arrow.position.x = 0
	arrow_direction = 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_active:
		visible = false
	elif what == NOTIFICATION_UNPAUSED and is_active:
		visible = true

func _process(delta: float) -> void:
	if not is_active: return
	if get_tree().paused: return
	
	# Move arrow
	arrow.position.x += arrow_speed * arrow_direction * delta
	
	# Bounce
	if arrow.position.x > bar_width - arrow.size.x:
		arrow.position.x = bar_width - arrow.size.x
		arrow_direction = -1
	elif arrow.position.x < 0:
		arrow.position.x = 0
		arrow_direction = 1
		
	# Input Check — uses Space (qte_confirm), NOT E (interact)
	if Input.is_action_just_pressed("qte_confirm"):
		_check_result()

func _check_result() -> void:
	is_active = false
	prompt_label.visible = false
	
	var arrow_center = arrow.position.x + (arrow.size.x / 2.0)
	var zone_start = yellow_zone.position.x
	var zone_end = yellow_zone.position.x + yellow_zone.size.x
	
	var success = (arrow_center >= zone_start and arrow_center <= zone_end)
	
	if success:
		result_label.text = "GOOD!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		if success_sfx:
			success_sfx.play() # Play sound success
	else:
		result_label.text = "FAILED!"
		result_label.add_theme_color_override("font_color", Color.RED)
		if fail_sfx:
			fail_sfx.play() # Play sound fail
		
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		visible = false
		skill_check_completed.emit(success)
	)
