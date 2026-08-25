extends Component
class_name DamageNumberComponent

signal damage_number_spawned(number: DamageNumberView, amount: float)

const DAMAGE_NUMBER_SCENE := preload(
	"res://features/combat/DamageNumberView.tscn"
)

@export var config: DamageNumberConfig

var _health_component: HealthComponent


func on_initialize() -> void:
	if config == null:
		push_error("DamageNumberComponent requires DamageNumberConfig")
		disable()
		return

	if config.duration <= 0.0 or config.rise_distance <= 0.0:
		push_error("DamageNumberComponent has an invalid config")
		disable()
		return

	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _health_component == null or not _health_component.is_enabled:
		push_error("DamageNumberComponent requires an enabled HealthComponent")
		disable()
		return

	if not _health_component.damaged.is_connected(_on_damaged):
		_health_component.damaged.connect(_on_damaged)


func _on_damaged(amount: float, _current_health: float) -> void:
	if not is_enabled or not is_inside_tree():
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var number := DAMAGE_NUMBER_SCENE.instantiate() as DamageNumberView
	number.setup(amount, actor.global_position + config.spawn_offset, config)
	current_scene.add_child(number)
	damage_number_spawned.emit(number, amount)
