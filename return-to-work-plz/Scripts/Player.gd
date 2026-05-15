extends CharacterBody2D

## Player — Office worker character
## Left/right movement only, no jumping. Interacts with NPCs via 'E'.

@export var move_speed: float = 250.0
@export var gravity: float = 980.0

var nearby_interactable: Node = null

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	# Horizontal movement
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * move_speed
	
	# Flip sprite direction
	if input_dir != 0.0:
		var sprite = $Sprite
		if sprite:
			sprite.scale.x = sign(input_dir) * abs(sprite.scale.x)
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and nearby_interactable:
		if nearby_interactable.has_method("interact"):
			nearby_interactable.interact()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	# Detect NPCs or interactables
	if body.has_method("interact") and body != self:
		nearby_interactable = body

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body == nearby_interactable:
		nearby_interactable = null
		# Hide any interaction prompts
		if body.has_method("hide_prompt"):
			body.hide_prompt()

func _on_interaction_area_area_entered(area: Area2D) -> void:
	# Also detect Area2D-based interactables
	var parent = area.get_parent()
	if parent and parent.has_method("interact") and parent != self:
		nearby_interactable = parent

func _on_interaction_area_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == nearby_interactable:
		nearby_interactable = null
		if parent.has_method("hide_prompt"):
			parent.hide_prompt()
