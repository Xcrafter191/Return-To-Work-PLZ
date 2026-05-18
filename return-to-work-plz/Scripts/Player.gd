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
		_update_animation(0.0)
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
		_play_anim("interact")
		return
		
	var is_moving = input_dir != 0.0
	
	match current_anim_state:
		"interact":
			current_anim_state = "idle"
			if GameManager.morale < 33:
				_play_anim("idleaware")
			else:
				_play_anim("idle")
		"idle", "idleaware":
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
			if GameManager.morale < 33:
				current_anim_state = "idleaware"
				_play_anim("idleaware")
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

## Start a QTE skill check task — locks movement
func start_task(_duration: float = 3.0) -> void:
	is_working = true
	
	# Determine arrow speed based on difficulty modifier
	var base_speed = 400.0 * GameManager.difficulty_modifier
	
	SkillCheck.start_skill_check(base_speed)
	
	if not SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.connect(_on_qte_completed)

func _on_qte_completed(success: bool) -> void:
	if success:
		_complete_task()
	else:
		# Failed! Deduct productivity and try again.
		GameManager.set_productivity(GameManager.productivity - 2.0)
		var new_speed = 400.0 * GameManager.difficulty_modifier * randf_range(1.1, 1.3)
		SkillCheck.start_skill_check(new_speed)

func _update_progress_bar() -> void:
	# Fill grows from left to right (total 100px width)
	progress_fill.offset_right = progress_fill.offset_left + 100.0 * work_progress

func _complete_task() -> void:
	is_working = false
	if nearby_workstation and nearby_workstation.has_method("on_interact_complete"):
		nearby_workstation.on_interact_complete()
	if SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.disconnect(_on_qte_completed)

func cancel_task() -> void:
	if not is_working: return
	is_working = false
	if SkillCheck.is_connected("skill_check_completed", _on_qte_completed):
		SkillCheck.skill_check_completed.disconnect(_on_qte_completed)
	SkillCheck.visible = false
	SkillCheck.is_active = false
	if nearby_workstation and nearby_workstation.has_method("_update_prompt"):
		nearby_workstation._update_prompt()

	progress_container.visible = false
	progress_container.modulate.a = 1.0
