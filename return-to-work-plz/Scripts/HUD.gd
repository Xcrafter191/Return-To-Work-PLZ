extends CanvasLayer

## HUD — Main UI overlay.
## Shows Productivity, Morale, and Current Task.

@onready var productivity_badge: TextureRect = $ProdBarBackground/Badge
@onready var productivity_bar: TextureProgressBar = $ProductivityContainer/Bar
@onready var morale_bar: TextureProgressBar = $MoraleContainer/Bar
@onready var task_bg: TextureRect = $TaskBackground
@onready var task_label: RichTextLabel = $TaskBackground/TaskLabel
@onready var clockout_label: Label = $ClockOutLabel
@onready var value_productivity: Label = $ProdBarBackground/LabelValueProduct
@onready var value_moral: Label = $MoraleBarBackgroumd/LabelValueMoral


var tex_task_small: Texture2D = preload("res://Assets/UI V1/TEXT BOX/TASK SMALL.png")
var tex_task_big: Texture2D = preload("res://Assets/UI V1/TEXT BOX/TASK SMALL.png")
var tex_badge_bad: Texture2D = preload("res://Assets/UI V1/BADGE/QUOTA BAD.png")
var tex_badge_mid: Texture2D = preload("res://Assets/UI V1/BADGE/QUOTA MID.png")
var tex_badge_good: Texture2D = preload("res://Assets/UI V1/BADGE/QUOTA GOOD.png")

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

func _on_morale_changed(val: float) -> void:
	var tween = create_tween()
	tween.tween_property(morale_bar, "value", val, 0.3).set_ease(Tween.EASE_OUT)
	value_moral.text = str(int(val)) + " %"

func _on_productivity_changed(val: float) -> void:
	var tween = create_tween()
	tween.tween_property(productivity_bar, "value", val, 0.3).set_ease(Tween.EASE_OUT)
	value_productivity.text = str(int(val)) + " %"
	
	# Swap badge
	if val < 33.0:
		productivity_badge.texture = tex_badge_bad
	elif val > 66.0:
		productivity_badge.texture = tex_badge_good
	else:
		productivity_badge.texture = tex_badge_mid

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
	if task_label.text.length() > 38: 
		task_bg.texture = tex_task_big
	else:
		task_bg.texture = tex_task_small

func _refresh_task_text() -> void:
	var idx = GameManager.current_task_index
	task_label.text = "[center]%s[/center]" % _get_task_display_text(idx)
	_update_task_texture()

func _show_current_task() -> void:
	var idx = GameManager.current_task_index
	if idx >= GameManager.objectives.size():
		task_label.text = ""
		task_bg.visible = false
		return
	
	task_bg.visible = true
	task_label.text = "[center]%s[/center]" % _get_task_display_text(idx)
	_update_task_texture()
	
	task_bg.position.x = 1920.0
	var tween = create_tween()
	tween.tween_property(task_bg, "position:x", 1550.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_task_complete() -> void:
	if _animating:
		return
	_animating = true
	
	var idx = GameManager.current_task_index - 1
	if idx < 0 or idx >= GameManager.objectives.size():
		_animating = false
		return
	
	task_label.text = "[center][s]%s[/s][/center]" % _get_task_display_text(idx)
	
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
