extends Component
class_name ThrowingComponent

enum Phase {
	NONE,
	AIM,
	ACTION,
	RECOVERY,
}

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal throwable_released(direction: float, remaining_charges: int)

const PROJECTILE_SCENE := preload("res://features/throwing/ThrownProjectile.tscn")

@export var config: ThrowingConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _facing_component: FacingComponent
var _phase: Phase = Phase.NONE
var _phase_timer: float = 0.0
var _remaining_charges: int = 0


func on_initialize() -> void:
	if config == null:
		push_error("ThrowingComponent requires ThrowingConfig")
		disable()
		return

	if (
		config.action_duration <= 0.0
		or config.recovery_duration <= 0.0
		or config.projectile_speed <= 0.0
		or config.projectile_lifetime <= 0.0
		or config.damage < 0.0
		or config.knockback < 0.0
		or config.max_charges < 0
	):
		push_error("ThrowingComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_equipment_component = actor.get_component(EquipmentComponent) as EquipmentComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent

	if (
		_input_component == null
		or not _input_component.is_enabled
		or _equipment_component == null
		or not _equipment_component.is_enabled
		or _facing_component == null
		or not _facing_component.is_enabled
	):
		push_error(
			"ThrowingComponent requires enabled input, equipment, and facing"
		)
		disable()
		return

	_remaining_charges = config.max_charges
	if not _equipment_component.equipment_changed.is_connected(
		_on_equipment_changed
	):
		_equipment_component.equipment_changed.connect(
			_on_equipment_changed
		)


func _process(delta: float) -> void:
	_update_phase(delta)

	if not _equipment_component.is_slot_active(EquipmentComponent.Slot.THROWABLE):
		return

	if _phase == Phase.NONE and _input_component.consume_attack_pressed():
		if _remaining_charges > 0:
			_set_phase(Phase.AIM, 0.0)
	elif _phase == Phase.AIM:
		if _input_component.consume_guard_just_pressed():
			_set_phase(Phase.NONE, 0.0)
		elif _input_component.consume_attack_released():
			_release_throwable()


func get_phase() -> Phase:
	return _phase


func is_primary_action_active() -> bool:
	return _phase != Phase.NONE


func get_remaining_charges() -> int:
	return _remaining_charges


func add_charges(amount: int) -> int:
	if not is_enabled or amount <= 0:
		return 0

	var previous := _remaining_charges
	_remaining_charges = mini(_remaining_charges + amount, config.max_charges)
	return _remaining_charges - previous


func capture_runtime_state() -> Variant:
	return _remaining_charges


func restore_runtime_state(state: Variant) -> void:
	_remaining_charges = clampi(int(state), 0, config.max_charges)


func cancel_throw() -> void:
	if _phase != Phase.NONE:
		_set_phase(Phase.NONE, 0.0)


func disable() -> void:
	cancel_throw()
	super.disable()


func _release_throwable() -> void:
	_remaining_charges -= 1
	var direction := float(_facing_component.get_direction())
	var parent := actor.get_parent()

	if parent != null:
		var projectile := PROJECTILE_SCENE.instantiate() as ThrownProjectile
		parent.add_child(projectile)
		projectile.global_position = actor.global_position
		projectile.setup(
			actor,
			direction,
			config.projectile_speed,
			config.damage,
			config.knockback,
			config.projectile_lifetime
		)

	throwable_released.emit(direction, _remaining_charges)
	_set_phase(Phase.ACTION, config.action_duration)


func _update_phase(delta: float) -> void:
	if _phase == Phase.AIM or _phase == Phase.NONE:
		return

	_phase_timer = maxf(_phase_timer - delta, 0.0)

	if _phase_timer > 0.0:
		return

	if _phase == Phase.ACTION:
		_set_phase(Phase.RECOVERY, config.recovery_duration)
	elif _phase == Phase.RECOVERY:
		_set_phase(Phase.NONE, 0.0)


func _set_phase(new_phase: Phase, duration: float) -> void:
	if new_phase == _phase:
		return

	var previous_phase := _phase
	_phase = new_phase
	_phase_timer = duration
	phase_changed.emit(previous_phase, _phase)


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	current_slot: EquipmentComponent.Slot
) -> void:
	if current_slot != EquipmentComponent.Slot.THROWABLE:
		cancel_throw()
