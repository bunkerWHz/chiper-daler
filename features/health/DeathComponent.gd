extends Component
class_name DeathComponent

signal death_started
signal death_finished

@export var config: DeathConfig
@export var visual_path: NodePath = ^"_Visual"

var _health_component: HealthComponent
var _visual: CanvasItem
var _original_modulate: Color = Color.WHITE
var _death_timer: float = 0.0
var _is_dying: bool = false


func on_initialize() -> void:
	if config == null:
		push_error("DeathComponent requires DeathConfig")
		disable()
		return

	if config.duration <= 0.0:
		push_error("DeathConfig duration must be greater than zero")
		disable()
		return

	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _health_component == null or not _health_component.is_enabled:
		push_error("DeathComponent requires an enabled HealthComponent")
		disable()
		return

	if not _health_component.died.is_connected(_on_health_died):
		_health_component.died.connect(_on_health_died)


func _ready() -> void:
	if not config.fade_visual:
		return

	_visual = actor.get_node_or_null(visual_path) as CanvasItem

	if _visual == null:
		push_error("DeathComponent requires a CanvasItem visual for fade-out")
		disable()
		return

	_original_modulate = _visual.modulate


func _process(delta: float) -> void:
	if not _is_dying:
		return

	_death_timer = maxf(_death_timer - delta, 0.0)
	_update_visual()

	if _death_timer == 0.0:
		_finish_death()


func is_dying() -> bool:
	return _is_dying


func _on_health_died() -> void:
	if _is_dying or not is_enabled:
		return

	_is_dying = true
	_death_timer = config.duration
	_disable_actor_components()
	_disable_actor_collisions()
	death_started.emit()


func _disable_actor_components() -> void:
	for component: Component in actor.get_components():
		if component != self:
			component.disable()


func _disable_actor_collisions() -> void:
	for node: Node in actor.find_children("*", "CollisionShape2D", true, false):
		(node as CollisionShape2D).set_deferred(&"disabled", true)

	for node: Node in actor.find_children("*", "CollisionPolygon2D", true, false):
		(node as CollisionPolygon2D).set_deferred(&"disabled", true)


func _update_visual() -> void:
	if not config.fade_visual or _visual == null:
		return

	var progress := 1.0 - (_death_timer / config.duration)
	var modulate := _original_modulate
	modulate.a = lerpf(_original_modulate.a, 0.0, progress)
	_visual.modulate = modulate


func _finish_death() -> void:
	_is_dying = false
	set_process(false)
	death_finished.emit()

	if config.remove_actor_on_finish and is_instance_valid(actor):
		actor.queue_free()
