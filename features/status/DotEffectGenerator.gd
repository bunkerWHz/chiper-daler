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
	var effect := build_effect()
	if not String(effect_id).is_valid_identifier() or not effect.is_valid() or damage_per_tick <= 0.0:
		push_error("Use an ID such as frost_bite and positive damage, interval and duration.")
		return
	var directory := "res://game/status"
	var path := directory.path_join(String(effect_id) + ".tres")
	if FileAccess.file_exists(path):
		push_error("Effect already exists; edit it directly or choose another ID: " + path)
		return
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error == OK:
		error = ResourceSaver.save(effect, path)
	if error != OK:
		push_error("Could not create DOT: " + error_string(error))
		return
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.edit_resource(effect)
	print("Created DOT: ", path)
