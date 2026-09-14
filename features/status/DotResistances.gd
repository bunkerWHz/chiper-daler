@tool
extends Resource
class_name DotResistances

const PROPERTY_PREFIX := "resistance/"
const DEFAULT_CATALOG = preload("res://game/status/DotCatalog.tres")

@export_storage var catalog: DotCatalog = DEFAULT_CATALOG:
	set(value):
		if catalog != null and catalog.changed.is_connected(_on_catalog_changed):
			catalog.changed.disconnect(_on_catalog_changed)
		catalog = value
		_connect_catalog()
		_on_catalog_changed()

## Only overrides are stored; newly registered types always start at zero.
@export_storage var percentages: Dictionary = {}


func _init() -> void:
	resource_local_to_scene = true
	_connect_catalog()


func get_percent(effect_id: StringName) -> float:
	var value := float(percentages.get(effect_id, 0.0))
	return clampf(value, 0.0, 100.0) if is_finite(value) else 0.0


func set_percent(effect_id: StringName, value: float) -> void:
	if effect_id.is_empty() or not is_finite(value):
		return
	percentages[effect_id] = clampf(value, 0.0, 100.0)
	emit_changed()


func get_all() -> Dictionary:
	var result: Dictionary = {}
	if catalog != null:
		for effect_id: StringName in catalog.get_effect_ids():
			result[effect_id] = get_percent(effect_id)
	return result


func reduce_damage(effect_id: StringName, damage: float) -> float:
	return maxf(damage, 0.0) * (1.0 - get_percent(effect_id) / 100.0)


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if catalog == null:
		return properties
	for effect_id: StringName in catalog.get_effect_ids():
		properties.append({
			"name": PROPERTY_PREFIX + String(effect_id),
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,100,0.1,suffix:%",
			# Persistence is owned by percentages; these are inspector views.
			"usage": PROPERTY_USAGE_EDITOR,
		})
	return properties


func _get(property: StringName) -> Variant:
	if String(property).begins_with(PROPERTY_PREFIX):
		return get_percent(StringName(String(property).trim_prefix(PROPERTY_PREFIX)))
	return null


func _set(property: StringName, value: Variant) -> bool:
	if not String(property).begins_with(PROPERTY_PREFIX):
		return false
	set_percent(StringName(String(property).trim_prefix(PROPERTY_PREFIX)), float(value))
	return true


func _property_can_revert(property: StringName) -> bool:
	return String(property).begins_with(PROPERTY_PREFIX)


func _property_get_revert(_property: StringName) -> Variant:
	return 0.0


func _connect_catalog() -> void:
	if catalog != null and not catalog.changed.is_connected(_on_catalog_changed):
		catalog.changed.connect(_on_catalog_changed)


func _on_catalog_changed() -> void:
	notify_property_list_changed()
	emit_changed()
