extends Component
class_name EnemyAttackComponent

signal windup_started(target: Actor)
signal windup_cancelled
signal windup_finished

const COMBAT_TARGETING := preload("res://features/combat/CombatTargeting.gd")

@export var config: EnemyAttackConfig
@export var visual_path: NodePath = ^"_Visual"

var _attack_component: AttackComponent
var _movement_component: EnemyMovementComponent
var _detection_area: Area2D
var _targets: Array[HurtboxComponent] = []
var _stored_move_direction: float = 0.0
var _movement_stopped: bool = false
var _visual: CanvasItem
var _original_modulate: Color = Color.WHITE
var _windup_target: HurtboxComponent
var _windup_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("EnemyAttackComponent requires EnemyAttackConfig")
		disable()
		return

	if config.attack_range <= 0.0 or config.windup_duration < 0.0:
		push_error("EnemyAttackComponent has an invalid config")
		disable()
		return

	_attack_component = actor.get_component(AttackComponent) as AttackComponent

	if _attack_component == null or not _attack_component.is_enabled:
		push_error("EnemyAttackComponent requires an enabled AttackComponent")
		disable()
		return

	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)


func _ready() -> void:
	_detection_area = get_node_or_null("DetectionArea2D") as Area2D

	if _detection_area == null:
		push_error("EnemyAttackComponent requires DetectionArea2D")
		disable()
		return

	var collision_shape := (
		_detection_area.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		push_error("EnemyAttackComponent requires a RectangleShape2D")
		disable()
		return

	_visual = actor.get_node_or_null(visual_path) as CanvasItem

	if _visual == null:
		push_error("EnemyAttackComponent requires a CanvasItem visual")
		disable()
		return

	_original_modulate = _visual.modulate

	var rectangle := collision_shape.shape as RectangleShape2D
	rectangle.size = Vector2.ONE * config.attack_range * 2.0

	if not _detection_area.area_entered.is_connected(_on_area_entered):
		_detection_area.area_entered.connect(_on_area_entered)

	if not _detection_area.area_exited.is_connected(_on_area_exited):
		_detection_area.area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_remove_invalid_targets()

	if _targets.is_empty():
		_cancel_windup()
		_resume_movement()
		return

	var target := COMBAT_TARGETING.get_closest_hostile(actor, _targets)

	if target == null:
		_cancel_windup()
		_resume_movement()
		return

	_stop_movement()
	_face_target(target)

	if _attack_component.is_attacking() or not _attack_component.can_attack():
		_cancel_windup()
		return

	if _windup_target != target:
		_start_windup(target)

	_windup_timer = maxf(_windup_timer - delta, 0.0)

	if _windup_timer == 0.0:
		_finish_windup()


func has_target() -> bool:
	return not _targets.is_empty()


func enable() -> void:
	super.enable()
	_refresh_targets()


func disable() -> void:
	_targets.clear()
	_cancel_windup()
	_resume_movement()
	# Keep the sensor active so overlapping targets can be reacquired on enable.
	is_enabled = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_INHERIT


func _on_area_entered(other_area: Area2D) -> void:
	if not is_enabled:
		return

	var hurtbox := other_area.get_parent() as HurtboxComponent

	if not _is_valid_target(hurtbox) or _targets.has(hurtbox):
		return

	_targets.append(hurtbox)


func _on_area_exited(other_area: Area2D) -> void:
	var hurtbox := other_area.get_parent() as HurtboxComponent

	if hurtbox != null:
		_targets.erase(hurtbox)

	if _targets.is_empty():
		_cancel_windup()
		_resume_movement()


func _remove_invalid_targets() -> void:
	for index in range(_targets.size() - 1, -1, -1):
		if not _is_valid_target(_targets[index]):
			_targets.remove_at(index)


func _refresh_targets() -> void:
	_targets.clear()

	if _detection_area == null or not is_instance_valid(_detection_area):
		return

	for area: Area2D in _detection_area.get_overlapping_areas():
		_on_area_entered(area)


func _face_target(target: HurtboxComponent) -> void:
	var direction := signf(
		target.actor.global_position.x - actor.global_position.x
	)

	if not is_zero_approx(direction):
		_attack_component.set_horizontal_direction(direction)


func _start_windup(target: HurtboxComponent) -> void:
	_cancel_windup()
	_windup_target = target
	_windup_timer = config.windup_duration

	if _visual != null:
		_visual.modulate = config.telegraph_modulate

	windup_started.emit(target.actor)


func _cancel_windup() -> void:
	if _windup_target == null:
		return

	_windup_target = null
	_windup_timer = 0.0

	if _visual != null:
		_visual.modulate = _original_modulate

	windup_cancelled.emit()


func _finish_windup() -> void:
	var target := _windup_target
	_windup_target = null
	_windup_timer = 0.0

	if _visual != null:
		_visual.modulate = _original_modulate

	if _is_valid_target(target) and _attack_component.attack():
		windup_finished.emit()


func _is_valid_target(hurtbox: HurtboxComponent) -> bool:
	return COMBAT_TARGETING.is_valid_hostile(actor, hurtbox)


func _stop_movement() -> void:
	if (
		_movement_stopped
		or not config.stop_movement_in_range
		or _movement_component == null
		or not _movement_component.is_enabled
	):
		return

	_stored_move_direction = _movement_component.get_move_direction()
	_movement_component.stop()
	_movement_stopped = true


func _resume_movement() -> void:
	if not _movement_stopped:
		return

	if _movement_component == null or not is_instance_valid(_movement_component):
		_movement_stopped = false
		return

	if not _movement_component.is_enabled:
		return

	_movement_component.set_move_direction(_stored_move_direction)
	_movement_stopped = false
