extends CharacterBody2D

## NPCMoving — Coworker that patrols between two points.
## Shows dialogue box when player is nearby. Always faces movement direction.

@export var npc_name: String = "Wandering Coworker"
@export var dialogue_text: String = "Can't talk, gotta move..."
@export var move_speed: float = 80.0
@export var gravity: float = 980.0
@export var patrol_left_x: float = 100.0
@export var patrol_right_x: float = 500.0
@export var sprite_texture: Texture2D = null
@export var dialogue_offset_y: float = -20.0

var _moving_right: bool = true
var player_nearby: bool = false
var _fade_tween: Tween = null

@onready var dialogue_box: Node2D = $DialogueBox
@onready var dialogue_label: Label = $DialogueBox/Label
@onready var dialogue_bg: TextureRect = $DialogueBox/Bubble
@onready var sprite: Sprite2D = $Sprite if has_node("Sprite") else null
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite if has_node("AnimSprite") else null

func _ready() -> void:
	dialogue_box.visible = false
	dialogue_box.modulate.a = 0.0
	dialogue_box.position.y = dialogue_offset_y
	dialogue_label.text = dialogue_text
	if sprite and sprite_texture:
		sprite.texture = sprite_texture
	
	if anim_sprite:
		if sprite: sprite.visible = false
		anim_sprite.play("walk")
		
	_update_dialogue_position()
	
	# Set a max width so it wraps if text is too long
	dialogue_label.custom_minimum_size.x = 100 # Min width
	dialogue_bg.custom_minimum_size.x = 100
	
	$InteractionArea.body_entered.connect(_on_player_entered)
	$InteractionArea.body_exited.connect(_on_player_exited)

func _update_dialogue_position() -> void:
	var target_node = sprite if sprite else anim_sprite
	if not target_node: return
	
	var sprite_height: float = 0.0
	if target_node is Sprite2D and target_node.texture:
		sprite_height = target_node.texture.get_height() * abs(target_node.scale.y)
	elif target_node is AnimatedSprite2D and target_node.sprite_frames:
		var tex = target_node.sprite_frames.get_frame_texture(target_node.animation, 0)
		if tex: sprite_height = tex.get_height() * abs(target_node.scale.y)
		
	var sprite_top: float = target_node.position.y - (sprite_height / 2.0)
	dialogue_box.position.y = sprite_top + dialogue_offset_y

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	
	if _moving_right:
		velocity.x = move_speed
		if global_position.x >= patrol_right_x:
			_moving_right = false
	else:
		velocity.x = -move_speed
		if global_position.x <= patrol_left_x:
			_moving_right = true
	
	# Only face movement direction (negated: sprites face left by default)
	var target_node = sprite if sprite else anim_sprite
	if target_node:
		target_node.scale.x = (-1.0 if _moving_right else 1.0) * abs(target_node.scale.x)
	
	move_and_slide()

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		GameManager.register_npc_talk(npc_name)
		_show_dialogue()

func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		_fade_dialogue()

func _show_dialogue() -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	dialogue_box.visible = true
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.3)

func _fade_dialogue() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(dialogue_box, "modulate:a", 0.0, 3.0)
	_fade_tween.tween_callback(func(): dialogue_box.visible = false)
