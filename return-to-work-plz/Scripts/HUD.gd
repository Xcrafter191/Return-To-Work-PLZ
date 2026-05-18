extends CanvasLayer

## HUD — Main UI overlay.
## Shows Productivity, Morale, and Current Task.

@onready var productive_texture: TextureRect = $ProductivityContainer/ProductiveTexture
@onready var moral_texture: TextureRect = $MoraleContainer/MoralTexture
@onready var productivity_bar: TextureProgressBar = $ProductivityContainer/Bar
@onready var morale_bar: TextureProgressBar = $MoraleContainer/Bar
@onready var task_bg: TextureRect = $TaskBackground
@onready var task_label: Label = $TaskBackground/TaskLabel
@onready var clockout_label: Label = $ClockOutLabel

var deadline_label: Label = null


var texbox_task: Texture2D = preload("res://Assets/UI V4/TEXTBOX/TASK.png")
var productive_good: Texture2D = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/GOOD.png")
var productive_mid: Texture2D = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/ALERT.png")
var productive_bad: Texture2D = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/BAD.png")
var moral_good: Texture2D = preload("res://Assets/UI V4/MORAL/MORAL/GOOD.png")
var moral_mid: Texture2D = preload("res://Assets/UI V4/MORAL/MORAL/ALERT.png")
var moral_bad: Texture2D = preload("res://Assets/UI V4/MORAL/MORAL/BAD.png")

var _animating: bool = false

func _ready() -> void:
	GameManager.objective_completed.connect(_on_objective_completed)
	GameManager.all_objectives_completed.connect(_on_all_completed)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	GameManager.npc_talk_updated.connect(_on_npc_talk_updated)
	GameManager.morale_changed.connect(_on_morale_changed)
	GameManager.productivity_changed.connect(_on_productivity_changed)
	
	clockout_label.visible = false
	_show_current_task()
	
	# Init bars
	_on_morale_changed(GameManager.morale)
	_on_productivity_changed(GameManager.productivity)
	
	# Create Deadline Label dynamically
	deadline_label = Label.new()
	deadline_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	deadline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deadline_label.offset_top = 40
	deadline_label.add_theme_font_size_override("font_size", 36)
	deadline_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	add_child(deadline_label)

func _process(_delta: float) -> void:
	if not deadline_label: return
	
	if GameManager.is_deadline_active:
		if InconvenienceManager.is_clock_stopped:
			# Freeze the text
			pass
		else:
			var t = maxf(GameManager.task_deadline_time, 0.0)
			deadline_label.text = "TIME REMAINING: %.1fs" % t
	else:
		deadline_label.text = ""

func _on_morale_changed(val: float) -> void:
	var tween = create_tween()
	tween.tween_property(morale_bar, "value", val, 0.3).set_ease(Tween.EASE_OUT)
	
	if val < 33.0:
		moral_texture.texture = moral_bad
	elif val > 66.0:
		moral_texture.texture = moral_good
	else:
		moral_texture.texture = moral_mid

func _on_productivity_changed(val: float) -> void:
	var tween = create_tween()
	tween.tween_property(productivity_bar, "value", val, 0.3).set_ease(Tween.EASE_OUT)

	
	if val < 33.0:
		productive_texture.texture = productive_bad
	elif val > 66.0:
		productive_texture.texture = productive_good
	else:
		productive_texture.texture = productive_mid
func _on_objective_completed(_task_id: String) -> void:
	_animate_task_complete()

func _on_all_completed() -> void:
	clockout_label.visible = true

func _on_loop_restarted(_loop_number: int) -> void:
	clockout_label.visible = false
	task_bg.position.x = 1550.0
	_show_current_task()

func _on_npc_talk_updated(_count: int) -> void:
	if not _animating and GameManager.get_current_task_id() == "talk_npcs":
		_refresh_task_text()

func _get_task_display_text(idx: int) -> String:
	if idx >= GameManager.objectives.size():
		return ""
	var obj = GameManager.objectives[idx]
	var label_text = obj["label"]
	if obj["id"] == "talk_npcs":
		label_text = "Talk to coworkers (%d/%d)" % [GameManager.get_talked_count(), GameManager.REQUIRED_NPC_TALKS]
	return "Task %d/%d - %s" % [idx + 1, GameManager.get_total_count(), label_text]

func _update_task_texture() -> void:
	# If text is long, use big texture, else small
	# A typical short task is ~25 chars including bbcode tags
	pass
func _refresh_task_text() -> void:
	var idx = GameManager.current_task_index
	task_label.text = _get_task_display_text(idx)
	_update_task_texture()

func _show_current_task() -> void:
	var idx = GameManager.current_task_index
	if idx >= GameManager.objectives.size():
		task_label.text = ""
		task_bg.visible = false
		return
	
	task_bg.visible = true
	task_label.text = _get_task_display_text(idx)
	_update_task_texture()
	
	task_bg.position.x = 1920.0
	var tween = create_tween()
	tween.tween_property(task_bg, "position:x", 1500.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_task_complete() -> void:
	if _animating:
		return
	_animating = true
	
	var idx = GameManager.current_task_index - 1
	if idx < 0 or idx >= GameManager.objectives.size():
		_animating = false
		return
	
	task_label.text = "DONE - %s" % _get_task_display_text(idx)
	
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(task_bg, "position:x", 1550.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_slide_out_done)

func _on_slide_out_done() -> void:
	_animating = false
	if GameManager.current_task_index >= GameManager.objectives.size():
		task_bg.visible = false
	else:
		_show_current_task()
