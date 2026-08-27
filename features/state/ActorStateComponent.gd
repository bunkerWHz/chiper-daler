extends Component
class_name ActorStateComponent

signal locomotion_changed(
	previous_state: ActorState.Locomotion,
	current_state: ActorState.Locomotion
)
signal action_changed(
	previous_state: ActorState.Action,
	current_state: ActorState.Action
)
signal conditions_changed(previous_conditions: int, current_conditions: int)

var _movement_component: MovementComponent
var _body_component: CharacterBodyComponent
var _attack_component: AttackComponent
var _guard_component: GuardComponent
var _hit_reaction_component: HitReactionComponent
var _hit_stun_component: HitStunComponent
var _health_component: HealthComponent
var _respawn_component: PlayerRespawnComponent

var _locomotion: ActorState.Locomotion = ActorState.Locomotion.IDLE
var _action: ActorState.Action = ActorState.Action.NONE
var _conditions: int = ActorState.Condition.NONE


func on_initialize() -> void:
	_movement_component = (
		actor.get_component(MovementComponent) as MovementComponent
	)
	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)
	_attack_component = (
		actor.get_component(AttackComponent) as AttackComponent
	)
	_guard_component = actor.get_component(GuardComponent) as GuardComponent
	_hit_reaction_component = (
		actor.get_component(HitReactionComponent)
		as HitReactionComponent
	)
	_hit_stun_component = (
		actor.get_component(HitStunComponent) as HitStunComponent
	)
	_health_component = (
		actor.get_component(HealthComponent) as HealthComponent
	)
	_respawn_component = (
		actor.get_component(PlayerRespawnComponent)
		as PlayerRespawnComponent
	)
	refresh_state()


func _process(_delta: float) -> void:
	refresh_state()


func refresh_state() -> void:
	_set_locomotion(_resolve_locomotion())
	_set_action(_resolve_action())
	_set_conditions(_resolve_conditions())


func get_locomotion() -> ActorState.Locomotion:
	return _locomotion


func get_action() -> ActorState.Action:
	return _action


func get_conditions() -> int:
	return _conditions


func has_condition(condition: ActorState.Condition) -> bool:
	return ActorState.has_condition(_conditions, condition)


func get_active_state_names() -> PackedStringArray:
	var names := PackedStringArray([
		ActorState.get_locomotion_name(_locomotion),
	])

	if _action != ActorState.Action.NONE:
		names.append(ActorState.get_action_name(_action))

	names.append_array(ActorState.get_condition_names(_conditions))
	return names


func should_disable_on_actor_death() -> bool:
	return false


func _resolve_locomotion() -> ActorState.Locomotion:
	if _movement_component != null and _movement_component.is_enabled:
		match _movement_component.get_state():
			MovementState.Type.RUN:
				return ActorState.Locomotion.WALKING
			MovementState.Type.JUMP:
				return ActorState.Locomotion.JUMPING
			MovementState.Type.DOUBLE_JUMP:
				return ActorState.Locomotion.DOUBLE_JUMPING
			MovementState.Type.FALL:
				return ActorState.Locomotion.FALLING
			_:
				return ActorState.Locomotion.IDLE

	if _body_component == null or not _body_component.is_enabled:
		return ActorState.Locomotion.IDLE

	var velocity := _body_component.get_velocity()

	if not _body_component.is_on_floor():
		return (
			ActorState.Locomotion.JUMPING
			if velocity.y < 0.0
			else ActorState.Locomotion.FALLING
		)

	if not is_zero_approx(velocity.x):
		return ActorState.Locomotion.WALKING

	return ActorState.Locomotion.IDLE


func _resolve_action() -> ActorState.Action:
	if (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.is_attacking()
	):
		return ActorState.Action.LIGHT_ATTACK

	if (
		_guard_component != null
		and _guard_component.is_enabled
		and _guard_component.is_guarding()
	):
		return ActorState.Action.BLOCKING

	return ActorState.Action.NONE


func _resolve_conditions() -> int:
	var result := ActorState.Condition.NONE

	if (
		_hit_reaction_component != null
		and _hit_reaction_component.is_enabled
		and _hit_reaction_component.is_reacting()
	):
		result |= ActorState.Condition.HIT

	if (
		_hit_stun_component != null
		and _hit_stun_component.is_enabled
		and _hit_stun_component.is_stunned()
	):
		result |= ActorState.Condition.STUNNED

	if _health_component != null and _health_component.is_dead():
		result |= ActorState.Condition.DEAD

	if (
		_respawn_component != null
		and _respawn_component.is_restart_scheduled()
	):
		result |= ActorState.Condition.RESPAWNING

	return result


func _set_locomotion(new_state: ActorState.Locomotion) -> void:
	if new_state == _locomotion:
		return

	var previous_state := _locomotion
	_locomotion = new_state
	locomotion_changed.emit(previous_state, _locomotion)


func _set_action(new_state: ActorState.Action) -> void:
	if new_state == _action:
		return

	var previous_state := _action
	_action = new_state
	action_changed.emit(previous_state, _action)


func _set_conditions(new_conditions: int) -> void:
	if new_conditions == _conditions:
		return

	var previous_conditions := _conditions
	_conditions = new_conditions
	conditions_changed.emit(previous_conditions, _conditions)
