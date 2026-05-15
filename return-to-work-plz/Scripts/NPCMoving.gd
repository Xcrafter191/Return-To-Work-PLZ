extends CharacterBody2D

## NPCMoving — A coworker NPC that patrols between two points.
## Placeholder: orange rectangle. Shows dialogue on interaction.

@export var npc_name: String = "Wandering Coworker"
@export var dialogue_text: String = "Can't talk, gotta move..."
@export var move_speed: float = 80.0
@export var gravity: float = 980.0

## Patrol boundaries (X positions relative to room)
@export var patrol_left_x: float = 100.0
@export var patrol_right_x: float = 500.0

var _moving_right: bool = true
var _dialogue_visible: bool = false
var _is_talking: bool = false

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	# Patrol movement (pause when talking)
	if not _is_talking:
		if _moving_right:
			velocity.x = move_speed
			if global_position.x >= patrol_right_x:
				_moving_right = false
		else:
			velocity.x = -move_speed
			if global_position.x <= patrol_left_x:
				_moving_right = true
		
		# Flip sprite based on direction
		var sprite = $Sprite
		if sprite:
			sprite.scale.x = (1.0 if _moving_right else -1.0) * abs(sprite.scale.x)
	else:
		velocity.x = 0.0
	
	move_and_slide()

func interact() -> void:
	_dialogue_visible = !_dialogue_visible
	_is_talking = _dialogue_visible
	var label = $DialogueLabel
	if label:
		label.visible = _dialogue_visible
		label.text = dialogue_text

func hide_prompt() -> void:
	_dialogue_visible = false
	_is_talking = false
	var label = $DialogueLabel
	if label:
		label.visible = false
