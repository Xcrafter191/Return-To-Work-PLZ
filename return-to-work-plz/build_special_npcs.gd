extends SceneTree

func _init():
	_build_zugad()
	_build_gukesh()
	_build_nadia()
	_build_derek()
	_build_aliensol()
	print("Finished generating all special NPCs")
	quit()

func _build_zugad():
	var scene = PackedScene.new()
	var root = preload("res://Scenes/NPCs/StationaryNPC.tscn").instantiate()
	root.name = "Zugad"
	root.set("npc_name", "Wizard Zugad")
	root.set("dialogue_text", "YOU SHALL NOT PASS!")
	
	var anim_sprite = root.get_node("AnimSprite")
	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	
	var idle_path = "res://Assets/Sprites/Sprites_Animation/Zugad/idle/"
	var dir = DirAccess.open(idle_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var paths = []
		while file_name != "":
			if file_name.ends_with(".png") or file_name.ends_with(".png.import"):
				var actual = file_name.replace(".import", "")
				if not paths.has(actual):
					paths.append(actual)
			file_name = dir.get_next()
		paths.sort()
		for p in paths:
			var tex = load(idle_path + p)
			frames.add_frame("idle", tex)
			
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "idle"
	root.get_node("Sprite").visible = false
	
	scene.pack(root)
	ResourceSaver.save(scene, "res://Scenes/NPCs/Zugad.tscn")

func _build_stationary(name: String, npc_name: String, dialogue: String, tex_path: String):
	var scene = PackedScene.new()
	var root = preload("res://Scenes/NPCs/StationaryNPC.tscn").instantiate()
	root.name = name
	root.set("npc_name", npc_name)
	root.set("dialogue_text", dialogue)
	root.set("sprite_texture", load(tex_path))
	
	scene.pack(root)
	ResourceSaver.save(scene, "res://Scenes/NPCs/" + name + ".tscn")

func _build_moving(name: String, npc_name: String, dialogue: String, tex_path: String):
	var scene = PackedScene.new()
	var root = preload("res://Scenes/NPCs/MovingNPC.tscn").instantiate()
	root.name = name
	root.set("npc_name", npc_name)
	root.set("dialogue_text", dialogue)
	root.set("sprite_texture", load(tex_path))
	
	scene.pack(root)
	ResourceSaver.save(scene, "res://Scenes/NPCs/" + name + ".tscn")

func _build_gukesh():
	_build_stationary("Gukesh", "Vendor Gukesh", "2 bottles for 100 rupee!", "res://Assets/Sprites/Vendor Gukesh.png")

func _build_nadia():
	_build_stationary("Nadia", "Customer Nadia", "These chairs look great.", "res://Assets/Sprites/Customer Nadia.png")

func _build_derek():
	_build_moving("Derek", "Lifeguard Derek", "No drowning during peak hours.", "res://Assets/Sprites/Lifeguard Derek.png")

func _build_aliensol():
	_build_stationary("AlienSol", "Alien Sol", "⩌∫⍎ⲰⴺⰏ≘◠ⷘⳜ⚳⚟⥟ⱗ℣⍎ⶃ???", "res://Assets/Sprites/Alien Sol.png")
