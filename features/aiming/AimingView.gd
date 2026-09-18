extends Node2D

@export var radius: float = 65.0
@export var arrow_length: float = 32.0
@export var color: Color = Color(0.95, 0.93, 0.85, 0.85)
var _aim: AimingComponent


func _ready() -> void:
	# Follow the final animated grip after the player's pose update.
	process_priority = 3
	_aim = get_parent() as AimingComponent
	_aim.aim_ended.connect(_hide_indicator)
	visible = false
	z_index = 10
	# The indicator is measured in world units, independently of Actor scaling.
	top_level = true


func _process(_delta: float) -> void:
	visible = _aim.is_indicator_visible()
	if visible:
		global_position = _aim.get_launch_position()
		queue_redraw()


func _hide_indicator() -> void:
	visible = false


func _draw() -> void:
	if not visible:
		return
	var direction := _aim.get_direction()
	var angle := direction.angle()
	draw_arc(Vector2.ZERO, radius, angle - 0.3, angle + 0.3, 24,
		Color(color, color.a * 0.4), 1.0, true)
	var start := direction * radius
	var tip := direction * (radius + arrow_length)
	var side := direction.orthogonal() * 5.0
	draw_line(start, tip, color, 1.5, true)
	draw_line(tip, tip - direction * 8.0 + side, color, 1.5, true)
	draw_line(tip, tip - direction * 8.0 - side, color, 1.5, true)
