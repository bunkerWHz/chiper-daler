@tool
extends Node
class_name DotEffectGenerator

## Open DotEffectGenerator.tscn and select its root to create named DOT resources.
@export var effect_id: StringName = &"burning"
@export var display_name: String = "Горение"
@export_range(0.1, 100000.0, 0.1) var damage_per_tick: float = 5.0
@export_range(0.05, 3600.0, 0.05) var tick_interval: float = 1.0
@export_range(0.05, 3600.0, 0.05) var duration: float = 5.0
@export_tool_button("Create DOT resource", "Resource") var generate: Callable = _generate
@export_tool_button("Refresh DOT catalog", "Reload") var refresh_catalog: Callable = _refresh_catalog

const CATALOG = preload("res://game/status/DotCatalog.tres")


func build_effect() -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_id = effect_id
	effect.display_name = display_name
	effect.polarity = StatusEffect.Polarity.DEBUFF
	effect.damage_per_tick = damage_per_tick
	effect.tick_interval = tick_interval
	effect.duration = duration
	return effect


func _generate() -> void:
	if not Engine.is_editor_hint():
		return
	var error := save_effect("res://game/status", CATALOG)
	if error != OK:
		push_error("Could not create DOT (use a unique ID and valid parameters): " + error_string(error))
		return
	var path := "res://game/status".path_join(String(effect_id) + ".tres")
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.edit_resource(load(path))
	print("Created DOT and resistance entry: ", path)


## Save both the definition and registry. Existing definitions are never overwritten.
func save_effect(directory: String, catalog: DotCatalog) -> Error:
	var effect := build_effect()
	if not String(effect_id).is_valid_identifier() or not DotCatalog.is_dot_definition(effect):
		return ERR_INVALID_PARAMETER
	if catalog == null or catalog.resource_path.is_empty():
		return ERR_INVALID_PARAMETER
	var path := directory.path_join(String(effect_id) + ".tres")
	if FileAccess.file_exists(path) or catalog.contains(effect_id):
		return ERR_ALREADY_EXISTS
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error == OK:
		error = ResourceSaver.save(effect, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		return error
	# ResourceSaver does not retain the path for a newly created resource here.
	# Register the saved file, not an embedded duplicate inside the catalog.
	effect.take_over_path(path)
	var previous := catalog.effects.duplicate()
	catalog.register_effect(effect)
	error = ResourceSaver.save(catalog)
	if error != OK:
		catalog.effects = previous
		DirAccess.remove_absolute(path)
	return error


## Also imports definitions created manually in the DOT directory.
func rebuild_catalog(directory: String, catalog: DotCatalog) -> Error:
	if catalog == null or catalog.resource_path.is_empty() or not DirAccess.dir_exists_absolute(directory):
		return ERR_INVALID_PARAMETER
	var definitions: Array[StatusEffect] = []
	var ids: Array[StringName] = []
	for file: String in DirAccess.get_files_at(directory):
		if not file.ends_with(".tres") and not file.ends_with(".res"):
			continue
		var effect := load(directory.path_join(file)) as StatusEffect
		if effect == null or effect.damage_per_tick == 0.0:
			continue
		if not DotCatalog.is_dot_definition(effect) or effect.effect_id in ids:
			return ERR_INVALID_DATA
		ids.append(effect.effect_id)
		definitions.append(effect)
	var previous := catalog.effects
	catalog.effects = definitions
	var error := ResourceSaver.save(catalog)
	if error != OK:
		catalog.effects = previous
	return error


func _refresh_catalog() -> void:
	if not Engine.is_editor_hint():
		return
	var error := rebuild_catalog("res://game/status", CATALOG)
	if error != OK:
		push_error("Could not refresh DOT catalog; check definitions and duplicate IDs: " + error_string(error))
		return
	EditorInterface.get_resource_filesystem().scan()
	print("Updated DOT catalog and resistance lists.")
