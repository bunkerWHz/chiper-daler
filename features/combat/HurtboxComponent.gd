extends Component
class_name HurtboxComponent

signal hit_received(hit: HitData, applied_damage: float)

var _health_component: HealthComponent


func on_initialize() -> void:
	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _health_component == null or not _health_component.is_enabled:
		push_error("HurtboxComponent requires an enabled HealthComponent")
		disable()


func receive_hit(hit: HitData) -> float:
	if not is_enabled or _health_component == null:
		return 0.0

	if hit == null or hit.damage <= 0.0 or _health_component.is_dead():
		return 0.0

	var applied_damage := _health_component.take_damage(hit.damage)

	if applied_damage > 0.0:
		hit_received.emit(hit, applied_damage)

	return applied_damage
