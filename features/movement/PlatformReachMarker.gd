@tool
extends Node2D
class_name PlatformReachMarker

enum JumpProfile {
	PLAYER,
	ENEMY,
}

const TRAJECTORY_CALCULATOR := preload(
	"res://features/movement/JumpTrajectoryCalculator.gd"
)

@export var source_actor_path: NodePath
@export var jump_profile: JumpProfile = JumpProfile.PLAYER
@export var show_preview: bool = true
@export_range(1.0, 8.0, 0.5) var line_width: float = 2.5
@export var label_offset: Vector2 = Vector2(10.0, -8.0)
@export var reachable_color: Color = Color(0.2, 1.0, 0.35, 0.9)
@export var unreachable_color: Color = Color(1.0, 0.2, 0.2, 0.9)


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

	var source_actor := get_node_or_null(source_actor_path) as Node2D

	if source_actor == null:
		_draw_status("NO SOURCE", false, Vector2(-60.0, 0.0), 0.0, 0.0)
		return

	var jump_values := _get_jump_values(source_actor)

	if jump_values.is_empty():
		_draw_status(
			"NO CONFIG",
			false,
			to_local(source_actor.global_position),
			0.0,
			0.0
		)
		return

	var offset := global_position - source_actor.global_position
	var horizontal_reach: float = (
		TRAJECTORY_CALCULATOR.get_horizontal_reach_at_height(
			jump_values[0],
			jump_values[1],
			jump_values[2],
			offset.y
		)
	)
	var reachable := (
		TRAJECTORY_CALCULATOR.can_reach_height(
			jump_values[1],
			jump_values[2],
			offset.y
		)
		and absf(offset.x) <= horizontal_reach + jump_values[3]
	)
	var profile_name := (
		"PLAYER" if jump_profile == JumpProfile.PLAYER else "ENEMY"
	)

	_draw_status(
		profile_name,
		reachable,
		to_local(source_actor.global_position),
		absf(offset.x),
		horizontal_reach
	)


func _get_jump_values(source_actor: Node2D) -> PackedFloat32Array:
	var components := source_actor.get_node_or_null("_Components")

	if components == null:
		return PackedFloat32Array()

	if jump_profile == JumpProfile.PLAYER:
		var movement := components.get_node_or_null("MovementComponent")
		var config := (
			movement.get("config") as MovementConfig
			if movement != null
			else null
		)

		if config == null:
			return PackedFloat32Array()

		return PackedFloat32Array([
			config.move_speed,
			config.gravity,
			config.jump_velocity,
			0.0,
		])

	var enemy_movement := components.get_node_or_null("EnemyMovementComponent")
	var enemy_jump := components.get_node_or_null("EnemyJumpComponent")
	var movement_config := (
		enemy_movement.get("config") as EnemyMovementConfig
		if enemy_movement != null
		else null
	)
	var jump_config := (
		enemy_jump.get("config") as EnemyJumpConfig
		if enemy_jump != null
		else null
	)

	if movement_config == null or jump_config == null:
		return PackedFloat32Array()

	return PackedFloat32Array([
		movement_config.move_speed,
		movement_config.gravity,
		jump_config.jump_velocity,
		jump_config.landing_tolerance,
	])


func _draw_status(
	profile_name: String,
	reachable: bool,
	source_position: Vector2,
	distance: float,
	horizontal_reach: float
) -> void:
	var color := reachable_color if reachable else unreachable_color
	draw_dashed_line(source_position, Vector2.ZERO, color, line_width, 8.0)
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_circle(Vector2.ZERO, 3.0, Color(0.08, 0.08, 0.08, 1.0))

	var status := "OK" if reachable else "NO"
	var label := "%s %s %.0f/%.0f px" % [
		profile_name,
		status,
		distance,
		horizontal_reach,
	]
	var configured_offset: Variant = get("label_offset")
	var resolved_label_offset := Vector2(10.0, -8.0)

	if configured_offset is Vector2:
		resolved_label_offset = configured_offset

	draw_string(
		ThemeDB.fallback_font,
		resolved_label_offset,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		color
	)
