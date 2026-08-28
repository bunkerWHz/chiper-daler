extends Component
class_name CharacterAttributesComponent

signal attributes_changed(strength: int, dexterity: int)

@export_range(0, 999, 1) var strength: int = 5
@export_range(0, 999, 1) var dexterity: int = 5


func meets_item_requirements(item: ItemData) -> bool:
	if item == null or item.stats == null:
		return true
	return (
		strength >= item.stats.strength_requirement
		and dexterity >= item.stats.dexterity_requirement
	)


func get_requirement_failure(item: ItemData) -> String:
	if item == null or item.stats == null:
		return ""
	var missing := PackedStringArray()
	if strength < item.stats.strength_requirement:
		missing.append("STR %d" % item.stats.strength_requirement)
	if dexterity < item.stats.dexterity_requirement:
		missing.append("DEX %d" % item.stats.dexterity_requirement)
	return ", ".join(missing)


func set_strength(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == strength:
		return
	strength = resolved
	attributes_changed.emit(strength, dexterity)


func set_dexterity(value: int) -> void:
	var resolved := maxi(value, 0)
	if resolved == dexterity:
		return
	dexterity = resolved
	attributes_changed.emit(strength, dexterity)


func capture_runtime_state() -> Variant:
	return {
		"strength": strength,
		"dexterity": dexterity,
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	strength = maxi(int(state.get("strength", strength)), 0)
	dexterity = maxi(int(state.get("dexterity", dexterity)), 0)
	attributes_changed.emit(strength, dexterity)


func get_runtime_state_restore_priority() -> int:
	return -50
