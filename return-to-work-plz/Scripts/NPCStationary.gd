extends CharacterBody2D

## NPCStationary — A coworker NPC that stays in place.
## Placeholder: green rectangle. Shows dialogue on interaction.

@export var npc_name: String = "Coworker"
@export var dialogue_text: String = "Hey, back to work..."
@export var gravity: float = 980.0

var _dialogue_visible: bool = false

func _physics_process(delta: float) -> void:
	# Apply gravity to stay on floor
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	move_and_slide()

func interact() -> void:
	_dialogue_visible = !_dialogue_visible
	var label = $DialogueLabel
	if label:
		label.visible = _dialogue_visible
		label.text = dialogue_text

func hide_prompt() -> void:
	_dialogue_visible = false
	var label = $DialogueLabel
	if label:
		label.visible = false
