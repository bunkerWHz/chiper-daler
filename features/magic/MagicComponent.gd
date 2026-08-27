extends Component
class_name MagicComponent

enum Phase { NONE, CHARGE, CAST, RECOVERY, CHANNELING }

@export var config: MagicConfig

var _input: InputComponent
var _equipment: EquipmentComponent
var _facing: FacingComponent
var _phase: Phase = Phase.NONE
var _timer: float = 0.0
var _mana: float = 0.0


func on_initialize() -> void:
	if config == null or config.charge_time <= 0.0 or config.max_mana <= 0:
		push_error("MagicComponent requires a valid MagicConfig")
		disable()
		return
	_input = actor.get_component(InputComponent) as InputComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_facing = actor.get_component(FacingComponent) as FacingComponent
	if _input == null or _equipment == null or _facing == null:
		push_error("MagicComponent requires input, equipment, and facing")
		disable()
		return
	_mana = config.max_mana
	_equipment.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	_update_phase(delta)
	if not _equipment.is_slot_active(EquipmentComponent.Slot.MAGIC):
		return
	if _phase == Phase.NONE:
		if _input.consume_attack_pressed() and _mana >= config.cast_mana_cost:
			_set_phase(Phase.CHARGE, config.charge_time)
		elif _input.consume_guard_just_pressed() and _mana > 0.0:
			_set_phase(Phase.CHANNELING, 0.0)
	elif _phase == Phase.CHARGE and _input.consume_attack_released():
		_cast_spell()
	elif _phase == Phase.CHANNELING:
		_mana = maxf(_mana - config.channel_mana_per_second * delta, 0.0)
		if not _input.is_guard_pressed() or _mana == 0.0:
			_set_phase(Phase.NONE, 0.0)


func get_phase() -> Phase:
	return _phase


func get_mana() -> float:
	return _mana


func disable() -> void:
	_set_phase(Phase.NONE, 0.0)
	super.disable()


func _cast_spell() -> void:
	_mana -= config.cast_mana_cost
	var parent := actor.get_parent()
	if parent != null:
		var projectile := preload("res://features/throwing/ThrownProjectile.tscn").instantiate() as ThrownProjectile
		parent.add_child(projectile)
		projectile.global_position = actor.global_position
		projectile.setup(actor, float(_facing.get_direction()), config.projectile_speed, config.damage, 120.0, 2.0)
	_set_phase(Phase.CAST, config.cast_duration)


func _update_phase(delta: float) -> void:
	if _phase == Phase.CHARGE:
		_timer = maxf(_timer - delta, 0.0)
	elif _phase == Phase.CAST or _phase == Phase.RECOVERY:
		_timer = maxf(_timer - delta, 0.0)
		if _timer == 0.0:
			_set_phase(Phase.RECOVERY if _phase == Phase.CAST else Phase.NONE, config.recovery_duration if _phase == Phase.CAST else 0.0)


func _set_phase(value: Phase, duration: float) -> void:
	_phase = value
	_timer = duration


func _on_equipment_changed(_previous: int, current: int) -> void:
	if current != EquipmentComponent.Slot.MAGIC:
		_set_phase(Phase.NONE, 0.0)
