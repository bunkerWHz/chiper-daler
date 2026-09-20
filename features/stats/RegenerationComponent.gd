extends Component
class_name RegenerationComponent

## All resource regeneration shares one real-time tick. Pausing freezes it.
@export_range(0.1, 10.0, 0.1) var tick_interval: float = 1.0
@export_range(0.0, 60.0, 0.5) var combat_timeout: float = 5.0
@export_range(1.0, 10.0, 0.1) var out_of_combat_multiplier: float = 2.0
var _elapsed := 0.0
var _combat_remaining := 0.0
var _attributes: CharacterAttributesComponent
var _equipment: EquipmentComponent
var _health: HealthComponent
var _mana: MagicComponent
var _stamina: StaminaComponent

func on_initialize() -> void:
	_attributes = actor.get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_health = actor.get_component(HealthComponent) as HealthComponent
	_mana = actor.get_component(MagicComponent) as MagicComponent
	_stamina = actor.get_component(StaminaComponent) as StaminaComponent
	if _attributes == null or _health == null:
		disable()
		return
	_health.damaged.connect(enter_combat.unbind(2))
	_health.died.connect(_reset)
	var attack := actor.get_component(AttackComponent) as AttackComponent
	if attack != null:
		attack.attack_started.connect(enter_combat)
	var ranged := actor.get_component(RangedWeaponComponent) as RangedWeaponComponent
	if ranged != null:
		ranged.projectile_fired.connect(enter_combat.unbind(2))
	var throwing := actor.get_component(ThrowingComponent) as ThrowingComponent
	if throwing != null:
		throwing.throwable_released.connect(enter_combat.unbind(2))
	if _mana != null:
		_mana.phase_changed.connect(_on_magic_phase)

func enter_combat() -> void:
	_combat_remaining = combat_timeout

func is_in_combat() -> bool:
	return _combat_remaining > 0.0

func get_regeneration_multiplier() -> float:
	return 1.0 if is_in_combat() else out_of_combat_multiplier

func _on_magic_phase(_previous: MagicComponent.Phase, current: MagicComponent.Phase) -> void:
	if current in [MagicComponent.Phase.CAST, MagicComponent.Phase.CHANNELING]:
		enter_combat()

func _reset() -> void:
	_elapsed = 0.0
	_combat_remaining = 0.0

func _process(delta: float) -> void:
	if not is_enabled or not _attributes.is_enabled or not _health.is_alive():
		return
	var channeling := _mana != null and _mana.get_phase() == MagicComponent.Phase.CHANNELING
	# Advance to each boundary so a long frame never grants the peaceful bonus
	# retroactively to ticks that occurred while still in combat.
	while delta > 0.0:
		var step := minf(delta, tick_interval - _elapsed)
		_combat_remaining = combat_timeout if channeling else maxf(0.0, _combat_remaining - step)
		_elapsed += step
		delta -= step
		if _elapsed + 0.000001 >= tick_interval:
			_elapsed = 0.0
			_tick()

func _bonus(property: StringName) -> float:
	return _equipment.get_stat_bonus(property) if _equipment != null and _equipment.is_enabled else 0.0

func _tick() -> void:
	var multiplier := get_regeneration_multiplier()
	_health.heal((_attributes.get_health_regeneration() + _bonus(&"health_regeneration")) * multiplier)
	if _mana != null and _mana.is_enabled:
		_mana.restore_mana((_attributes.get_mana_regeneration() + _bonus(&"mana_regeneration")) * multiplier)
	if _stamina != null and _stamina.is_enabled:
		_stamina.restore((_attributes.get_stamina_regeneration() + _bonus(&"stamina_regeneration")) * multiplier)
