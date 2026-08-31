extends Component
class_name ViewportFallDeathComponent

@export var config: ViewportFallDeathConfig

var _health: HealthComponent
var _death_triggered := false


func on_initialize() -> void:
	if config == null:
		push_error("ViewportFallDeathComponent requires ViewportFallDeathConfig")
		disable()
		return
	if config.bottom_margin < 0.0:
		push_error("ViewportFallDeathConfig bottom_margin cannot be negative")
		disable()
		return
	_health = actor.get_component(HealthComponent) as HealthComponent
	if _health == null or not _health.is_enabled:
		push_error("ViewportFallDeathComponent requires an enabled HealthComponent")
		disable()


func _process(_delta: float) -> void:
	if _death_triggered or _health == null or _health.is_dead():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_position := (
		viewport.get_canvas_transform() * actor.global_position
	)
	_check_screen_position(screen_position, viewport.get_visible_rect())


func _check_screen_position(
	screen_position: Vector2,
	visible_rect: Rect2
) -> bool:
	if (
		not is_enabled
		or _death_triggered
		or _health == null
		or _health.is_dead()
		or screen_position.y <= visible_rect.end.y + config.bottom_margin
	):
		return false
	_death_triggered = true
	_health.take_damage(_health.get_current_health())
	return true
