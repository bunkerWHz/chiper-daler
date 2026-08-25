extends Component
class_name HurtboxComponent

signal hit_received(hit: HitData, applied_damage: float)

const INVULNERABILITY_COMPONENT_SCRIPT := preload(
	"res://features/combat/InvulnerabilityComponent.gd"
)

var _health_component: HealthComponent
var _invulnerability_component: Component


func on_initialize() -> void:
	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _health_component == null or not _health_component.is_enabled:
		push_error("HurtboxComponent requires an enabled HealthComponent")
		disable()
		return

	_invulnerability_component = (
		actor.get_component(INVULNERABILITY_COMPONENT_SCRIPT)
		as Component
	)

	if (
		_invulnerability_component != null
		and not _invulnerability_component.is_enabled
	):
		_invulnerability_component = null


func receive_hit(hit: HitData) -> float:
	if not is_enabled or _health_component == null:
		return 0.0

	if hit == null or hit.damage <= 0.0 or _health_component.is_dead():
		return 0.0

	if (
		_invulnerability_component != null
		and not bool(_invulnerability_component.call("can_receive_damage"))
	):
		return 0.0

	var applied_damage := _health_component.take_damage(hit.damage)

	if applied_damage > 0.0:
		if (
			_invulnerability_component != null
			and _invulnerability_component.is_enabled
		):
			_invulnerability_component.call("activate")

		hit_received.emit(hit, applied_damage)

	return applied_damage
