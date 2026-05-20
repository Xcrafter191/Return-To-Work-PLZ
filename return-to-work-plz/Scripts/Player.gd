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
var is_locked: bool = false  ## True during attack sequence — blocks movement and animation overrides

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
	GameManager.morale_changed.connect(_on_morale_changed)

func _on_morale_changed(new_morale: float) -> void:
	if new_morale < 33:
		if current_anim_state == "idle":
			play_state("idleaware")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	if is_working:
		velocity.x = 0.0
		_update_animation(0.0)
		_tick_progress_bar(delta)
	elif is_locked:
		velocity.x = 0.0
		# Don't call _update_animation — let the attack anim play uninterrupted
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
var target_state: String = ""

func _play_anim(anim_name: String) -> void:
	if not anim_sprite: return
	if anim_sprite.animation == anim_name: return
	anim_sprite.play(anim_name)

## Get current base state name (ignores transition prefixes)
func _get_base_state(state: String) -> String:
	if state.begins_with("trans-"):
		var parts = state.split("-")
		if parts.size() >= 3:
			var dest = parts[parts.size() - 1]
			if dest == "aware":
				return "idleaware"
			return dest
	return state

## Check if transition exists and returns its name, otherwise empty string
func _get_transition_name(from_state: String, to_state: String) -> String:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return ""
	
	var f = _get_base_state(from_state)
	var t = _get_base_state(to_state)
	
	if f == t:
		return ""
		
	# Try candidates based on naming pattern
	var candidates = [
		"trans-" + f + "-" + t,
		"trans-" + f.replace("idleaware", "aware") + "-" + t.replace("idleaware", "aware"),
		"trans-" + f.replace("idleaware", "aware") + "-" + t,
		"trans-" + f + "-" + t.replace("idleaware", "aware")
	]
	
	for cand in candidates:
		if anim_sprite.sprite_frames.has_animation(cand):
			return cand
	return ""

## Play animation with transition if one exists
func play_state(new_state: String) -> void:
	if not anim_sprite: return
	
	var current_base = _get_base_state(current_anim_state)
	var target_base = _get_base_state(new_state)
	
	if current_base == target_base:
		if not current_anim_state.begins_with("trans-"):
			current_anim_state = new_state
			_play_anim(new_state)
		return
		
	var trans = _get_transition_name(current_anim_state, new_state)
	if trans != "":
		target_state = new_state
		current_anim_state = trans
		_play_anim(trans)
	else:
		target_state = ""
		current_anim_state = new_state
		_play_anim(new_state)

func _update_animation(input_dir: float) -> void:
	if not anim_sprite: return
	if is_working:
		play_state("interact")
		return
		
	var is_moving = input_dir != 0.0
	var target = "walk" if is_moving else _get_idle_anim()
	
	# Allow quick responsive switches if we reverse direction mid-transition
	if current_anim_state == "trans-idle-walk" and not is_moving:
		play_state(target)
	elif current_anim_state == "trans-walk-idle" and is_moving:
		play_state(target)
	elif not current_anim_state.begins_with("trans-"):
		play_state(target)

func _on_animation_finished() -> void:
	if current_anim_state.begins_with("trans-"):
		if target_state != "":
			var next = target_state
			target_state = ""
			current_anim_state = next
			_play_anim(next)
		else:
			var input_dir: float = Input.get_axis("move_left", "move_right")
			var is_moving = input_dir != 0.0
			var next = "walk" if is_moving else _get_idle_anim()
			current_anim_state = next
			_play_anim(next)

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

		var retry_distance = randf_range(0.15, 0.35)
		var new_pos = minf(work_progress + retry_distance, 0.99)
		
		var found = false
		if next_checkpoint_idx < qte_checkpoints.size():
			qte_checkpoints[next_checkpoint_idx] = new_pos
			qte_checkpoints.sort()
			
			for i in range(qte_checkpoints.size()):
				if qte_checkpoints[i] > work_progress + 0.01:
					next_checkpoint_idx = i
					current_threshold = qte_checkpoints[i]
					found = true
					break
		
		if not found:
			current_threshold = new_pos

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
	GameManager._trigger_game_over()

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
