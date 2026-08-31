extends Component
class_name CharacterAttributesComponent

signal attributes_changed(
	strength: int,
	dexterity: int,
	intelligence: int,
	endurance: int,
	wisdom: int
)

@export_range(0, 999, 1) var strength: int = 5
@export_range(0, 999, 1) var dexterity: int = 5
@export_range(0, 999, 1) var intelligence: int = 5
@export_range(0, 999, 1) var endurance: int = 5
@export_range(0, 999, 1) var wisdom: int = 5
@export var derived_stats_config := CharacterDerivedStatsConfig.new()


func get_endurance_health_bonus() -> float:
	if derived_stats_config == null:
		return 0.0
	return (
		float(endurance - derived_stats_config.reference_endurance)
		* derived_stats_config.health_per_endurance
	)


func get_max_equip_load() -> float:
	if derived_stats_config == null:
		return 1.0
	return maxf(
		derived_stats_config.base_max_equip_load
		+ float(endurance - derived_stats_config.reference_endurance)
		* derived_stats_config.equip_load_per_endurance,
		1.0
	)


func meets_item_requirements(item: ItemData) -> bool:
	var item_stats := item.get_equipment_stats() if item != null else null
	if item_stats == null:
		return true
	return (
		strength >= item_stats.strength_requirement
		and dexterity >= item_stats.dexterity_requirement
		and intelligence >= item_stats.intelligence_requirement
		and endurance >= item_stats.endurance_requirement
		and wisdom >= item_stats.wisdom_requirement
	)


func get_requirement_failure(item: ItemData) -> String:
	var item_stats := item.get_equipment_stats() if item != null else null
	if item_stats == null:
		return ""
	var missing := PackedStringArray()
	if strength < item_stats.strength_requirement:
		missing.append("STR %d" % item_stats.strength_requirement)
	if dexterity < item_stats.dexterity_requirement:
		missing.append("DEX %d" % item_stats.dexterity_requirement)
	if intelligence < item_stats.intelligence_requirement:
		missing.append("INT %d" % item_stats.intelligence_requirement)
	if endurance < item_stats.endurance_requirement:
		missing.append("END %d" % item_stats.endurance_requirement)
	if wisdom < item_stats.wisdom_requirement:
		missing.append("WIS %d" % item_stats.wisdom_requirement)
	return ", ".join(missing)


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
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	strength = maxi(int(state.get("strength", strength)), 0)
	dexterity = maxi(int(state.get("dexterity", dexterity)), 0)
	intelligence = maxi(int(state.get("intelligence", intelligence)), 0)
	endurance = maxi(int(state.get("endurance", endurance)), 0)
	wisdom = maxi(int(state.get("wisdom", wisdom)), 0)
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
