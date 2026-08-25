extends Component
class_name AttackComponent

signal attack_started
signal attack_finished

@export var config: AttackConfig

var _input_component: InputComponent
var _hitbox_component: HitboxComponent
var _facing_component: FacingComponent
var _active_timer: float = 0.0
var _cooldown_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("AttackComponent requires AttackConfig")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_hitbox_component = actor.get_component(HitboxComponent) as HitboxComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent

	if _hitbox_component == null or not _hitbox_component.is_enabled:
		push_error("AttackComponent requires an enabled HitboxComponent")
		disable()
		return

	if _input_component != null and not _input_component.is_enabled:
		_input_component = null

	if _facing_component != null and not _facing_component.is_enabled:
		_facing_component = null

	if (
		_facing_component != null
		and not _facing_component.facing_changed.is_connected(_on_facing_changed)
	):
		_facing_component.facing_changed.connect(_on_facing_changed)


func _ready() -> void:
	if not is_enabled:
		return

	if _facing_component != null:
		_apply_facing(_facing_component.get_direction())

	_hitbox_component.deactivate()


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if _active_timer > 0.0:
		_active_timer = maxf(_active_timer - delta, 0.0)

		if _active_timer == 0.0:
			_finish_attack()

	if _input_component != null and _input_component.consume_attack_pressed():
		attack()


func attack() -> bool:
	if not is_enabled or _cooldown_timer > 0.0 or _active_timer > 0.0:
		return false

	_active_timer = config.active_duration
	_cooldown_timer = config.cooldown
	_hitbox_component.activate()
	attack_started.emit()
	return true


func is_attacking() -> bool:
	return _active_timer > 0.0


func _finish_attack() -> void:
	_hitbox_component.deactivate()
	attack_finished.emit()


func _on_facing_changed(
	_previous_direction: FacingComponent.Direction,
	current_direction: FacingComponent.Direction
) -> void:
	if is_enabled:
		_apply_facing(current_direction)


func _apply_facing(direction: FacingComponent.Direction) -> void:
	_hitbox_component.set_horizontal_direction(float(direction))
