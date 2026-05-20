extends Node

var click_player: AudioStreamPlayer
var hover_player: AudioStreamPlayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep playing when paused
	
	click_player = AudioStreamPlayer.new()
	click_player.stream = preload("res://Assets/Audio/SFX/UI_click.mp3")
	click_player.bus = "SFX"
	add_child(click_player)
	
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = preload("res://Assets/Audio/SFX/UI_hover.mp3")
	hover_player.bus = "SFX"
	add_child(hover_player)

func play_click():
	click_player.play()

func play_hover():
	hover_player.play()
