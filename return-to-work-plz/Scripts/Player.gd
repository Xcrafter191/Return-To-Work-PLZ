extends CharacterBody2D

## Player — Office worker character
## Left/right movement only, no jumping. Can work at interactable objects.

@export var move_speed: float = 1000.0
@export var gravity: float = 980.0

var is_working: bool = false
var work_progress: float = 0.0
var work_duration: float = 3.0
var nearby_workstation: Node = null
var _is_stuck_timer_started: bool = false

@onready var progress_container: Node2D = $ProgressContainer
@onready var progress_bg: ColorRect = $ProgressContainer/ProgressBG
@onready var progress_fill: ColorRect = $ProgressContainer/ProgressFill
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite if has_node("AnimSprite") else null

var current_anim_state: String = "idle"

func _ready() -> void:
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	if is_working:
		velocity.x = 0.0
		
		if InconvenienceManager.is_stuck_99 and work_progress >= 0.99 and not _is_stuck_timer_started:
			work_progress = 0.99
			_update_progress_bar()
			_is_stuck_timer_started = true
			var t = get_tree().create_timer(5.0)
			t.timeout.connect(func():
				if is_working:
					_is_stuck_timer_started = false
					work_progress = 1.0
					_update_progress_bar()
					_complete_task()
			)
			
		if not _is_stuck_timer_started:
			work_progress += delta / work_duration
			work_progress = min(work_progress, 1.0)
			_update_progress_bar()
			if work_progress >= 1.0:
				_complete_task()
	else:
		# Horizontal movement
		var input_dir: float = Input.get_axis("move_left", "move_right")
		
		velocity.x = input_dir * move_speed
		
		# Flip sprite direction
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

# ── Animation State Machine ──
func _play_anim(anim_name: String) -> void:
	if not anim_sprite: return
	if anim_sprite.animation == anim_name: return
	anim_sprite.play(anim_name)

func _update_animation(input_dir: float) -> void:
	if not anim_sprite: return
	
	if is_working:
		if current_anim_state != "interact":
			current_anim_state = "interact"
			_play_anim("interact")
		return
		
	var is_moving = input_dir != 0.0
	
	match current_anim_state:
		"interact":
			# We finished working
			current_anim_state = "idle"
			_play_anim("idle")
		"idle":
			if is_moving:
				current_anim_state = "trans-idle-walk"
				_play_anim("trans-idle-walk")
			else:
				_play_anim("idle")
		"walk":
			if not is_moving:
				current_anim_state = "trans-walk-idle"
				_play_anim("trans-walk-idle")
			else:
				_play_anim("walk")
		"trans-idle-walk":
			pass # Lock state until animation finishes
		"trans-walk-idle":
			if is_moving:
				current_anim_state = "walk"
				_play_anim("walk")

func _on_animation_finished() -> void:
	if current_anim_state == "trans-idle-walk":
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			current_anim_state = "walk"
			_play_anim("walk")
		else:
			# Player stopped before the transition finished
			current_anim_state = "trans-walk-idle"
			_play_anim("trans-walk-idle")
			
	elif current_anim_state == "trans-walk-idle":
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			current_anim_state = "trans-idle-walk"
			_play_anim("trans-idle-walk")
		else:
			current_anim_state = "idle"
			_play_anim("idle")

## Note: Interaction input is handled by InteractableObject._input,
## which checks task availability before calling start_task().

## Called by InteractableObject when player enters range
func set_nearby_workstation(obj: Node) -> void:
	nearby_workstation = obj

func clear_nearby_workstation(obj: Node) -> void:
	if nearby_workstation == obj:
		nearby_workstation = null

## Start a timed task — locks movement, shows progress bar
func start_task(duration: float = 3.0) -> void:
	is_working = true
	work_progress = 0.0
	_is_stuck_timer_started = false
	work_duration = duration
	progress_container.visible = true
	progress_container.modulate.a = 1.0
	_update_progress_bar()

func _update_progress_bar() -> void:
	# Fill grows from left to right (total 100px width)
	progress_fill.offset_right = progress_fill.offset_left + 100.0 * work_progress

func _complete_task() -> void:
	is_working = false
	if nearby_workstation and nearby_workstation.has_method("on_interact_complete"):
		nearby_workstation.on_interact_complete()
	_blink_and_fade()

func _blink_and_fade() -> void:
	var tween = create_tween()
	# Blink 5 times
	for i in 5:
		tween.tween_property(progress_container, "modulate:a", 0.2, 0.1)
		tween.tween_property(progress_container, "modulate:a", 1.0, 0.1)
	# Fade out
	tween.tween_property(progress_container, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_hide_progress)

func _hide_progress() -> void:
	progress_container.visible = false
	progress_container.modulate.a = 1.0
