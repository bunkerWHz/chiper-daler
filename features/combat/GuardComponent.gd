extends DamageModifierComponent
class_name GuardComponent

const EQUIPMENT_COMPONENT_SCRIPT := preload(
	"res://features/equipment/EquipmentComponent.gd"
)
const LOCOMOTION_CONSTRAINT := preload(
	"res://features/movement/LocomotionConstraint.gd"
)
const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal guard_started
signal guard_finished
signal parry_started
signal parry_finished
signal attack_parried(hit: HitData)
signal damage_blocked(hit: HitData, prevented_damage: float)

@export var config: GuardConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _facing_component: FacingComponent
var _attack_component: AttackComponent
var _equipment_component: Component
var _is_guarding: bool = false
var _parry_timer: float = 0.0
var _parry_cooldown_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("GuardComponent requires GuardConfig")
		disable()
		return

	if (
		config.damage_multiplier < 0.0
		or config.damage_multiplier > 1.0
		or config.parry_window <= 0.0
		or config.parry_cooldown <= 0.0
	):
		push_error("GuardComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_body_component = (
		actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	)
	_facing_component = actor.get_component(FacingComponent) as FacingComponent
	_attack_component = actor.get_component(AttackComponent) as AttackComponent
	_equipment_component = (
		actor.get_component(EQUIPMENT_COMPONENT_SCRIPT) as Component
	)

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


func _process(delta: float) -> void:
	_parry_cooldown_timer = maxf(_parry_cooldown_timer - delta, 0.0)

	if _parry_timer > 0.0:
		_parry_timer = maxf(_parry_timer - delta, 0.0)

		if _parry_timer == 0.0:
			parry_finished.emit()

	if not _allows_guard():
		stop_guard()
	if not _allows_parry():
		_finish_parry()
	if not _allows_guard() and not _allows_parry():
		return
	if not _is_grounded():
		stop_guard()
		_finish_parry()
		return

	var attack_in_progress := (
		_attack_component != null
		and _attack_component.is_enabled
		and (
			_attack_component.is_attacking()
			or _attack_component.is_charging_heavy_attack()
		)
	)

	if (
		_input_component.consume_guard_just_pressed()
		and not attack_in_progress
	):
		start_parry()

	if is_parrying():
		stop_guard()
	elif _input_component.is_guard_pressed() and not attack_in_progress:
		start_guard()
	else:
		stop_guard()


func modify_damage(hit: HitData, damage: float) -> float:
	if not _is_hit_from_front(hit):
		return damage

	if is_parrying():
		_finish_parry()
		attack_parried.emit(hit)
		return 0.0

	if not _is_guarding:
		return damage

	var modified_damage := damage * config.damage_multiplier
	var prevented_damage := damage - modified_damage
	damage_blocked.emit(hit, prevented_damage)
	return modified_damage


func allows_hit_reactions(hit: HitData) -> bool:
	return not (
		(is_parrying() or (config.block_hit_reactions and _is_guarding))
		and _is_hit_from_front(hit)
	)


func start_parry() -> bool:
	if (
		not is_enabled
		or not _allows_parry()
		or not _can_enter_defense()
		or is_parrying()
		or _parry_cooldown_timer > 0.0
		or BEHAVIOR_GATE.is_blocked(actor, self)
	):
		return false

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and (
			_attack_component.is_attacking()
			or _attack_component.is_charging_heavy_attack()
		)
	):
		return false

	stop_guard()
	_parry_timer = config.parry_window
	_parry_cooldown_timer = config.parry_cooldown
	parry_started.emit()
	return true


func start_guard() -> bool:
	if (
		not is_enabled
		or not _allows_guard()
		or not _can_enter_defense()
		or _is_guarding
		or is_parrying()
		or BEHAVIOR_GATE.is_blocked(actor, self)
	):
		return false

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and (
			_attack_component.is_attacking()
			or _attack_component.is_charging_heavy_attack()
		)
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


func is_parrying() -> bool:
	return _parry_timer > 0.0


func is_defending() -> bool:
	return is_guarding() or is_parrying()


func is_exclusive_behavior_active() -> bool:
	return is_defending()


func get_locomotion_blocks() -> int:
	if not is_defending():
		return LOCOMOTION_CONSTRAINT.Block.NONE
	return (
		LOCOMOTION_CONSTRAINT.Block.HORIZONTAL
		| LOCOMOTION_CONSTRAINT.Block.JUMP
		| LOCOMOTION_CONSTRAINT.Block.DODGE
	)


func disable() -> void:
	stop_guard()
	_finish_parry()
	super.disable()


func _finish_parry() -> void:
	if not is_parrying():
		return

	_parry_timer = 0.0
	parry_finished.emit()


func _is_hit_from_front(hit: HitData) -> bool:
	if hit == null or not is_instance_valid(hit.source_actor):
		return false

	var source_direction := signf(
		hit.source_actor.global_position.x - actor.global_position.x
	)

	if is_zero_approx(source_direction):
		return true

	return source_direction == float(_facing_component.get_direction())


func _can_enter_defense() -> bool:
	return _is_grounded()


func _is_grounded() -> bool:
	return _body_component == null or _body_component.is_on_floor()


func _on_attack_started() -> void:
	stop_guard()
	_finish_parry()


func _allows_guard() -> bool:
	return (
		_equipment_component == null
		or bool(_equipment_component.call("allows_guard"))
	)


func _allows_parry() -> bool:
	return (
		_equipment_component == null
		or bool(_equipment_component.call("allows_parry"))
	)


func _on_equipment_changed(_previous_slot: int, _current_slot: int) -> void:
	_cancel_guard_if_melee_unavailable()


func _on_loadout_item_changed(
	_equip_slot: ItemData.EquipSlot,
	_slot_index: int,
	_weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	_cancel_guard_if_melee_unavailable()


func _on_weapon_set_changed(_previous_set: int, _current_set: int) -> void:
	_cancel_guard_if_melee_unavailable()


func _cancel_guard_if_melee_unavailable() -> void:
	if not _allows_guard():
		stop_guard()
	if not _allows_parry():
		_finish_parry()
