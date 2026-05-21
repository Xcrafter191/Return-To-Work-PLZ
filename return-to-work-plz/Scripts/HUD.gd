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

var clock_rect: TextureRect = null  ## Animated clock deadline indicator
var _clock_frames_cache: Dictionary = {}  ## Cache for loaded clock frame textures
var direction_arrow: TextureRect = null  ## Flashing arrow CTA pointing toward task room
var _cta_tween: Tween = null

# Slot order on each floor for direction logic
const FLOOR1_SLOTS = ["Slot_F1_Left", "Slot_Elevator_F1", "Slot_F1_Right"]
const FLOOR2_SLOTS = ["Slot_F2_Left", "Slot_F2_Middle", "Slot_Elevator_F2", "Slot_F2_Right", "Slot_F2_FarRight"]

# Maps task room name → which floor slots to search
const TASK_ROOM_TO_SLOT: Dictionary = {
	"Lobby": "Slot_F1_Left",
	"Lounge": "Slot_F2_Left",
	"Printer": "Slot_F2_FarRight",
	"Meeting": "Slot_F2_Right",
}

var texbox_task: Texture2D = preload("res://Assets/UI V4/TEXTBOX/TASK.png")
const productive_mid = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/ALERT.png")
const productive_bad = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/BAD.png")
const productive_good = preload("res://Assets/UI V4/PRODUCTIVITY BAR/BAR/GOOD.png")
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
	GameManager.current_task_changed.connect(_on_current_task_changed)
	if has_node("/root/RoomManager"):
		RoomManager.room_changed.connect(_on_room_changed)
	
	clockout_label.visible = false
	_show_current_task()
	
	# Init bars
	_on_morale_changed(GameManager.morale)
	_on_productivity_changed(GameManager.productivity)
	
	# Create animated clock deadline indicator (TextureRect)
	clock_rect = TextureRect.new()
	clock_rect.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	clock_rect.offset_left   = 20    # jarak dari tepi kiri
	clock_rect.offset_bottom = -20   # jarak dari tepi bawah (negatif = naik)
	clock_rect.offset_right  = 20 + 96   # offset_left + lebar clock (sesuaikan)
	clock_rect.offset_top    = -20 - 96  # offset_bottom - tinggi clock (sesuaikan)
	clock_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	clock_rect.visible = false
	add_child(clock_rect)
	
	# Create directional arrow indicator (TextureRect with ARROW.png)
	direction_arrow = TextureRect.new()
	direction_arrow.texture = load("res://Assets/ARROW.png")
	direction_arrow.custom_minimum_size = Vector2(48, 48)
	direction_arrow.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	direction_arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	direction_arrow.offset_left = 30
	direction_arrow.offset_top = -24
	direction_arrow.offset_right = 78
	direction_arrow.offset_bottom = 24
	direction_arrow.pivot_offset = direction_arrow.custom_minimum_size / 2.0
	direction_arrow.visible = false
	add_child(direction_arrow)
	
	_update_direction_arrow()

func _process(_delta: float) -> void:
	if not clock_rect: return
	
	if not GameManager.is_deadline_active:
		clock_rect.visible = false
		return
	
	clock_rect.visible = true
	var total_deadline: float = 24.0 * GameManager.difficulty_modifier
	var remaining: float = GameManager.task_deadline_time
	var elapsed: float = total_deadline - remaining
	var frame_idx: int = clampi(int((elapsed / total_deadline) * 240), 0, 240)
	var frame_tex: Texture2D = _get_clock_frame(frame_idx)
	if frame_tex:
		clock_rect.texture = frame_tex
	else:
		clock_rect.visible = false
		push_warning("HUD: Clock frame %d unavailable — hiding clock." % frame_idx)

## Load (and cache) a clock frame texture by index (0–240).
func _get_clock_frame(index: int) -> Texture2D:
	if _clock_frames_cache.has(index):
		return _clock_frames_cache[index]
	var path = "res://Assets/clock/time/time_%03d.png" % index
	var tex = load(path)
	if tex:
		_clock_frames_cache[index] = tex
	else:
		push_warning("HUD: Failed to load clock frame at %s" % path)
	return tex

func _on_current_task_changed(_idx: int) -> void:
	_update_direction_arrow()

func _on_room_changed(_room_name: String) -> void:
	_update_direction_arrow()

