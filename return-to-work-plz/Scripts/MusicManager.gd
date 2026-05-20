extends Node

## MusicManager — Autoload Singleton
## Handles BGM that persists across room transitions.
## Only changes the track when the room's music is DIFFERENT from what's currently playing.

var bgm_player: AudioStreamPlayer = null
var current_track_path: String = ""

# Map each room name → music file path
# Rooms sharing the same track will NOT restart the music on transition.
var room_music: Dictionary = {
	# Floor 1 — all share "lower floor.mp3"
	"Lobby": "res://Assets/Music/lower floor.mp3",
	"Elevator_F1": "res://Assets/Music/lower floor.mp3",
	"Bathroom": "res://Assets/Music/lower floor.mp3",
	
	# Floor 2 — each room has its own track
	"Elevator_F2": "res://Assets/Music/cubicle.mp3",
	"Lounge": "res://Assets/Music/lounge.mp3",
	"Cubicle_Left": "res://Assets/Music/cubicle.mp3",
	"Cubicle_Middle": "res://Assets/Music/cubicle.mp3",
	"Cubicle_Right": "res://Assets/Music/cubicle.mp3",
	"Meeting": "res://Assets/Music/printer n meeting.mp3",
	"Printer": "res://Assets/Music/printer n meeting.mp3",
	
	# Special rooms
	"Special_Castle": "res://Assets/Music/castle.mp3",
	"Special_Beach": "res://Assets/Music/beach.mp3",
	"Special_Ikea": "res://Assets/Music/ikea.mp3",
	"Special_Market": "res://Assets/Music/market.mp3",
	"Special_Spaceship": "res://Assets/Music/spaceship.mp3",
}

func _ready() -> void:
	# Create a persistent AudioStreamPlayer
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Music"
	add_child(bgm_player)
	
	# Connect to RoomManager's room_changed signal
	RoomManager.room_changed.connect(_on_room_changed)

func _on_room_changed(room_name: String) -> void:
	var target_track = room_music.get(room_name, "")
	
	if target_track == "":
		# No music defined for this room — stop playing
		bgm_player.stop()
		current_track_path = ""
		print("[MusicManager] No music for room: %s — stopped." % room_name)
		return
	
	# If the same track is already playing, do NOT restart it
	if target_track == current_track_path and bgm_player.playing:
		print("[MusicManager] Same track already playing for room: %s — keeping." % room_name)
		return
	
	# Different track → load and play
	var stream = load(target_track)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()
		current_track_path = target_track
		print("[MusicManager] Now playing: %s (room: %s)" % [target_track, room_name])
	else:
		push_error("[MusicManager] Failed to load music: %s" % target_track)

## Stop the BGM (e.g., for game over, main menu)
func stop_music() -> void:
	bgm_player.stop()
	current_track_path = ""

## Manually play a specific track (e.g., game over music)
func play_track(track_path: String) -> void:
	if track_path == current_track_path and bgm_player.playing:
		return
	var stream = load(track_path)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()
		current_track_path = track_path
