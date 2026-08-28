extends Component
class_name MagicComponent

enum Phase { NONE, CHARGE, CAST, RECOVERY, CHANNELING }

signal phase_changed(previous_phase: Phase, current_phase: Phase)

@export var config: MagicConfig

var _input: InputComponent
var _equipment: EquipmentComponent
var _facing: FacingComponent
var _phase: Phase = Phase.NONE
var _timer: float = 0.0
var _mana: float = 0.0


func on_initialize() -> void:
	if (
		config == null
		or config.charge_time <= 0.0
		or config.cast_duration <= 0.0
		or config.recovery_duration <= 0.0
		or config.projectile_speed <= 0.0
		or config.projectile_lifetime <= 0.0
		or config.damage < 0.0
		or config.knockback < 0.0
		or config.max_mana <= 0
		or config.cast_mana_cost <= 0
		or config.cast_mana_cost > config.max_mana
		or config.channel_mana_per_second <= 0.0
	):
		push_error("MagicComponent requires a valid MagicConfig")
		disable()
		return
	_input = actor.get_component(InputComponent) as InputComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_facing = actor.get_component(FacingComponent) as FacingComponent
	if (
		_input == null
		or not _input.is_enabled
		or _equipment == null
		or not _equipment.is_enabled
		or _facing == null
		or not _facing.is_enabled
	):
		push_error(
			"MagicComponent requires enabled input, equipment, and facing"
		)
		disable()
		return
	_mana = config.max_mana
	if not _equipment.equipment_changed.is_connected(_on_equipment_changed):
		_equipment.equipment_changed.connect(_on_equipment_changed)
	if not _equipment.loadout_item_changed.is_connected(
		_on_loadout_item_changed
	):
		_equipment.loadout_item_changed.connect(_on_loadout_item_changed)
	if not _equipment.weapon_set_changed.is_connected(
		_on_weapon_set_changed
	):
		_equipment.weapon_set_changed.connect(_on_weapon_set_changed)


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


func restore_mana(amount: float) -> float:
	if not is_enabled or amount <= 0.0:
		return 0.0

	var previous := _mana
	_mana = minf(_mana + amount, config.max_mana)
	return _mana - previous


func capture_runtime_state() -> Variant:
	return _mana


func restore_runtime_state(state: Variant) -> void:
	_mana = clampf(float(state), 0.0, config.max_mana)


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
		projectile.setup(
			actor,
			float(_facing.get_direction()),
			config.projectile_speed,
			config.damage + _equipment.get_active_weapon_damage(),
			config.knockback,
			config.projectile_lifetime
		)
	_set_phase(Phase.CAST, config.cast_duration)


func _update_phase(delta: float) -> void:
	if _phase == Phase.CHARGE:
		_timer = maxf(_timer - delta, 0.0)
	elif _phase == Phase.CAST or _phase == Phase.RECOVERY:
		_timer = maxf(_timer - delta, 0.0)
		if _timer == 0.0:
			_set_phase(Phase.RECOVERY if _phase == Phase.CAST else Phase.NONE, config.recovery_duration if _phase == Phase.CAST else 0.0)


func _set_phase(value: Phase, duration: float) -> void:
	if value == _phase:
		_timer = duration
		return

	var previous_phase := _phase
	_phase = value
	_timer = duration
	phase_changed.emit(previous_phase, _phase)


func _on_equipment_changed(
	_previous: EquipmentComponent.Slot,
	current: EquipmentComponent.Slot
) -> void:
	if current != EquipmentComponent.Slot.MAGIC:
		_set_phase(Phase.NONE, 0.0)


func _on_loadout_item_changed(
	equip_slot: ItemData.EquipSlot,
	_slot_index: int,
	weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	if (
		equip_slot == ItemData.EquipSlot.MAIN_HAND
		and weapon_set == _equipment.get_active_weapon_set()
	):
		_set_phase(Phase.NONE, 0.0)


func _on_weapon_set_changed(_previous_set: int, _current_set: int) -> void:
	_set_phase(Phase.NONE, 0.0)
