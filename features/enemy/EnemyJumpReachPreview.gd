@tool
extends JumpReachPreview
class_name EnemyJumpReachPreview

const ENEMY_MOVEMENT_COMPONENT_PATH := (
	^"../_Components/EnemyMovementComponent"
)
const ENEMY_JUMP_COMPONENT_PATH := ^"../_Components/EnemyJumpComponent"

var _preview_config := MovementConfig.new()


func _get_movement_config() -> MovementConfig:
	var movement_component := get_node_or_null(
		ENEMY_MOVEMENT_COMPONENT_PATH
	)
	var jump_component := get_node_or_null(ENEMY_JUMP_COMPONENT_PATH)

	if movement_component == null or jump_component == null:
		return null

	var movement_config := (
		movement_component.get("config") as EnemyMovementConfig
	)
	var jump_config := jump_component.get("config") as EnemyJumpConfig

	if movement_config == null or jump_config == null:
		return null

	_preview_config.move_speed = movement_config.move_speed
	_preview_config.gravity = movement_config.gravity
	_preview_config.jump_velocity = jump_config.jump_velocity
	_preview_config.air_jump_velocity = jump_config.jump_velocity
	_preview_config.max_jump_count = 1
	_preview_config.acceleration_mode = MovementConfig.AccelerationMode.INSTANT
	return _preview_config
