extends CharacterBody2D

## Player — Office worker character
## Left/right movement only, no jumping. Can work at interactable objects.

@export var move_speed: float = 700.0
@export var gravity: float = 980.0

var is_working: bool = false
var work_progress: float = 0.0
var work_duration: float = 3.0
var nearby_workstation: Node = null
@onready var progress_container: Node2D = $ProgressContainer
@onready var progress_bg: ColorRect = $ProgressContainer/ProgressBG
@onready var progress_fill: ColorRect = $ProgressContainer/ProgressFill
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite if has_node("AnimSprite") else null

var current_anim_state: String = "idle"

# ── QTE / Progress-bar state ──
const BASE_FILL_SPEED: float = 0.12   ## Progress per second at normal speed (~8s full bar)
const SLOW_FILL_SPEED: float = 0.04   ## Slowed speed after a failed QTE (~25s full bar)

var fill_speed: float = BASE_FILL_SPEED
var is_filling: bool = false           ## True while the bar is actively advancing

var qte_checkpoints: Array = []        ## Sorted list of pre-generated QTE trigger thresholds
var next_checkpoint_idx: int = 0       ## Which pre-generated checkpoint we're heading toward next
var current_threshold: float = 2.0    ## The actual progress value where the bar pauses (>1 = none)
var qte_required: int = 1
var qte_completed: int = 0

func _ready() -> void:
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		if GameManager.morale < 33:
			anim_sprite.play("idleaware")
		else:
			anim_sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	if is_working:
		velocity.x = 0.0
		_update_animation(0.0)
		_tick_progress_bar(delta)
	else:
		var input_dir: float = Input.get_axis("move_left", "move_right")
		velocity.x = input_dir * move_speed
		if input_dir != 0.0:
			var sprite = $Sprite if has_node("Sprite") else anim_sprite
			if sprite:
				sprite.scale.x = -sign(input_dir) * abs(sprite.scale.x)
		_update_animation(input_dir)
		
	# Inconvenience: Shaky
	var cam = $Camera2D if has_node("Camera2D") else null
	if cam:
		if InconvenienceManager.is_shaky and velocity.x != 0.0:
			cam.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		else:
			cam.offset = Vector2.ZERO
	
	move_and_slide()

## Advance the progress bar each frame.
## The bar pauses at current_threshold to fire a QTE.
## After all QTEs are passed, it fills the rest of the way to 1.0 before completing.
func _tick_progress_bar(delta: float) -> void:
	if not is_filling: return

	work_progress = minf(work_progress + fill_speed * delta, 1.0)
	_update_progress_bar()

	# Reached a QTE checkpoint — pause and show QTE
	if work_progress >= current_threshold and current_threshold <= 1.0:
		is_filling = false
		_launch_qte()
		return

	# All QTEs done and bar is full — complete the task
	if current_threshold > 1.0 and work_progress >= 1.0:
		_complete_task()

## Helper: pick the correct idle animation based on morale
func _get_idle_anim() -> String:
	if GameManager.morale < 33:
		return "idleaware"
	return "idle"

# ── Animation State Machine ──
func _play_anim(anim_name: String) -> void:
	if not anim_sprite: return
	if anim_sprite.animation == anim_name: return
	anim_sprite.play(anim_name)

func _update_animation(input_dir: float) -> void:
	if not anim_sprite: return
	if is_working:
		_play_anim("interact")
		return
	var is_moving = input_dir != 0.0
	var idle_anim = _get_idle_anim()
	match current_anim_state:
		"interact":
			current_anim_state = "trans-walk-idle"
			_play_anim("trans-walk-idle")
		"idle", "idleaware":
			if is_moving:
				current_anim_state = "trans-idle-walk"
				_play_anim("trans-idle-walk")
			else:
				current_anim_state = idle_anim
				_play_anim(idle_anim)
		"walk":
			if not is_moving:
				current_anim_state = "trans-walk-idle"
				_play_anim("trans-walk-idle")
			else:
				_play_anim("walk")
		"trans-idle-walk":
			pass
		"trans-walk-idle":
			if is_moving:
				current_anim_state = "walk"
				_play_anim("walk")

func _on_animation_finished() -> void:
	var idle_anim = _get_idle_anim()
	if current_anim_state == "trans-idle-walk":
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			current_anim_state = "walk"
			_play_anim("walk")
		else:
			current_anim_state = "trans-walk-idle"
			_play_anim("trans-walk-idle")
	elif current_anim_state == "trans-walk-idle":
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			current_anim_state = "trans-idle-walk"
			_play_anim("trans-idle-walk")
		else:
			current_anim_state = idle_anim
			_play_anim(idle_anim)

