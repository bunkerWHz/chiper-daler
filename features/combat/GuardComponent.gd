extends DamageModifierComponent
class_name GuardComponent

signal guard_started
signal guard_finished
signal damage_blocked(hit: HitData, prevented_damage: float)

@export var config: GuardConfig

var _input_component: InputComponent
var _facing_component: FacingComponent
var _attack_component: AttackComponent
var _is_guarding: bool = false


func on_initialize() -> void:
	if config == null:
		push_error("GuardComponent requires GuardConfig")
		disable()
		return

	if config.damage_multiplier < 0.0 or config.damage_multiplier > 1.0:
		push_error("GuardComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent
	_attack_component = actor.get_component(AttackComponent) as AttackComponent

	if _input_component == null or not _input_component.is_enabled:
		push_error("GuardComponent requires an enabled InputComponent")
		disable()
		return

	if _facing_component == null or not _facing_component.is_enabled:
		push_error("GuardComponent requires an enabled FacingComponent")
		disable()
		return

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and not _attack_component.attack_started.is_connected(_on_attack_started)
	):
		_attack_component.attack_started.connect(_on_attack_started)


func _process(_delta: float) -> void:
	var attack_in_progress := (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.is_attacking()
	)

	if _input_component.is_guard_pressed() and not attack_in_progress:
		start_guard()
	else:
		stop_guard()


func modify_damage(hit: HitData, damage: float) -> float:
	if not _is_guarding or not _is_hit_from_front(hit):
		return damage

	var modified_damage := damage * config.damage_multiplier
	var prevented_damage := damage - modified_damage
	damage_blocked.emit(hit, prevented_damage)
	return modified_damage


func start_guard() -> bool:
	if not is_enabled or _is_guarding:
		return false

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.is_attacking()
	):
		return false

	_is_guarding = true
	guard_started.emit()
	return true


func stop_guard() -> void:
	if not _is_guarding:
		return

	_is_guarding = false
	guard_finished.emit()


func is_guarding() -> bool:
	return _is_guarding


func disable() -> void:
	stop_guard()
	super.disable()


func _is_hit_from_front(hit: HitData) -> bool:
	if hit == null or not is_instance_valid(hit.source_actor):
		return false

	var source_direction := signf(
		hit.source_actor.global_position.x - actor.global_position.x
	)

	if is_zero_approx(source_direction):
		return true

	return source_direction == float(_facing_component.get_direction())


func _on_attack_started() -> void:
	stop_guard()
