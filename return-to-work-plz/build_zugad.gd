extends SceneTree

func _init():
	var scene = PackedScene.new()
	var root = preload("res://Scenes/NPCs/StationaryNPC.tscn").instantiate()
	root.name = "Zugad"
	root.set("npc_name", "Wizard Zugad")
	root.set("dialogue_text", "YOU SHALL NOT PASS!")
	
	var anim_sprite = root.get_node("AnimSprite")
	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 12.0)
	
	# Load idle frames
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
	
	# Hide basic sprite
	root.get_node("Sprite").visible = false
	
	scene.pack(root)
	ResourceSaver.save(scene, "res://Scenes/NPCs/Zugad.tscn")
	print("Saved Zugad.tscn")
	quit()
