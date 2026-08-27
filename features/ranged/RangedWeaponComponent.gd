extends Component
class_name RangedWeaponComponent

enum Phase {
	NONE,
	BOW_AIM,
	BOW_LOOSE,
	CROSSBOW_AIM,
	CROSSBOW_FIRE,
}

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal projectile_fired(phase: Phase, remaining_ammo: int)

const PROJECTILE_SCENE := preload("res://features/throwing/ThrownProjectile.tscn")

@export var config: RangedWeaponConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _facing_component: FacingComponent
var _phase: Phase = Phase.NONE
var _phase_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _arrows: int = 0
var _bolts: int = 0


func on_initialize() -> void:
	if config == null:
		push_error("RangedWeaponComponent requires RangedWeaponConfig")
		disable()
		return

	if (
		config.release_duration <= 0.0
		or config.shot_cooldown < 0.0
		or config.arrow_speed <= 0.0
		or config.bolt_speed <= 0.0
		or config.projectile_lifetime <= 0.0
		or config.arrow_damage < 0.0
		or config.bolt_damage < 0.0
	):
		push_error("RangedWeaponComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_equipment_component = actor.get_component(EquipmentComponent) as EquipmentComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent

	if _input_component == null or _equipment_component == null or _facing_component == null:
		push_error("RangedWeaponComponent requires input, equipment, and facing")
		disable()
		return

	_arrows = config.arrow_count
	_bolts = config.bolt_count
	_equipment_component.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_update_release(delta)

	if _equipment_component.is_slot_active(EquipmentComponent.Slot.BOW):
		_process_bow_input()
	elif _equipment_component.is_slot_active(EquipmentComponent.Slot.CROSSBOW):
		_process_crossbow_input()


func get_phase() -> Phase:
	return _phase


func get_arrow_count() -> int:
	return _arrows


func get_bolt_count() -> int:
	return _bolts


func cancel_aim() -> void:
	if _phase == Phase.BOW_AIM or _phase == Phase.CROSSBOW_AIM:
		_set_phase(Phase.NONE, 0.0)


func disable() -> void:
	_set_phase(Phase.NONE, 0.0)
	super.disable()


func _process_bow_input() -> void:
	if _phase == Phase.NONE and _input_component.consume_attack_pressed():
		if _arrows > 0 and _cooldown_timer <= 0.0:
			_set_phase(Phase.BOW_AIM, 0.0)
	elif _phase == Phase.BOW_AIM:
		if _input_component.consume_guard_just_pressed():
			cancel_aim()
		elif _input_component.consume_attack_released():
			_arrows -= 1
			_spawn_projectile(config.arrow_speed, config.arrow_damage)
			projectile_fired.emit(Phase.BOW_LOOSE, _arrows)
			_set_phase(Phase.BOW_LOOSE, config.release_duration)
			_cooldown_timer = config.shot_cooldown


func _process_crossbow_input() -> void:
	if _phase == Phase.NONE and _input_component.consume_attack_pressed():
		if _bolts > 0 and _cooldown_timer <= 0.0:
			_set_phase(Phase.CROSSBOW_AIM, 0.0)
	elif _phase == Phase.CROSSBOW_AIM:
		if _input_component.consume_guard_just_pressed():
			_bolts -= 1
			_spawn_projectile(config.bolt_speed, config.bolt_damage)
			projectile_fired.emit(Phase.CROSSBOW_FIRE, _bolts)
			_set_phase(Phase.CROSSBOW_FIRE, config.release_duration)
			_cooldown_timer = config.shot_cooldown
		elif _input_component.consume_attack_pressed():
			cancel_aim()


func _update_release(delta: float) -> void:
	if _phase != Phase.BOW_LOOSE and _phase != Phase.CROSSBOW_FIRE:
		return

	_phase_timer = maxf(_phase_timer - delta, 0.0)

	if _phase_timer == 0.0:
		_set_phase(Phase.NONE, 0.0)


func _spawn_projectile(speed: float, damage: float) -> void:
	var parent := actor.get_parent()

	if parent == null:
		return

	var projectile := PROJECTILE_SCENE.instantiate() as ThrownProjectile
	parent.add_child(projectile)
	projectile.global_position = actor.global_position
	projectile.setup(
		actor,
		float(_facing_component.get_direction()),
		speed,
		damage,
		config.knockback,
		config.projectile_lifetime
	)


func _set_phase(new_phase: Phase, duration: float) -> void:
	if new_phase == _phase:
		return

	var previous_phase := _phase
	_phase = new_phase
	_phase_timer = duration
	phase_changed.emit(previous_phase, _phase)


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	_current_slot: EquipmentComponent.Slot
) -> void:
	_set_phase(Phase.NONE, 0.0)
