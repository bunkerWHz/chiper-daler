extends Node2D
class_name WorldHealthBarView

@export var actor_path: NodePath = ^"../.."

var _health_component: HealthComponent
var _displayed_health: float = 0.0
var _displayed_max_health: float = 1.0

@onready var _progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	if _health_component == null:
		var target_actor := get_node_or_null(actor_path) as Actor

		if target_actor == null:
			push_error("WorldHealthBarView requires a valid Actor path")
			return

		var health := target_actor.get_component(HealthComponent) as HealthComponent

		if health == null or not health.is_enabled:
			push_error("WorldHealthBarView requires an enabled HealthComponent")
			return

		bind_health(health)

	_apply_display()


func bind_health(health: HealthComponent) -> void:
	if _health_component != null and _health_component.health_changed.is_connected(
		_on_health_changed
	):
		_health_component.health_changed.disconnect(_on_health_changed)

	_health_component = health

	if _health_component == null:
		return

	if not _health_component.health_changed.is_connected(_on_health_changed):
		_health_component.health_changed.connect(_on_health_changed)

	_set_displayed_health(
		_health_component.get_current_health(),
		_health_component.get_max_health()
	)


func get_displayed_health() -> float:
	return _displayed_health


func get_displayed_max_health() -> float:
	return _displayed_max_health


func _on_health_changed(_previous_health: float, current_health: float) -> void:
	_set_displayed_health(current_health, _health_component.get_max_health())


func _set_displayed_health(current_health: float, max_health: float) -> void:
	_displayed_max_health = maxf(max_health, 1.0)
	_displayed_health = clampf(current_health, 0.0, _displayed_max_health)

	if is_node_ready():
		_apply_display()


func _apply_display() -> void:
	_progress_bar.max_value = _displayed_max_health
	_progress_bar.value = _displayed_health
