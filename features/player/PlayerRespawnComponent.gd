extends Component
class_name PlayerRespawnComponent

signal restart_scheduled(delay: float)
signal restart_requested

@export var config: PlayerRespawnConfig

var _health_component: HealthComponent
var _restart_scheduled: bool = false


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


func is_restart_scheduled() -> bool:
	return _restart_scheduled


func _on_health_died() -> void:
	if _restart_scheduled or not is_enabled:
		return

	_restart_scheduled = true
	restart_scheduled.emit(config.restart_delay)

	if not is_inside_tree():
		return

	var timer := get_tree().create_timer(config.restart_delay)
	timer.timeout.connect(_restart_current_scene)


func _restart_current_scene() -> void:
	_restart_scheduled = false
	restart_requested.emit()

	var error := get_tree().reload_current_scene()

	if error != OK:
		push_error("PlayerRespawnComponent failed to reload the current scene")
