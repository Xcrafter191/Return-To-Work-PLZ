extends CanvasLayer

signal skill_check_completed(success: bool)

@onready var panel = $Panel
@onready var yellow_zone = $Panel/BarBackground/YellowZone
@onready var arrow = $Panel/BarBackground/Arrow
@onready var bar_bg = $Panel/BarBackground
@onready var result_label = $Panel/ResultLabel

@onready var success_sfx: AudioStreamPlayer2D = $SuccessSFX
@onready var fail_sfx: AudioStreamPlayer2D = $FailedSFX

var is_active: bool = false
var arrow_speed: float = 400.0
var arrow_direction: int = 1
var bar_width: float = 460.0

func _ready() -> void:
	visible = false

func start_skill_check(base_speed: float = 400.0) -> void:
	is_active = true
	visible = true
	result_label.text = "Press [SPACE]"
	
	# Yellow zone width shrinks each loop, capped at minimum 25px
	var base_width = 100.0 - (GameManager.current_loop * 5.0)
	var zone_width = clampf(base_width, 25.0, 100.0)
	var max_x = bar_width - zone_width
	var zone_x = randf_range(0, max_x)
	
	# Hacker attack hook - shrink zone even further!
	if InconvenienceManager.is_stuck_99:
		zone_width = 15.0
		arrow_speed = base_speed * randf_range(1.5, 2.5)
	else:
		arrow_speed = base_speed
	
	yellow_zone.position.x = zone_x
	yellow_zone.size.x = zone_width
	
	# Reset arrow
	arrow.position.x = 0
	arrow_direction = 1

func _process(delta: float) -> void:
	if not is_active: return
	
	# Move arrow
	arrow.position.x += arrow_speed * arrow_direction * delta
	
	# Bounce
	if arrow.position.x > bar_width - arrow.size.x:
		arrow.position.x = bar_width - arrow.size.x
		arrow_direction = -1
	elif arrow.position.x < 0:
		arrow.position.x = 0
		arrow_direction = 1
		
	# Input Check — uses Space (qte_confirm), NOT E (interact)
	if Input.is_action_just_pressed("qte_confirm"):
		_check_result()

func _check_result() -> void:
	is_active = false
	
	var arrow_center = arrow.position.x + (arrow.size.x / 2.0)
	var zone_start = yellow_zone.position.x
	var zone_end = yellow_zone.position.x + yellow_zone.size.x
	
	var success = (arrow_center >= zone_start and arrow_center <= zone_end)
	
	if success:
		result_label.text = "GOOD!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		if success_sfx:
			success_sfx.play() # Play sound success
	else:
		result_label.text = "FAILED!"
		result_label.add_theme_color_override("font_color", Color.RED)
		if fail_sfx:
			fail_sfx.play() # Play sound fail
		
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		visible = false
		skill_check_completed.emit(success)
	)
