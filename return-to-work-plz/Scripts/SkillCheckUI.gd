extends CanvasLayer

signal skill_check_completed(success: bool)

@onready var panel = $Panel
@onready var yellow_zone = $Panel/BarBackground/YellowZone
@onready var arrow = $Panel/BarBackground/Arrow
@onready var bar_bg = $Panel/BarBackground
@onready var result_label = $Panel/ResultLabel

var is_active: bool = false
var arrow_speed: float = 400.0
var arrow_direction: int = 1
var bar_width: float = 460.0

func _ready() -> void:
	visible = false

func start_skill_check(base_speed: float = 400.0) -> void:
	is_active = true
	visible = true
	result_label.text = ""
	
	# Randomize Yellow Zone (Width between 40 and 100)
	var zone_width = randf_range(40, 100)
	var max_x = bar_width - zone_width
	var zone_x = randf_range(0, max_x)
	
	# Hacker attack hook - shrink zone!
	if InconvenienceManager.is_stuck_99: # Reuse this state or a new one
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
		
	# Input Check
	if Input.is_action_just_pressed("interact"):
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
	else:
		result_label.text = "FAILED!"
		result_label.add_theme_color_override("font_color", Color.RED)
		
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		visible = false
		skill_check_completed.emit(success)
	)
