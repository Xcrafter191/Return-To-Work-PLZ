extends CharacterBody2D

## NPCStationary — Coworker that stays in place.
## Shows dialogue box when player is nearby, faces toward player.

@export var npc_name: String = "Coworker"
@export var dialogue_text: String = "Hey, back to work...":
	set(value):
		dialogue_text = value
		if is_inside_tree() and dialogue_label:
			dialogue_label.text = dialogue_text
@export var gravity: float = 980.0
@export var sprite_texture: Texture2D = null
@export var dialogue_offset_y: float = -380.0

var player_nearby: bool = false
var _fade_tween: Tween = null

@onready var dialogue_box: Node2D = $DialogueBox
@onready var dialogue_label: Label = $DialogueBox/Bubble/Label
@onready var dialogue_bg: PanelContainer = $DialogueBox/Bubble
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	dialogue_box.visible = false
	dialogue_box.modulate.a = 0.0
	dialogue_box.position.y = dialogue_offset_y
	dialogue_label.text = dialogue_text
	if sprite_texture:
		sprite.texture = sprite_texture
	
	# Set a max width so it wraps if text is too long
	dialogue_label.custom_minimum_size.x = 100 # Min width
	dialogue_bg.custom_minimum_size.x = 100
	
	$InteractionArea.body_entered.connect(_on_player_entered)
	$InteractionArea.body_exited.connect(_on_player_exited)

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
				sprite.scale.x = -abs(sprite.scale.x)
			else:
				sprite.scale.x = abs(sprite.scale.x)

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
