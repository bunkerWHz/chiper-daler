extends Component
class_name PlayerRespawnComponent

signal restart_scheduled(delay: float)
signal restart_requested
signal checkpoint_changed(position: Vector2)
signal actor_respawned(replacement: Actor)

static var _scene_checkpoints: Dictionary = {}

@export var config: PlayerRespawnConfig

var _health_component: HealthComponent
var _restart_scheduled: bool = false
var _restart_timer: SceneTreeTimer


func on_initialize() -> void:
	if config == null:
		push_error("PlayerRespawnComponent requires PlayerRespawnConfig")
		disable()
		return

	if config.restart_delay <= 0.0:
		push_error("PlayerRespawnConfig restart_delay must be greater than zero")
		disable()
		return

	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _health_component == null or not _health_component.is_enabled:
		push_error("PlayerRespawnComponent requires an enabled HealthComponent")
		disable()
		return

	if not _health_component.died.is_connected(_on_health_died):
		_health_component.died.connect(_on_health_died)

	var scene_key := _get_scene_key()
	if _scene_checkpoints.has(scene_key):
		actor.global_position = _scene_checkpoints[scene_key]
	else:
		_scene_checkpoints[scene_key] = actor.global_position


func is_restart_scheduled() -> bool:
	return _restart_scheduled


func set_checkpoint_position(position: Vector2) -> void:
	_scene_checkpoints[_get_scene_key()] = position
	checkpoint_changed.emit(position)


func get_checkpoint_position() -> Vector2:
	return _scene_checkpoints.get(_get_scene_key(), actor.global_position)


func has_checkpoint() -> bool:
	return _scene_checkpoints.has(_get_scene_key())


func should_disable_on_actor_death() -> bool:
	return false


func disable() -> void:
	_restart_scheduled = false
	if (
		_restart_timer != null
		and _restart_timer.timeout.is_connected(_restart_current_scene)
	):
		_restart_timer.timeout.disconnect(_restart_current_scene)
	_restart_timer = null
	super.disable()


func _on_health_died() -> void:
	if _restart_scheduled or not is_enabled:
		return

	_restart_scheduled = true
	restart_scheduled.emit(config.restart_delay)

	if not is_inside_tree():
		return

	_restart_timer = get_tree().create_timer(config.restart_delay)
	_restart_timer.timeout.connect(_restart_current_scene)


func _restart_current_scene() -> void:
	_restart_scheduled = false
	_restart_timer = null
	restart_requested.emit()

	if _replace_actor_at_checkpoint():
		return

	var error := get_tree().reload_current_scene()

	if error != OK:
		push_error("PlayerRespawnComponent failed to reload the current scene")


func _replace_actor_at_checkpoint() -> bool:
	if actor == null or actor.scene_file_path.is_empty():
		return false

	var actor_scene := load(actor.scene_file_path) as PackedScene
	var parent := actor.get_parent()
	if actor_scene == null or parent == null:
		return false

	var replacement := actor_scene.instantiate() as Actor
	if replacement == null:
		return false

	var spawn_position := get_checkpoint_position()
	var runtime_state := _capture_actor_runtime_state(actor)
	var sibling_index := actor.get_index()
	var actor_name := actor.name
	parent.remove_child(actor)
	actor.queue_free()

	replacement.name = actor_name
	parent.add_child(replacement)
	parent.move_child(replacement, mini(sibling_index, parent.get_child_count() - 1))
	replacement.global_position = spawn_position
	_restore_actor_runtime_state(replacement, runtime_state)
	actor_respawned.emit(replacement)
	return true


func _capture_actor_runtime_state(source: Actor) -> Dictionary:
	var result := {}
	for component: Component in source.get_components():
		var state: Variant = component.capture_runtime_state()
		if state != null:
			result[String(component.name)] = state

	return result


func _restore_actor_runtime_state(target: Actor, state: Dictionary) -> void:
	var components := target.get_components()
	components.sort_custom(_sort_runtime_restore_priority)
	for component: Component in components:
		var key := String(component.name)
		if state.has(key):
			component.restore_runtime_state(state[key])


func _sort_runtime_restore_priority(
	left: Component,
	right: Component
) -> bool:
	return (
		left.get_runtime_state_restore_priority()
		< right.get_runtime_state_restore_priority()
	)


func _get_scene_key() -> String:
	if is_inside_tree() and get_tree().current_scene != null:
		var current_path := get_tree().current_scene.scene_file_path
		if not current_path.is_empty():
			return current_path

	if actor != null and not actor.scene_file_path.is_empty():
		return actor.scene_file_path

	return "__runtime__"


static func clear_saved_checkpoints() -> void:
	_scene_checkpoints.clear()
