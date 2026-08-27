extends Component
class_name HitStunComponent

signal hit_stun_started
signal hit_stun_finished

@export var config: HitStunConfig

var _timer: float = 0.0
var _suspended_components: Array[Component] = []


func on_initialize() -> void:
	if config == null:
		push_error("HitStunComponent requires HitStunConfig")
		disable()
		return

	if config.duration <= 0.0:
		push_error("HitStunConfig duration must be greater than zero")
		disable()


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return

	_timer = maxf(_timer - delta, 0.0)

	if _timer == 0.0:
		_finish_hit_stun()


func apply_hit(hit: HitData) -> bool:
	if not is_enabled or hit == null or hit.damage <= 0.0:
		return false

	_suspend_components()
	_timer = config.duration
	hit_stun_started.emit()
	return true


func is_stunned() -> bool:
	return _timer > 0.0


func take_suspension_ownership(component: Component) -> void:
	if component == null or _suspended_components.has(component):
		return

	if component.is_enabled:
		component.disable()

	_suspended_components.append(component)


func disable() -> void:
	_timer = 0.0
	_suspended_components.clear()
	super.disable()


func _suspend_components() -> void:
	if not _suspended_components.is_empty():
		return

	var attack := actor.get_component(AttackComponent)
	var enemy_attack := actor.get_component(EnemyAttackComponent)
	var guard := actor.get_component(GuardComponent)
	var player_movement := actor.get_component(MovementComponent)
	var dodge := actor.get_component(DodgeComponent)
	var climbing := actor.get_component(ClimbingComponent)
	var item_use := actor.get_component(ItemUseComponent)
	var throwing := actor.get_component(ThrowingComponent)
	var enemy_movement := actor.get_component(EnemyMovementComponent)

	for component: Component in [
		attack,
		enemy_attack,
		guard,
		player_movement,
		dodge,
		climbing,
		item_use,
		throwing,
		enemy_movement,
	]:
		if component != null and component.is_enabled:
			take_suspension_ownership(component)


func _finish_hit_stun() -> void:
	for component: Component in _suspended_components:
		if is_instance_valid(component):
			component.enable()

	_suspended_components.clear()
	hit_stun_finished.emit()
