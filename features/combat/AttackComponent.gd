extends Component
class_name AttackComponent

const EQUIPMENT_COMPONENT_SCRIPT := preload(
	"res://features/equipment/EquipmentComponent.gd"
)
const LOCOMOTION_CONSTRAINT := preload(
	"res://features/movement/LocomotionConstraint.gd"
)
const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal attack_started
signal heavy_attack_started
signal attack_finished
signal landing_recovery_started
signal landing_recovery_finished

@export var config: AttackConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _hitbox_component: HitboxComponent
var _facing_component: FacingComponent
var _equipment_component: Component
var _active_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _charge_timer: float = 0.0
var _is_charging: bool = false
var _is_heavy_attack: bool = false
var _base_damage: float = 0.0
var _base_horizontal_knockback: float = 0.0
var _base_vertical_knockback: float = 0.0
var _critical_timer: float = 0.0
var _attack_started_airborne: bool = false
var _landing_recovery_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("AttackComponent requires AttackConfig")
		disable()
		return

	if (
		config.active_duration <= 0.0
		or config.cooldown <= 0.0
		or config.heavy_charge_time <= 0.0
		or config.heavy_active_duration <= 0.0
		or config.heavy_cooldown <= 0.0
		or config.landing_recovery_duration <= 0.0
		or config.heavy_damage_multiplier < 1.0
		or config.heavy_knockback_multiplier < 1.0
		or config.critical_state_duration <= 0.0
	):
		push_error("AttackComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_body_component = (
		actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	)
	_hitbox_component = actor.get_component(HitboxComponent) as HitboxComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent
	_equipment_component = (
		actor.get_component(EQUIPMENT_COMPONENT_SCRIPT) as Component
	)

	if _hitbox_component == null or not _hitbox_component.is_enabled:
		push_error("AttackComponent requires an enabled HitboxComponent")
		disable()
		return

	_base_damage = _hitbox_component.damage
	_base_horizontal_knockback = _hitbox_component.horizontal_knockback
	_base_vertical_knockback = _hitbox_component.vertical_knockback
	if not _hitbox_component.critical_hit_landed.is_connected(
		_on_critical_hit_landed
	):
		_hitbox_component.critical_hit_landed.connect(_on_critical_hit_landed)

	if _input_component != null and not _input_component.is_enabled:
		_input_component = null

	if _facing_component != null and not _facing_component.is_enabled:
		_facing_component = null

	if _equipment_component != null and not _equipment_component.is_enabled:
		_equipment_component = null
	if _equipment_component != null:
		if not _equipment_component.is_connected(
			&"equipment_changed",
			_on_equipment_changed
		):
			_equipment_component.connect(
				&"equipment_changed",
				_on_equipment_changed
			)
		if not _equipment_component.is_connected(
			&"loadout_item_changed",
			_on_loadout_item_changed
		):
			_equipment_component.connect(
				&"loadout_item_changed",
				_on_loadout_item_changed
			)
		if not _equipment_component.is_connected(
			&"weapon_set_changed",
			_on_weapon_set_changed
		):
			_equipment_component.connect(
				&"weapon_set_changed",
				_on_weapon_set_changed
			)

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
	_critical_timer = maxf(_critical_timer - delta, 0.0)
	_update_landing_recovery(delta)

	if _active_timer > 0.0:
		if _attack_started_airborne and not _is_airborne():
			_begin_landing_recovery()
		else:
			_active_timer = maxf(_active_timer - delta, 0.0)
		if _active_timer == 0.0 and not is_landing_recovery():
			_finish_attack()

	_update_attack_input(delta)


func attack() -> bool:
	return _start_attack(false, _is_airborne())


func heavy_attack() -> bool:
	return _start_attack(true, _is_airborne())


func can_attack() -> bool:
	return (
		is_enabled
		and _allows_any_attack_action()
		and _cooldown_timer <= 0.0
		and _active_timer <= 0.0
		and not is_landing_recovery()
		and not BEHAVIOR_GATE.is_blocked(actor, self)
	)


func is_attacking() -> bool:
	return _active_timer > 0.0


func is_heavy_attacking() -> bool:
	return is_attacking() and _is_heavy_attack


func is_charging_heavy_attack() -> bool:
	return _is_charging


func is_critical_attacking() -> bool:
	return _critical_timer > 0.0


func is_air_attack() -> bool:
	return (
		_attack_started_airborne
		and (is_attacking() or is_charging_heavy_attack())
	)


func is_landing_recovery() -> bool:
	return _landing_recovery_timer > 0.0


func is_exclusive_behavior_active() -> bool:
	return (
		is_attacking()
		or is_charging_heavy_attack()
		or is_critical_attacking()
		or is_landing_recovery()
	)


func get_locomotion_blocks() -> int:
	if is_landing_recovery():
		return (
			LOCOMOTION_CONSTRAINT.Block.HORIZONTAL
			| LOCOMOTION_CONSTRAINT.Block.JUMP
			| LOCOMOTION_CONSTRAINT.Block.DODGE
		)
	if not is_attacking() and not is_charging_heavy_attack():
		return LOCOMOTION_CONSTRAINT.Block.NONE
	if is_air_attack():
		return (
			LOCOMOTION_CONSTRAINT.Block.JUMP
			| LOCOMOTION_CONSTRAINT.Block.DODGE
		)
	return (
		LOCOMOTION_CONSTRAINT.Block.HORIZONTAL
		| LOCOMOTION_CONSTRAINT.Block.JUMP
		| LOCOMOTION_CONSTRAINT.Block.DODGE
	)


