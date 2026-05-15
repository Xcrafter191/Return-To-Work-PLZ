extends CharacterBody2D

## NPCMoving — Coworker that patrols between two points.
## Shows dialogue box when player is nearby. Faces player when in range.

@export var npc_name: String = "Wandering Coworker"
@export var dialogue_text: String = "Can't talk, gotta move..."
@export var move_speed: float = 80.0
@export var gravity: float = 980.0
@export var patrol_left_x: float = 100.0
@export var patrol_right_x: float = 500.0
@export var sprite_texture: Texture2D = null

var _moving_right: bool = true
var player_nearby: bool = false
var _fade_tween: Tween = null

@onready var dialogue_box: Node2D = $DialogueBox
@onready var dialogue_label: Label = $DialogueBox/Label
@onready var dialogue_bg: ColorRect = $DialogueBox/BG
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	dialogue_box.visible = false
	dialogue_box.modulate.a = 0.0
	dialogue_label.text = dialogue_text
	if sprite_texture:
		sprite.texture = sprite_texture
	_resize_dialogue_bg()
	$InteractionArea.body_entered.connect(_on_player_entered)
	$InteractionArea.body_exited.connect(_on_player_exited)

func _resize_dialogue_bg() -> void:
	await get_tree().process_frame
	var text_width = dialogue_label.get_minimum_size().x
	var padding = 16.0
	var half_w = max(text_width / 2.0 + padding, 60.0)
	dialogue_bg.offset_left = -half_w
	dialogue_bg.offset_right = half_w
	dialogue_label.offset_left = -half_w + 6.0
	dialogue_label.offset_right = half_w - 6.0

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
	
	# Face player when nearby, otherwise face movement direction
	# Sprites face LEFT by default, so negative scale = face right
	if player_nearby:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if player.global_position.x > global_position.x:
				sprite.scale.x = -abs(sprite.scale.x)
			else:
				sprite.scale.x = abs(sprite.scale.x)
	else:
		# Face movement direction (negated: moving right → face right → negative scale)
		sprite.scale.x = (-1.0 if _moving_right else 1.0) * abs(sprite.scale.x)
	
	move_and_slide()

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
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
