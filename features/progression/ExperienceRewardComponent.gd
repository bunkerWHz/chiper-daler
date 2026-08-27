extends Component
class_name ExperienceRewardComponent

signal experience_awarded(recipient: Actor, amount: int)

@export var config: ExperienceRewardConfig

var _health: HealthComponent
var _hurtbox: HurtboxComponent
var _was_awarded: bool = false


func on_initialize() -> void:
	if config == null or config.amount <= 0:
		push_error("ExperienceRewardComponent requires a valid config")
		disable()
		return

	_health = actor.get_component(HealthComponent) as HealthComponent
	_hurtbox = actor.get_component(HurtboxComponent) as HurtboxComponent
	if (
		_health == null
		or not _health.is_enabled
		or _hurtbox == null
		or not _hurtbox.is_enabled
	):
		push_error(
			"ExperienceRewardComponent requires enabled health and hurtbox"
		)
		disable()
		return

	_hurtbox.hit_received.connect(_on_hit_received)


func should_disable_on_actor_death() -> bool:
	return false


func _on_hit_received(hit: HitData, applied_damage: float) -> void:
	if (
		_was_awarded
		or applied_damage <= 0.0
		or not _health.is_dead()
		or hit == null
		or hit.source_actor == null
	):
		return

	var progression := (
		hit.source_actor.get_component(ProgressionComponent)
		as ProgressionComponent
	)
	if progression == null or not progression.is_enabled:
		return

	_was_awarded = true
	progression.gain_experience(config.amount)
	experience_awarded.emit(hit.source_actor, config.amount)
