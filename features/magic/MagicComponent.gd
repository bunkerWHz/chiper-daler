extends Component
class_name MagicComponent

enum Phase { NONE, CHARGE, CAST, RECOVERY, CHANNELING }

const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal mana_changed(current: float, maximum: float)

@export var config: MagicConfig

var _input: InputComponent
var _equipment: EquipmentComponent
var _facing: FacingComponent
var _phase: Phase = Phase.NONE
var _timer: float = 0.0
var _mana: float = 0.0
var _max_mana: float = 1.0
var _attributes: CharacterAttributesComponent
var _aim: AimingComponent


func on_initialize() -> void:
	if (
		config == null
		or config.cast_duration <= 0.0
		or config.recovery_duration <= 0.0
		or config.projectile_speed <= 0.0
		or config.projectile_lifetime <= 0.0
		or config.damage < 0.0
		or config.knockback < 0.0
		or config.projectile_gravity < 0.0
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
	_attributes = (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	if _attributes != null and _attributes.is_enabled:
		if not _attributes.attributes_changed.is_connected(
			_on_attributes_changed
		):
			_attributes.attributes_changed.connect(_on_attributes_changed)
	else:
		_attributes = null
	_max_mana = _calculate_max_mana()
	_aim = actor.get_component(AimingComponent) as AimingComponent
	if _aim != null and not _aim.aim_cancelled.is_connected(_on_aim_cancelled):
		_aim.aim_cancelled.connect(_on_aim_cancelled)
	_mana = _max_mana
	mana_changed.emit(_mana, _max_mana)
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
		if (
			_input.consume_attack_pressed()
			and _aim != null and _aim.is_enabled
			and _equipment.allows_magic_cast()
			and _mana >= config.cast_mana_cost
			and not BEHAVIOR_GATE.is_blocked(actor, self)
		):
			_set_phase(Phase.CHARGE, 0.0)
		elif (
			_input.consume_guard_just_pressed()
			and _equipment.allows_magic_channel()
			and _mana > 0.0
			and not BEHAVIOR_GATE.is_blocked(actor, self)
		):
			_set_phase(Phase.CHANNELING, 0.0)
	if _phase == Phase.CHARGE:
		if _input.consume_guard_just_pressed():
			_set_phase(Phase.NONE, 0.0)
		elif _input.consume_attack_released():
			if _equipment.allows_magic_cast():
				_cast_spell()
			else:
				_set_phase(Phase.NONE, 0.0)
	elif _phase == Phase.CHANNELING:
		_set_mana(_mana - config.channel_mana_per_second * delta)
		if not _input.is_guard_pressed() or _mana == 0.0:
			_set_phase(Phase.NONE, 0.0)


func get_phase() -> Phase:
	return _phase


func is_exclusive_behavior_active() -> bool:
	return _phase != Phase.NONE


func get_mana() -> float:
	return _mana


func get_max_mana() -> float:
	return _max_mana


func restore_mana(amount: float) -> float:
	if not is_enabled or amount <= 0.0:
		return 0.0

	var previous := _mana
	_set_mana(_mana + amount)
	return _mana - previous


func capture_runtime_state() -> Variant:
	return _mana


func restore_runtime_state(state: Variant) -> void:
	_set_mana(float(state))


func disable() -> void:
	_set_phase(Phase.NONE, 0.0)
	super.disable()


func _cast_spell() -> void:
	if _aim == null or not _aim.is_aiming() or actor.get_parent() == null or _mana < config.cast_mana_cost:
		_set_phase(Phase.NONE, 0.0)
		return
	_set_mana(_mana - config.cast_mana_cost)
	var parent := actor.get_parent()
	if parent != null:
		var projectile := preload("res://features/throwing/ThrownProjectile.tscn").instantiate() as ThrownProjectile
		projectile.is_magic = true
		parent.add_child(projectile)
		projectile.global_position = _aim.get_launch_position()
		projectile.setup_direction(
			actor,
			_aim.get_direction(),
			config.projectile_speed,
			(_attributes.get_magic_attack() if _attributes != null else config.damage) + _equipment.get_active_weapon_damage(),
			config.knockback,
			config.projectile_lifetime,
			null,
			config.projectile_gravity
		)
	_set_phase(Phase.CAST, config.cast_duration / get_cast_speed_multiplier())


func get_cast_speed_multiplier() -> float:
	return _attributes.get_cast_speed_multiplier() if _attributes != null else 1.0


func _update_phase(delta: float) -> void:
	if _phase == Phase.CAST or _phase == Phase.RECOVERY:
		_timer = maxf(_timer - delta, 0.0)
		if _timer == 0.0:
			_set_phase(Phase.RECOVERY if _phase == Phase.CAST else Phase.NONE, config.recovery_duration / get_cast_speed_multiplier() if _phase == Phase.CAST else 0.0)


func _set_phase(value: Phase, duration: float) -> void:
	if value == _phase:
		_timer = duration
		return

	var previous_phase := _phase
	if _aim != null:
		if value == Phase.CHARGE:
			if not _aim.begin_aim(self):
				return
		else:
			_aim.end_aim(self)
	_phase = value
	_timer = duration
	phase_changed.emit(previous_phase, _phase)


func _on_aim_cancelled(aim_owner: Component) -> void:
	if aim_owner == self and _phase == Phase.CHARGE:
		_set_phase(Phase.NONE, 0.0)


func _set_mana(value: float) -> void:
	var resolved := clampf(value, 0.0, _max_mana)
	if is_equal_approx(resolved, _mana):
		return
	_mana = resolved
	mana_changed.emit(_mana, _max_mana)


func _calculate_max_mana() -> float:
	var wisdom_bonus := (
		_attributes.get_wisdom_mana_bonus()
		if _attributes != null
		else 0.0
	)
	return maxf(float(config.max_mana) + wisdom_bonus, 1.0)


func _on_attributes_changed(
	_strength: int,
	_dexterity: int,
	_intelligence: int,
	_endurance: int,
	_wisdom: int
) -> void:
	var previous_max := _max_mana
	_max_mana = _calculate_max_mana()
	if _max_mana > previous_max:
		_mana += _max_mana - previous_max
	_mana = clampf(_mana, 0.0, _max_mana)
	mana_changed.emit(_mana, _max_mana)


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
