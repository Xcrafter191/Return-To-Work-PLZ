extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var logo_rect = $LogoRect
@onready var background_rect = $BackgroundRect

var stationary_npcs = []
var moving_npcs = []
var backgrounds = []

var active_moving_npcs = []

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_load_resources()
	_setup_random_menu()

func _process(delta):
	for data in active_moving_npcs:
		var npc = data.npc
		var speed = data.speed
		if data.moving_right:
			npc.position.x += speed * delta
			if npc.position.x > data.right_bound:
				data.moving_right = false
				_flip_npc(npc, false)
		else:
			npc.position.x -= speed * delta
			if npc.position.x < data.left_bound:
				data.moving_right = true
				_flip_npc(npc, true)

func _flip_npc(npc: Node, moving_right: bool):
	var sprite = npc.get_node_or_null("Sprite")
	if sprite: sprite.scale.x = (-1.0 if moving_right else 1.0) * abs(sprite.scale.x)
	var anim_sprite = npc.get_node_or_null("AnimSprite")
	if anim_sprite: anim_sprite.scale.x = (-1.0 if moving_right else 1.0) * abs(anim_sprite.scale.x)

func _load_resources():
	# Load backgrounds
	var bg_dir = DirAccess.open("res://Assets/Rooms")
	if bg_dir:
		bg_dir.list_dir_begin()
		var file_name = bg_dir.get_next()
		while file_name != "":
			if not bg_dir.current_is_dir() and file_name.ends_with(".png"):
				backgrounds.append("res://Assets/Rooms/" + file_name)
			file_name = bg_dir.get_next()
			
	# Load NPCs
	var npc_dir = DirAccess.open("res://Scenes/NPCs")
	if npc_dir:
		npc_dir.list_dir_begin()
		var file_name = npc_dir.get_next()
		while file_name != "":
			if not npc_dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "StationaryNPC.tscn" and file_name != "MovingNPC.tscn":
				var path = "res://Scenes/NPCs/" + file_name
				var scene = load(path)
				if scene:
					var inst = scene.instantiate()
					if inst and inst.get_script():
						var script_path = inst.get_script().resource_path
						if "NPCStationary.gd" in script_path:
							stationary_npcs.append(scene)
						elif "NPCMoving.gd" in script_path:
							moving_npcs.append(scene)
					if inst:
						inst.queue_free()
			file_name = npc_dir.get_next()

func _setup_random_menu():
	randomize()
	
	# 1. Random Background
	if backgrounds.size() > 0:
		var random_bg = backgrounds[randi() % backgrounds.size()]
		var tex = load(random_bg)
		if tex and background_rect != null:
			background_rect.texture = tex
	
	# 2. Randomize NPCs
	stationary_npcs.shuffle()
	moving_npcs.shuffle()
	
	var screen_size = get_viewport_rect().size
	var ground_y = screen_size.y * 0.9
	if ground_y < 800:
		ground_y = 950 # Fallback for 1080p
		
	var npc_container = Node2D.new()
	npc_container.name = "NPCs"
	add_child(npc_container)
	move_child(npc_container, 1) # Behind UI
	
	# Stationary NPCs (Left and Right edges)
	if stationary_npcs.size() >= 1:
		_spawn_npc(stationary_npcs[0], Vector2(screen_size.x * 0.15, ground_y), false, npc_container)
	if stationary_npcs.size() >= 2:
		var right_npc = _spawn_npc(stationary_npcs[1], Vector2(screen_size.x * 0.85, ground_y), false, npc_container)
		if right_npc:
			_flip_npc(right_npc, false) # Face left
			
	# Moving NPCs (Middle area)
	if moving_npcs.size() >= 1:
		_spawn_npc(moving_npcs[0], Vector2(screen_size.x * 0.35, ground_y), true, npc_container)
	if moving_npcs.size() >= 2:
		_spawn_npc(moving_npcs[1], Vector2(screen_size.x * 0.65, ground_y), true, npc_container)

func _spawn_npc(scene: PackedScene, pos: Vector2, is_moving: bool, parent: Node) -> Node:
	var inst = scene.instantiate()
	parent.add_child(inst)
	inst.position = pos
	
	# Disable physics processing and standard processing
	inst.set_physics_process(false)
	inst.set_process(false)
	
	# Disable collisions and dialogue
	for child in inst.get_children():
		if child is CollisionShape2D or child is Area2D:
			child.queue_free()
	
	if inst.has_node("DialogueBox"):
		inst.get_node("DialogueBox").visible = false
		inst.get_node("DialogueBox").queue_free()
		
	if is_moving:
		# Extract speed if it exists, otherwise use default
		var speed = 80.0
		if "move_speed" in inst:
			speed = inst.move_speed
			
		var screen_w = get_viewport_rect().size.x
		var patrol_range = 300.0
		var left_b = pos.x - patrol_range
		var right_b = pos.x + patrol_range
		
		# Keep within screen bounds (roughly)
		left_b = max(left_b, screen_w * 0.2)
		right_b = min(right_b, screen_w * 0.8)
		
		active_moving_npcs.append({
			"npc": inst,
			"speed": speed,
			"moving_right": true,
			"left_bound": left_b,
			"right_bound": right_b
		})
		_flip_npc(inst, true)
		
	return inst

func _on_play_pressed():
	if has_node("/root/GameManager"):
		GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_exit_pressed():
	print("Exit button pressed")
	get_tree().quit()