## Work out which direction the current task room is relative to the player's current room,
## then show a flashing yellow arrow. Hide it if the task is in the current room.
func _update_direction_arrow() -> void:
	if not direction_arrow: return
	
	var task_idx = GameManager.current_task_index
	if task_idx >= GameManager.objectives.size():
		_stop_cta_flash()
		direction_arrow.visible = false
		return
	
	var task_room: String = GameManager.objectives[task_idx].get("room", "")
	if task_room == "Any" or task_room == "Cubicle":
		_stop_cta_flash()
		direction_arrow.visible = false
		return
	
	# Cari slot yang megang task room ini
	var target_slot = ""
	for slot in RoomManager.current_layout:
		if RoomManager.current_layout[slot] == task_room:
			target_slot = slot
			break
	
	if target_slot == "" or target_slot == RoomManager.current_slot:
		_stop_cta_flash()
		direction_arrow.visible = false
		return
	
	# Pakai live array dari RoomManager, bukan constant
	var f1_slots: Array = RoomManager.active_slots_f1
	var f2_slots: Array = RoomManager.active_slots_f2
	
	var current_slot = RoomManager.current_slot
	var in_elevator = ("Elevator" in current_slot)
	
	# Declare variables at function scope to avoid child-block shadowing warnings
	var active_slots: Array = f1_slots if RoomManager.current_floor == 1 else f2_slots
	var cur_idx: int = active_slots.find(current_slot)
	
	# Tentukan floor target
	var target_floor := 0
	if target_slot in f1_slots: target_floor = 1
	elif target_slot in f2_slots: target_floor = 2
	
	# --- Special case: player di dalam elevator ---
	if in_elevator:
		if target_floor == 0:
			# target tidak dikenal, sembunyikan
			_stop_cta_flash()
			direction_arrow.visible = false
			return
		direction_arrow.rotation_degrees = 270.0 if target_floor > RoomManager.current_floor else 90.0
		direction_arrow.set_anchors_preset(Control.PRESET_CENTER)
		direction_arrow.offset_left   = -50
		direction_arrow.offset_right  =  50
		direction_arrow.offset_top    = -50
		direction_arrow.offset_bottom =  50
		direction_arrow.visible = true
		_start_cta_flash()
		return
	
	# --- Guard: target_floor == 0 means slot not found in either floor array ---
	if target_floor == 0:
		_stop_cta_flash()
		direction_arrow.visible = false
		return
	
	# --- Target di lantai berbeda: tunjuk ke elevator ---
	if target_floor != RoomManager.current_floor:
		var elev_key = "Elevator_F1" if RoomManager.current_floor == 1 else "Elevator_F2"
		# Cari slot elevator di floor ini
		var elev_slot = ""
		for slot in RoomManager.current_layout:
			if RoomManager.current_layout[slot] == elev_key:
				elev_slot = slot
				break
		var elev_idx = active_slots.find(elev_slot)
		_set_arrow_side(elev_idx < cur_idx)
		direction_arrow.visible = true
		_start_cta_flash()
		return
	
	# --- Target di lantai sama ---
	var target_idx = active_slots.find(target_slot)
	if cur_idx == -1 or target_idx == -1:
		# Slot tidak dikenal (special room), hide arrow
		_stop_cta_flash()
		direction_arrow.visible = false
		return
	_set_arrow_side(target_idx < cur_idx)
	direction_arrow.visible = true
	_start_cta_flash()


## Helper: true = kiri, false = kanan
func _set_arrow_side(is_left: bool) -> void:
	if is_left:
		direction_arrow.rotation_degrees = 180.0
		direction_arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		direction_arrow.offset_left   =  30
		direction_arrow.offset_right  = 200
	else:
		direction_arrow.rotation_degrees = 0.0
		direction_arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		direction_arrow.offset_right  = -30
		direction_arrow.offset_left   = -170
	direction_arrow.offset_top    = -40
	direction_arrow.offset_bottom =  40

func _start_cta_flash() -> void:
	if _cta_tween and _cta_tween.is_valid():
		return  # Already flashing
	_cta_tween = create_tween().set_loops()
	_cta_tween.tween_property(direction_arrow, "modulate:a", 0.4, 0.45).set_ease(Tween.EASE_IN_OUT)
	_cta_tween.tween_property(direction_arrow, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_IN_OUT)

func _stop_cta_flash() -> void:
	if _cta_tween and _cta_tween.is_valid():
		_cta_tween.kill()
		_cta_tween = null
	if direction_arrow:
		direction_arrow.modulate.a = 1.0

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
	_stop_cta_flash()
	_show_current_task()
	_update_direction_arrow()

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
		_stop_cta_flash()
	else:
		_show_current_task()
		_update_direction_arrow()
