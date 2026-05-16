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
	GameManager.npc_talk_updated.connect(_on_npc_talk_updated)
	clockout_label.visible = false
	_update_loop_label()
	_show_current_task()

func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name

func _on_objective_completed(_task_id: String) -> void:
	_animate_task_complete()

func _on_all_completed() -> void:
	clockout_label.visible = true

func _on_loop_restarted(_loop_number: int) -> void:
	_update_loop_label()
	clockout_label.visible = false
	task_panel.position.x = 1920.0
	_show_current_task()

func _on_npc_talk_updated(_count: int) -> void:
	# Refresh the task label if showing the talk_npcs task
	if not _animating and GameManager.get_current_task_id() == "talk_npcs":
		_refresh_task_text()

func _update_loop_label() -> void:
	loop_label.text = "Day #%d" % GameManager.current_loop

func _get_task_display_text(idx: int) -> String:
	if idx >= GameManager.objectives.size():
		return ""
	var obj = GameManager.objectives[idx]
	var label_text = obj["label"]
	# Show NPC count for talk_npcs task
	if obj["id"] == "talk_npcs":
		label_text = "Talk to coworkers (%d/%d)" % [GameManager.get_talked_count(), GameManager.REQUIRED_NPC_TALKS]
	return "%d/%d  %s" % [idx + 1, GameManager.get_total_count(), label_text]

func _refresh_task_text() -> void:
	var idx = GameManager.current_task_index
	task_label.text = "[center]%s[/center]" % _get_task_display_text(idx)

func _show_current_task() -> void:
	var idx = GameManager.current_task_index
	if idx >= GameManager.objectives.size():
		task_label.text = ""
		task_panel.visible = false
		return
	
	task_panel.visible = true
	task_label.bbcode_enabled = true
	task_label.text = "[center]%s[/center]" % _get_task_display_text(idx)
	
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
	
	# Show strikethrough
	task_label.text = "[center][s]%s[/s]  ✓[/center]" % _get_task_display_text(idx)
	
	# Wait, then slide out left
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(task_panel, "position:x", -500.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_slide_out_done)

func _on_slide_out_done() -> void:
	_animating = false
	if GameManager.current_task_index >= GameManager.objectives.size():
		task_panel.visible = false
	else:
		_show_current_task()
