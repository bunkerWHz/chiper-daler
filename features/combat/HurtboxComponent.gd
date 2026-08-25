extends Component
class_name HurtboxComponent

signal hit_received(hit: HitData, applied_damage: float)

const INVULNERABILITY_COMPONENT_SCRIPT := preload(
	"res://features/combat/InvulnerabilityComponent.gd"
)
const KNOCKBACK_COMPONENT_SCRIPT := preload(
	"res://features/combat/KnockbackComponent.gd"
)
const HIT_STUN_COMPONENT_SCRIPT := preload(
	"res://features/combat/HitStunComponent.gd"
)

var _health_component: HealthComponent
var _invulnerability_component: Component
var _knockback_component: Component
var _hit_stun_component: Component


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

	_knockback_component = (
		actor.get_component(KNOCKBACK_COMPONENT_SCRIPT)
		as Component
	)

	if _knockback_component != null and not _knockback_component.is_enabled:
		_knockback_component = null

	_hit_stun_component = (
		actor.get_component(HIT_STUN_COMPONENT_SCRIPT)
		as Component
	)

	if _hit_stun_component != null and not _hit_stun_component.is_enabled:
		_hit_stun_component = null


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

	var modified_damage := _apply_damage_modifiers(hit)

	if modified_damage <= 0.0:
		return 0.0

	var applied_damage := _health_component.take_damage(modified_damage)

	if applied_damage > 0.0:
		if (
			_invulnerability_component != null
			and _invulnerability_component.is_enabled
		):
			_invulnerability_component.call("activate")

		if _knockback_component != null and _knockback_component.is_enabled:
			_knockback_component.call("apply_hit", hit)

		if _hit_stun_component != null and _hit_stun_component.is_enabled:
			_hit_stun_component.call("apply_hit", hit)

		hit_received.emit(hit, applied_damage)

	return applied_damage


func _apply_damage_modifiers(hit: HitData) -> float:
	var damage := hit.damage

	for component: Component in actor.get_components():
		if component is DamageModifierComponent and component.is_enabled:
			damage = (component as DamageModifierComponent).modify_damage(
				hit,
				damage
			)

			if damage <= 0.0:
				return 0.0

	return damage
