extends CanvasLayer

## HUD — Placeholder UI overlay.
## Shows room name, loop counter, objective checklist, clock-out prompt.

@onready var room_label: Label = $RoomLabel
@onready var loop_label: Label = $LoopLabel
@onready var objective_list: VBoxContainer = $ObjectivePanel/ObjectiveList
@onready var objective_panel: PanelContainer = $ObjectivePanel
@onready var clockout_label: Label = $ClockOutLabel

func _ready() -> void:
	RoomManager.room_changed.connect(_on_room_changed)
	GameManager.objective_completed.connect(_on_objective_completed)
	GameManager.all_objectives_completed.connect(_on_all_completed)
	GameManager.loop_restarted.connect(_on_loop_restarted)
	clockout_label.visible = false
	_update_loop_label()
	_build_objective_list()

func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name

func _on_objective_completed(_task_id: String) -> void:
	_build_objective_list()

func _on_all_completed() -> void:
	clockout_label.visible = true

func _on_loop_restarted(loop_number: int) -> void:
	_update_loop_label()
	_build_objective_list()
	clockout_label.visible = false

func _update_loop_label() -> void:
	loop_label.text = "Day #%d" % GameManager.current_loop

func _build_objective_list() -> void:
	# Clear existing items
	for child in objective_list.get_children():
		child.queue_free()
	# Build fresh list
	for obj in GameManager.objectives:
		var item = Label.new()
		if obj["completed"]:
			item.text = "[x] " + obj["label"]
			item.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			item.text = "[ ] " + obj["label"]
		item.add_theme_font_size_override("font_size", 18)
		objective_list.add_child(item)