func set_nearby_workstation(obj: Node) -> void:
	nearby_workstation = obj

func clear_nearby_workstation(obj: Node) -> void:
	if nearby_workstation == obj:
		nearby_workstation = null

## Start a task — bar fills automatically, pausing at random checkpoints for QTEs
func start_task(duration: float = 3.0) -> void:
	is_working = true
	work_duration = duration
	work_progress = 0.0
	fill_speed = BASE_FILL_SPEED

	# QTEs needed = clamp(current_loop, 1, 4)
	qte_required = clampi(GameManager.current_loop, 1, 4)
	if InconvenienceManager.is_stuck_99:
		qte_required += 4
		
	qte_completed = 0
	next_checkpoint_idx = 0

	# Pre-generate sorted random checkpoint positions
	qte_checkpoints = _generate_checkpoints(qte_required)
	current_threshold = qte_checkpoints[0]

	progress_container.visible = true
	_update_progress_bar()
	is_filling = true

	if not SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.connect(_on_qte_completed)

## Generate `count` random thresholds in (0.05, 0.95), one per equal segment, sorted
func _generate_checkpoints(count: int) -> Array:
	var points: Array = []
	for i in range(count):
		var seg_start = maxf(float(i) / float(count), 0.05)
		var seg_end   = minf(float(i + 1) / float(count), 0.95)
		points.append(randf_range(seg_start, seg_end))
	points.sort()
	return points

## Show QTE bar
func _launch_qte() -> void:
	var base_speed = 400.0 * GameManager.difficulty_modifier
	SkillCheck.start_skill_check(base_speed)

func _on_qte_completed(success: bool) -> void:
	if success:
		qte_completed += 1
		next_checkpoint_idx += 1
		fill_speed = BASE_FILL_SPEED  # Restore normal speed

		if next_checkpoint_idx < qte_checkpoints.size():
			# More checkpoints — set next threshold and resume
			current_threshold = qte_checkpoints[next_checkpoint_idx]
		else:
			# All QTEs passed — let bar fill freely to 1.0 before completing
			current_threshold = 2.0  # > 1.0 means "no more pauses"

		is_filling = true
	else:
		# Fail — deduct productivity (scales with loop), slow the bar heavily.
		# The bar must crawl visibly before the next QTE appears.
		var prod_loss = clampf(2.0 + (GameManager.current_loop - 1) * 1.5, 2.0, 15.0)
		GameManager.set_productivity(GameManager.productivity - prod_loss)
		
		# Check for game over
		if GameManager.productivity <= 0:
			_trigger_game_over()
			return
		
		fill_speed = SLOW_FILL_SPEED

		# Retry threshold is 0.15–0.35 ahead of current position (noticeable slow crawl)
		var retry_distance = randf_range(0.15, 0.35)
		var retry_pos = work_progress + retry_distance
		if next_checkpoint_idx < qte_checkpoints.size():
			retry_pos = minf(retry_pos, qte_checkpoints[next_checkpoint_idx])
		retry_pos = minf(retry_pos, 0.95)
		current_threshold = retry_pos

		is_filling = true

func _update_progress_bar() -> void:
	progress_fill.offset_right = progress_fill.offset_left + 100.0 * work_progress

## Called ONLY when the bar reaches 1.0 after all QTEs are passed
func _complete_task() -> void:
	is_working = false
	is_filling = false
	InconvenienceManager.is_stuck_99 = false
	_update_animation(0.0)
	
	progress_container.visible = false
	if nearby_workstation and nearby_workstation.has_method("on_interact_complete"):
		nearby_workstation.on_interact_complete()
	if SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.disconnect(_on_qte_completed)

func _trigger_game_over() -> void:
	cancel_task()
	GameManager.current_loop = 1
	GameManager.productivity = 100.0
	GameManager.morale = 100.0
	InconvenienceManager._reset_permanent_inconveniences()
	get_tree().change_scene_to_file("res://Scenes/UI/GameOver.tscn")

func cancel_task() -> void:
	if not is_working: return
	is_working = false
	is_filling = false
	InconvenienceManager.is_stuck_99 = false
	_update_animation(0.0)
	
	if SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.disconnect(_on_qte_completed)
	SkillCheck.visible = false
	SkillCheck.is_active = false
	if nearby_workstation and nearby_workstation.has_method("_update_prompt"):
		nearby_workstation._update_prompt()
	progress_container.visible = false
	progress_container.modulate.a = 1.0

func set_movement_locked(locked: bool) -> void:
	set_physics_process(not locked)
	set_process_input(not locked)
	if locked:
		velocity = Vector2.ZERO
		_update_animation(0.0)
