extends Component
class_name CharacterAttributesComponent

signal attributes_changed(
	strength: int,
	dexterity: int,
	intelligence: int,
	endurance: int,
	wisdom: int
)

@export_group("Base attributes")
@export_range(0, 999, 1) var strength: int = 1
@export_range(0, 999, 1) var dexterity: int = 1
@export_range(0, 999, 1) var intelligence: int = 1
@export_range(0, 999, 1) var endurance: int = 1
@export_range(0, 999, 1) var wisdom: int = 1
@export_group("Derived values")
@export var derived_stats_config := CharacterDerivedStatsConfig.new()
## Additional multiplier retained for buffs and existing saves.
@export_group("Action speed")
@export_range(0.1, 10.0, 0.05) var attack_speed_multiplier: float = 1.0


func get_attack_speed_multiplier() -> float:
	var extra := clampf(attack_speed_multiplier, 0.1, 10.0) if is_finite(attack_speed_multiplier) else 1.0
	return (100.0 + maxi(dexterity - 1, 0)) / 100.0 * extra


func get_run_speed_multiplier() -> float:
	return (100.0 + maxi(dexterity - 1, 0)) / 100.0


func get_cast_speed_multiplier() -> float:
	return (100.0 + maxi(wisdom - 1, 0)) / 100.0


func get_physical_attack() -> float:
	return 1.0 + maxi(strength - 1, 0)


func get_magic_attack() -> float:
	return 1.0 + maxi(intelligence - 1, 0)


func get_physical_defense() -> float:
	return 1.0 + maxi(strength - 1, 0)


func get_magic_defense() -> float:
	return 1.0 + maxi(intelligence - 1, 0)


func get_health_regeneration() -> float:
	return 10.0 + maxi(endurance - 1, 0)


func get_mana_regeneration() -> float:
	return 10.0 + maxi(wisdom - 1, 0)


func get_stamina_regeneration() -> float:
	return 10.0 + maxi(dexterity - 1, 0)


func get_endurance_health_bonus() -> float:
	if derived_stats_config == null:
		return 0.0
	return (
		float(maxi(endurance - derived_stats_config.reference_endurance, 0))
		* derived_stats_config.health_per_endurance
	)


func get_max_equip_load() -> float:
	if derived_stats_config == null:
		return 1.0
	return maxf(
		derived_stats_config.base_max_equip_load
		+ float(maxi(endurance - derived_stats_config.reference_endurance, 0))
		* derived_stats_config.equip_load_per_endurance,
		1.0
	)


func get_wisdom_mana_bonus() -> float:
	if derived_stats_config == null:
		return 0.0
	return (
		float(maxi(wisdom - derived_stats_config.reference_wisdom, 0))
		* derived_stats_config.mana_per_wisdom
	)


func set_strength(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == strength:
		return
	strength = resolved
	_emit_attributes_changed()


func set_dexterity(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == dexterity:
		return
	dexterity = resolved
	_emit_attributes_changed()


func set_intelligence(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == intelligence:
		return
	intelligence = resolved
	_emit_attributes_changed()


func set_endurance(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == endurance:
		return
	endurance = resolved
	_emit_attributes_changed()


func set_wisdom(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == wisdom:
		return
	wisdom = resolved
	_emit_attributes_changed()


func capture_runtime_state() -> Variant:
	return {
		"strength": strength,
		"dexterity": dexterity,
		"intelligence": intelligence,
		"endurance": endurance,
		"wisdom": wisdom,
		"attack_speed_multiplier": attack_speed_multiplier,
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	strength = maxi(int(state.get("strength", strength)), 0)
	dexterity = maxi(int(state.get("dexterity", dexterity)), 0)
	intelligence = maxi(int(state.get("intelligence", intelligence)), 0)
	endurance = maxi(int(state.get("endurance", endurance)), 0)
	wisdom = maxi(int(state.get("wisdom", wisdom)), 0)
	attack_speed_multiplier = float(state.get("attack_speed_multiplier", attack_speed_multiplier))
	_emit_attributes_changed()


func get_runtime_state_restore_priority() -> int:
	return -50


func _emit_attributes_changed() -> void:
	attributes_changed.emit(
		strength,
		dexterity,
		intelligence,
		endurance,
		wisdom
	)
