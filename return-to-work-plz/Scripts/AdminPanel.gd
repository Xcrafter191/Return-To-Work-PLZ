extends CanvasLayer

var panel: Panel
var is_open: bool = false

func _ready() -> void:
	layer = 128
	
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 350)
	panel.position = Vector2(-300, 100) # Hidden by default
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "ADMIN PANEL (Press F1)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# a. Set Loop
	var loop_box = HBoxContainer.new()
	var loop_lbl = Label.new()
	loop_lbl.text = "Loop:"
	var loop_spin = SpinBox.new()
	loop_spin.min_value = 1
	loop_spin.max_value = 999
	loop_spin.value = GameManager.current_loop
	loop_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loop_btn = Button.new()
	loop_btn.text = "Set"
	loop_btn.pressed.connect(func():
		GameManager.current_loop = int(loop_spin.value)
		GameManager.loop_restarted.emit(GameManager.current_loop)
	)
	loop_box.add_child(loop_lbl)
	loop_box.add_child(loop_spin)
	loop_box.add_child(loop_btn)
	vbox.add_child(loop_box)
	
	# b. Auto complete 1 task
	var task_btn = Button.new()
	task_btn.text = "Auto-Complete Current Task"
	task_btn.pressed.connect(func():
		if GameManager.get_current_task_id() != "":
			GameManager.complete_objective(GameManager.get_current_task_id())
	)
	vbox.add_child(task_btn)
	
	# c. Reset Loop
	var reset_btn = Button.new()
	reset_btn.text = "Reset Current Loop"
	reset_btn.pressed.connect(func():
		GameManager.loop_restarted.emit(GameManager.current_loop)
	)
	vbox.add_child(reset_btn)
	
	# d. Trigger Inconvenience
	var inc_box = HBoxContainer.new()
	var inc_opt = OptionButton.new()
	inc_opt.add_item("Minor", 0)
	inc_opt.add_item("Medium", 1)
	inc_opt.add_item("Major", 2)
	inc_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inc_btn = Button.new()
	inc_btn.text = "Trigger"
	inc_btn.pressed.connect(func():
		var inc_mgr = get_node_or_null("/root/InconvenienceManager")
		if inc_mgr:
			match inc_opt.selected:
				0: inc_mgr._execute_minor()
				1: inc_mgr._execute_medium()
				2: inc_mgr._execute_major()
	)
	inc_box.add_child(inc_opt)
	inc_box.add_child(inc_btn)
	vbox.add_child(inc_box)
	
	# e. Set Productivity
	var prod_box = HBoxContainer.new()
	var prod_lbl = Label.new()
	prod_lbl.text = "Prod:"
	var prod_spin = SpinBox.new()
	prod_spin.min_value = 0
	prod_spin.max_value = 100
	prod_spin.value = GameManager.productivity
	prod_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prod_btn = Button.new()
	prod_btn.text = "Set"
	prod_btn.pressed.connect(func():
		GameManager.set_productivity(prod_spin.value)
	)
	prod_box.add_child(prod_lbl)
	prod_box.add_child(prod_spin)
	prod_box.add_child(prod_btn)
	vbox.add_child(prod_box)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_toggle_panel()

func _toggle_panel() -> void:
	is_open = !is_open
	var tween = create_tween()
	if is_open:
		tween.tween_property(panel, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)
	else:
		tween.tween_property(panel, "position:x", -300.0, 0.3).set_trans(Tween.TRANS_QUAD)
