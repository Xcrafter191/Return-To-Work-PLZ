extends CharacterBody2D

## Player — Office worker character
## Left/right movement only, no jumping. Can work at interactable objects.

@export var move_speed: float = 250.0
@export var gravity: float = 980.0

var is_working: bool = false
var work_progress: float = 0.0
var work_duration: float = 3.0
var nearby_workstation: Node = null

@onready var progress_container: Node2D = $ProgressContainer
@onready var progress_bg: ColorRect = $ProgressContainer/ProgressBG
@onready var progress_fill: ColorRect = $ProgressContainer/ProgressFill

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	if is_working:
		velocity.x = 0.0
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
			var sprite = $Sprite
			if sprite:
				sprite.scale.x = -sign(input_dir) * abs(sprite.scale.x)
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and nearby_workstation and not is_working:
		if nearby_workstation.has_method("on_interact_start"):
			nearby_workstation.on_interact_start()
		start_task()

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