func set_horizontal_direction(direction: float) -> void:
	if _hitbox_component != null:
		_hitbox_component.set_horizontal_direction(direction)


func disable() -> void:
	var was_attacking := is_attacking()
	var was_recovering := is_landing_recovery()
	_active_timer = 0.0
	_charge_timer = 0.0
	_critical_timer = 0.0
	_landing_recovery_timer = 0.0
	_is_charging = false
	_attack_started_airborne = false
	_restore_hitbox_damage()

	if _hitbox_component != null:
		_hitbox_component.deactivate()

	if was_attacking:
		attack_finished.emit()
	if was_recovering:
		landing_recovery_finished.emit()

	super.disable()


func _finish_attack() -> void:
	_active_timer = 0.0
	_hitbox_component.deactivate()
	_restore_hitbox_damage()
	_attack_started_airborne = false
	attack_finished.emit()


func _update_attack_input(delta: float) -> void:
	if _input_component == null:
		return

	if not _allows_melee_actions():
		_is_charging = false
		_charge_timer = 0.0
		return

	if _input_component.consume_attack_pressed():
		if can_attack():
			_is_charging = true
			_charge_timer = 0.0
			_attack_started_airborne = _is_airborne()

	if not _is_charging:
		return

	if _input_component.is_attack_pressed():
		_charge_timer += delta

		if _charge_timer >= config.heavy_charge_time:
			_start_attack(true, _attack_started_airborne)
	elif _input_component.consume_attack_released():
		_start_attack(false, _attack_started_airborne)


func _start_attack(heavy: bool, started_airborne: bool) -> bool:
	if not can_attack() or not _allows_attack_action(heavy):
		return false

	_is_charging = false
	_charge_timer = 0.0
	_is_heavy_attack = heavy
	_attack_started_airborne = started_airborne
	_active_timer = (
		config.heavy_active_duration if heavy else config.active_duration
	)
	_cooldown_timer = config.heavy_cooldown if heavy else config.cooldown
	var equipped_damage := _get_equipped_melee_damage()
	_hitbox_component.damage = equipped_damage

	if heavy:
		_hitbox_component.damage = (
			equipped_damage * config.heavy_damage_multiplier
		)
		_hitbox_component.horizontal_knockback = (
			_base_horizontal_knockback * config.heavy_knockback_multiplier
		)
		_hitbox_component.vertical_knockback = (
			_base_vertical_knockback * config.heavy_knockback_multiplier
		)
		heavy_attack_started.emit()

	_hitbox_component.activate()
	attack_started.emit()
	return true


func _begin_landing_recovery() -> void:
	_finish_attack()
	_landing_recovery_timer = config.landing_recovery_duration
	landing_recovery_started.emit()


func _update_landing_recovery(delta: float) -> void:
	if not is_landing_recovery():
		return
	_landing_recovery_timer = maxf(_landing_recovery_timer - delta, 0.0)
	if _landing_recovery_timer == 0.0:
		landing_recovery_finished.emit()


func _is_airborne() -> bool:
	return _body_component != null and not _body_component.is_on_floor()


func _restore_hitbox_damage() -> void:
	if _hitbox_component != null:
		_hitbox_component.damage = _get_equipped_melee_damage()
		_hitbox_component.horizontal_knockback = _base_horizontal_knockback
		_hitbox_component.vertical_knockback = _base_vertical_knockback

	_is_heavy_attack = false


func _get_equipped_melee_damage() -> float:
	var result := _base_damage
	if (
		_equipment_component != null
		and _equipment_component.has_method("get_active_weapon_damage")
	):
		result += float(_equipment_component.call("get_active_weapon_damage"))
	return result


func _allows_melee_actions() -> bool:
	return (
		_equipment_component == null
		or bool(_equipment_component.call("allows_melee_actions"))
	)


func _allows_any_attack_action() -> bool:
	return _allows_attack_action(false) or _allows_attack_action(true)


func _allows_attack_action(heavy: bool) -> bool:
	if _equipment_component == null:
		return true
	var method := &"allows_heavy_attack" if heavy else &"allows_light_attack"
	return bool(_equipment_component.call(method))


func _on_equipment_changed(_previous_slot: int, _current_slot: int) -> void:
	_cancel_attack_if_melee_unavailable()


func _on_loadout_item_changed(
	_equip_slot: ItemData.EquipSlot,
	_slot_index: int,
	_weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	_cancel_attack_if_melee_unavailable()


func _on_weapon_set_changed(_previous_set: int, _current_set: int) -> void:
	_cancel_attack_if_melee_unavailable()


func _cancel_attack_if_melee_unavailable() -> void:
	var action_is_available := (
		_allows_attack_action(_is_heavy_attack)
		if is_attacking()
		else _allows_any_attack_action()
	)
	if action_is_available:
		return

	var was_attacking := is_attacking()
	var was_recovering := is_landing_recovery()
	_active_timer = 0.0
	_charge_timer = 0.0
	_landing_recovery_timer = 0.0
	_is_charging = false
	_attack_started_airborne = false
	_hitbox_component.deactivate()
	_restore_hitbox_damage()

	if was_attacking:
		attack_finished.emit()
	if was_recovering:
		landing_recovery_finished.emit()


func _on_facing_changed(
	_previous_direction: FacingComponent.Direction,
	current_direction: FacingComponent.Direction
) -> void:
	if is_enabled:
		_apply_facing(current_direction)


func _on_critical_hit_landed(
	_hurtbox: HurtboxComponent,
	_applied_damage: float
) -> void:
	_critical_timer = config.critical_state_duration


func _apply_facing(direction: FacingComponent.Direction) -> void:
	_hitbox_component.set_horizontal_direction(float(direction))
