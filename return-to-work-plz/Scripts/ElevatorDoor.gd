extends Node2D

@export var target_slot: String = "Slot_Elevator_F2"
@export var target_spawn: String = "SpawnDefault"
@onready var elevator_sfx: AudioStreamPlayer2D = $ElevatorSFX

var player_in_range: bool = false
var current_player: CharacterBody2D = null # Tambahkan variabel untuk simpan referensi player
var is_teleporting: bool = false          # Kunci biar gak bisa dispam

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	# Cek tombol interact, player ada, dan tidak sedang teleportasi
	if event.is_action_pressed("interact") and player_in_range and not is_teleporting:
		if current_player:
			is_teleporting = true
			prompt_label.visible = false
			
			# KUNCI PLAYER (Panggil fungsi lock di player lo)
			if current_player.has_method("set_movement_locked"):
				current_player.set_movement_locked(true)
			
			if elevator_sfx:
				elevator_sfx.play()
				await elevator_sfx.finished
			
			# Buka kunci sebelum pindah (opsional, tapi biar aman)
			current_player.set_movement_locked(false)
			RoomManager.change_room(target_slot, target_spawn)
			is_teleporting = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		current_player = body # Simpan siapa playernya
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		current_player = null
		prompt_label.visible = false
