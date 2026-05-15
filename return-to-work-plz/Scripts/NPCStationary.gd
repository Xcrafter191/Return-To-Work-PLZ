extends CharacterBody2D

## NPCStationary — Coworker that stays in place.
## Shows dialogue box when player is nearby, faces toward player.

@export var npc_name: String = "Coworker"
@export var dialogue_text: String = "Hey, back to work..."
@export var gravity: float = 980.0
@export var sprite_texture: Texture2D = null

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
	velocity.x = 0.0
	move_and_slide()
	
	# Face toward player when nearby (negated because sprites face left by default)
	if player_nearby:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if player.global_position.x > global_position.x:
				# Player is to the right → flip sprite to face right (negative scale)
				sprite.scale.x = -abs(sprite.scale.x)
			else:
				# Player is to the left → default facing (positive scale)
				sprite.scale.x = abs(sprite.scale.x)

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
