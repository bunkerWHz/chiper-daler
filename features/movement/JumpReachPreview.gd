@tool
extends Node2D
class_name JumpReachPreview

const TRAJECTORY_CALCULATOR := preload(
	"res://features/movement/JumpTrajectoryCalculator.gd"
)

@export var show_preview: bool = true
@export var show_standing_jump: bool = true
@export var movement_component_path: NodePath = (
	^"../_Components/MovementComponent"
)
@export_range(30.0, 240.0, 1.0) var preview_physics_fps: float = 60.0
@export_range(0.5, 5.0, 0.1) var max_preview_time: float = 2.0
@export_range(1.0, 8.0, 0.5) var line_width: float = 2.5
@export var running_jump_color: Color = Color(0.2, 1.0, 0.35, 0.9)
@export var standing_jump_color: Color = Color(0.2, 0.8, 1.0, 0.8)
@export var guide_color: Color = Color(1.0, 0.85, 0.2, 0.75)


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)
		return

	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_preview:
		return

	var config := _get_movement_config()

	if config == null:
		return

	var resolved_running_color := _resolve_color(
		&"running_jump_color",
		Color(0.2, 1.0, 0.35, 0.9)
	)
	var resolved_standing_color := _resolve_color(
		&"standing_jump_color",
		Color(0.2, 0.8, 1.0, 0.8)
	)

	var running_right := TRAJECTORY_CALCULATOR.sample_jump(
		config,
		1.0,
		true,
		preview_physics_fps,
		max_preview_time
	)
	var standing_right := TRAJECTORY_CALCULATOR.sample_jump(
		config,
		1.0,
		false,
		preview_physics_fps,
		max_preview_time
	)
	var double_right := PackedVector2Array()

	if config.max_jump_count >= 2:
		double_right = TRAJECTORY_CALCULATOR.sample_double_jump(
			config,
			1.0,
			true,
			preview_physics_fps,
			maxf(max_preview_time, 3.0)
		)

	_draw_symmetric_trajectory(running_right, resolved_running_color, false)

	if not double_right.is_empty():
		_draw_symmetric_trajectory(
			double_right,
			Color(0.75, 0.35, 1.0, 0.9),
			false
		)

	if show_standing_jump:
		_draw_symmetric_trajectory(
			standing_right,
			resolved_standing_color,
			true
		)

	_draw_measurements(running_right, standing_right, double_right)


func _get_movement_config() -> MovementConfig:
	var movement := get_node_or_null(movement_component_path)

	if movement == null:
		return null

	return movement.get("config") as MovementConfig


func _resolve_color(property_name: StringName, fallback: Color) -> Color:
	var value: Variant = get(property_name)
	return value if value is Color else fallback


func _draw_symmetric_trajectory(
	right_points: PackedVector2Array,
	color: Color,
	dashed: bool
) -> void:
	_draw_trajectory(right_points, color, dashed)

	var left_points := PackedVector2Array()

	for point: Vector2 in right_points:
		left_points.append(Vector2(-point.x, point.y))

	_draw_trajectory(left_points, color, dashed)


func _draw_trajectory(
	points: PackedVector2Array,
	color: Color,
	dashed: bool
) -> void:
	if points.size() < 2:
		return

	if not dashed:
		draw_polyline(points, color, line_width, true)
		return

	for index in range(points.size() - 1):
		if index % 2 == 0:
			draw_line(points[index], points[index + 1], color, line_width, true)


func _draw_measurements(
	running_points: PackedVector2Array,
	standing_points: PackedVector2Array,
	double_points: PackedVector2Array
) -> void:
	var resolved_guide_color := _resolve_color(
		&"guide_color",
		Color(1.0, 0.85, 0.2, 0.75)
	)
	var resolved_running_color := _resolve_color(
		&"running_jump_color",
		Color(0.2, 1.0, 0.35, 0.9)
	)
	var resolved_standing_color := _resolve_color(
		&"standing_jump_color",
		Color(0.2, 0.8, 1.0, 0.8)
	)
	var apex: Vector2 = TRAJECTORY_CALCULATOR.get_apex(running_points)
	var running_landing: Vector2 = (
		TRAJECTORY_CALCULATOR.get_landing_point(running_points)
	)
	var standing_landing: Vector2 = (
		TRAJECTORY_CALCULATOR.get_landing_point(standing_points)
	)
	var double_landing := Vector2.ZERO
	var horizontal_guide_landing := running_landing

	if not double_points.is_empty():
		var double_apex := TRAJECTORY_CALCULATOR.get_apex(double_points)
		double_landing = TRAJECTORY_CALCULATOR.get_landing_point(double_points)
		horizontal_guide_landing = double_landing

		if double_apex.y < apex.y:
			apex = double_apex

	draw_dashed_line(
		Vector2(0.0, apex.y),
		Vector2.ZERO,
		resolved_guide_color,
		1.5,
		4.0
	)
	draw_line(
		Vector2(-horizontal_guide_landing.x, 0.0),
		Vector2(horizontal_guide_landing.x, 0.0),
		Color(resolved_guide_color, 0.35),
		1.0
	)
	draw_circle(running_landing, 4.0, resolved_running_color)
	draw_circle(Vector2(-running_landing.x, 0.0), 4.0, resolved_running_color)

	if not double_points.is_empty():
		draw_circle(double_landing, 4.0, Color(0.75, 0.35, 1.0, 0.9))
		draw_circle(
			Vector2(-double_landing.x, 0.0),
			4.0,
			Color(0.75, 0.35, 1.0, 0.9)
		)

	if show_standing_jump:
		draw_circle(standing_landing, 3.0, resolved_standing_color)
		draw_circle(
			Vector2(-standing_landing.x, 0.0),
			3.0,
			resolved_standing_color
		)

	var font := ThemeDB.fallback_font
	var label := "H %.0f | REACH %.0f px" % [
		absf(apex.y),
		absf(running_landing.x),
	]

	if show_standing_jump:
		label = "H %.0f | RUN %.0f | STAND %.0f px" % [
			absf(apex.y),
			absf(running_landing.x),
			absf(standing_landing.x),
		]

	if not double_points.is_empty():
		label += " | DOUBLE %.0f px" % absf(double_landing.x)

	draw_string(
		font,
		Vector2(8.0, apex.y - 8.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		resolved_guide_color
	)
