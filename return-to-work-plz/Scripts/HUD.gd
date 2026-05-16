extends CanvasLayer

## HUD — Placeholder UI overlay.
## Shows room name, loop counter, current task with slide animations, clock-out prompt.

@onready var room_label: Label = $RoomLabel
@onready var loop_label: Label = $LoopLabel
@onready var task_label: RichTextLabel = $TaskPanel/TaskLabel
@onready var task_panel: PanelContainer = $TaskPanel
@onready var clockout_label: Label = $ClockOutLabel

var _animating: bool = false

func _ready() -> void:
	RoomManager.room_changed.connect(_on_room_changed)
	GameManager.objective_completed.connect(_on_objective_completed)
	GameManager.all_objectives_completed.connect(_on_all_completed)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	clockout_label.visible = false
	_update_loop_label()
	# Show the first task with a slide-in
	_show_current_task()

func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name

func _on_objective_completed(_task_id: String) -> void:
	# Strikethrough the completed task, slide out, then show next
	_animate_task_complete()

func _on_all_completed() -> void:
	clockout_label.visible = true

func _on_loop_restarted(_loop_number: int) -> void:
	_update_loop_label()
	clockout_label.visible = false
	task_panel.position.x = 1920.0  # Off-screen right
	_show_current_task()

func _update_loop_label() -> void:
	loop_label.text = "Day #%d" % GameManager.current_loop

func _show_current_task() -> void:
	var idx = GameManager.current_task_index
	if idx >= GameManager.objectives.size():
		task_label.text = ""
		task_panel.visible = false
		return
	
	var obj = GameManager.objectives[idx]
	task_panel.visible = true
	task_label.bbcode_enabled = true
	task_label.text = "[center]%d/%d  %s[/center]" % [idx + 1, GameManager.get_total_count(), obj["label"]]
	
	# Slide in from right
	task_panel.position.x = 1920.0
	var tween = create_tween()
	tween.tween_property(task_panel, "position:x", 1400.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_task_complete() -> void:
	if _animating:
		return
	_animating = true
	
	var idx = GameManager.current_task_index - 1  # Just completed task
	if idx < 0 or idx >= GameManager.objectives.size():
		_animating = false
		return
	
	var obj = GameManager.objectives[idx]
	
	# Show strikethrough
	task_label.text = "[center][s]%d/%d  %s[/s]  ✓[/center]" % [idx + 1, GameManager.get_total_count(), obj["label"]]
	
	# Wait a beat, then slide out to the left
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(task_panel, "position:x", -500.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_slide_out_done)

func _on_slide_out_done() -> void:
	_animating = false
	# Show the next task (or hide if all done)
	if GameManager.can_clock_out():
		task_panel.visible = false
	else:
		_show_current_task()
