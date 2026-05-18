extends SceneTree

func _init():
	var dir = DirAccess.open("res://Scenes/Rooms/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				print("Processing ", file_name)
				var scene = load("res://Scenes/Rooms/" + file_name)
				var root = scene.instantiate()
				
				_ensure_node(root, "WallLeft", "StaticBody2D", Vector2(-20, 524), true)
				_ensure_node(root, "WallRight", "StaticBody2D", Vector2(1940, 524), true)
				
				_ensure_node(root, "ExitLeft", "Area2D", Vector2(10, 780), false, -1)
				_ensure_node(root, "ExitRight", "Area2D", Vector2(1910, 780), false, 1)
				
				_ensure_node(root, "ExitVisual_Left", "ColorRect", Vector2(0, 630), false, 0, Vector2(30, 300))
				_ensure_node(root, "ExitVisual_Right", "ColorRect", Vector2(1890, 630), false, 0, Vector2(30, 300))
				
				_ensure_node(root, "ExitLabel_Left", "Label", Vector2(10, 760), false, 0, Vector2(110, 30), "<- Exit")
				_ensure_node(root, "ExitLabel_Right", "Label", Vector2(1800, 760), false, 0, Vector2(110, 30), "Exit ->")
				
				_ensure_node(root, "SpawnLeft", "Marker2D", Vector2(250, 925), false)
				_ensure_node(root, "SpawnRight", "Marker2D", Vector2(1670, 925), false)
				
				var packed = PackedScene.new()
				packed.pack(root)
				ResourceSaver.save(packed, "res://Scenes/Rooms/" + file_name)
				root.queue_free()
			file_name = dir.get_next()
	print("Injection complete.")
	quit()

func _ensure_node(root: Node, node_name: String, node_type: String, pos: Vector2, is_wall: bool, exit_dir: int = 0, size: Vector2 = Vector2.ZERO, text: String = ""):
	if not root.has_node(node_name):
		var new_node
		if node_type == "StaticBody2D":
			new_node = StaticBody2D.new()
			new_node.collision_layer = 2
			new_node.collision_mask = 0
			var cs = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(40, 1000)
			cs.shape = shape
			new_node.add_child(cs)
			cs.owner = root
		elif node_type == "Area2D":
			new_node = Area2D.new()
			new_node.collision_layer = 0
			var script = load("res://Scripts/RoomExit.gd")
			if script:
				new_node.set_script(script)
				new_node.set("exit_direction", exit_dir)
			var cs = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(40, 300)
			cs.shape = shape
			new_node.add_child(cs)
			cs.owner = root
		elif node_type == "ColorRect":
			new_node = ColorRect.new()
			new_node.color = Color(0.3, 0.3, 0.5, 0.4)
			new_node.size = size
		elif node_type == "Label":
			new_node = Label.new()
			new_node.text = text
			new_node.size = size
		elif node_type == "Marker2D":
			new_node = Marker2D.new()
			
		new_node.name = node_name
		if new_node is Node2D or new_node is Control:
			new_node.position = pos
		root.add_child(new_node)
		new_node.owner = root
