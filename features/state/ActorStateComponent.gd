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
var _interaction_component: InteractionComponent
var _item_use_component: ItemUseComponent
var _throwing_component: ThrowingComponent
var _ranged_weapon_component: RangedWeaponComponent
var _magic_component: MagicComponent
var _hit_reaction_component: HitReactionComponent
var _hit_stun_component: HitStunComponent
var _health_component: HealthComponent
var _respawn_component: PlayerRespawnComponent
var _rest_component: RestComponent
var _progression_component: ProgressionComponent
var _status_effect_component: StatusEffectComponent

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
	_interaction_component = (
		actor.get_component(InteractionComponent) as InteractionComponent
	)
	_item_use_component = (
		actor.get_component(ItemUseComponent) as ItemUseComponent
	)
	_throwing_component = (
		actor.get_component(ThrowingComponent) as ThrowingComponent
	)
	_ranged_weapon_component = (
		actor.get_component(RangedWeaponComponent) as RangedWeaponComponent
	)
	_magic_component = actor.get_component(MagicComponent) as MagicComponent
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
	_rest_component = actor.get_component(RestComponent) as RestComponent
	_progression_component = (
		actor.get_component(ProgressionComponent) as ProgressionComponent
	)
	_status_effect_component = (
		actor.get_component(StatusEffectComponent) as StatusEffectComponent
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
			MovementState.Type.WALL_JUMP:
				return ActorState.Locomotion.WALL_JUMPING
			MovementState.Type.DODGE:
				return ActorState.Locomotion.DODGING
			MovementState.Type.CLIMB_IDLE:
				return ActorState.Locomotion.CLIMBING_IDLE
			MovementState.Type.CLIMB_UP:
				return ActorState.Locomotion.CLIMBING_UP
			MovementState.Type.CLIMB_DOWN:
				return ActorState.Locomotion.CLIMBING_DOWN
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
		and (
			_attack_component.is_heavy_attacking()
			or _attack_component.is_charging_heavy_attack()
		)
	):
		return ActorState.Action.HEAVY_ATTACK

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.is_attacking()
	):
		return ActorState.Action.LIGHT_ATTACK

	if (
		_guard_component != null
		and _guard_component.is_enabled
		and _guard_component.is_parrying()
	):
		return ActorState.Action.PARRYING

	if (
		_guard_component != null
		and _guard_component.is_enabled
		and _guard_component.is_guarding()
	):
		return ActorState.Action.BLOCKING

	if (
		_item_use_component != null
		and _item_use_component.is_enabled
		and _item_use_component.is_using_item()
	):
		return ActorState.Action.USING_ITEM

	if _throwing_component != null and _throwing_component.is_enabled:
		match _throwing_component.get_phase():
			ThrowingComponent.Phase.AIM:
				return ActorState.Action.THROWING_AIM
			ThrowingComponent.Phase.ACTION:
				return ActorState.Action.THROWING_ACTION
			ThrowingComponent.Phase.RECOVERY:
				return ActorState.Action.THROWING_RECOVERY

	if _ranged_weapon_component != null and _ranged_weapon_component.is_enabled:
		match _ranged_weapon_component.get_phase():
			RangedWeaponComponent.Phase.BOW_AIM:
				return ActorState.Action.AIM_BOW
			RangedWeaponComponent.Phase.BOW_LOOSE:
				return ActorState.Action.LOOSE_ARROW
			RangedWeaponComponent.Phase.CROSSBOW_AIM:
				return ActorState.Action.AIM_CROSSBOW
			RangedWeaponComponent.Phase.CROSSBOW_FIRE:
				return ActorState.Action.FIRE_CROSSBOW

	if _magic_component != null and _magic_component.is_enabled:
		match _magic_component.get_phase():
			MagicComponent.Phase.CHARGE:
				return ActorState.Action.MAGIC_CHARGE
			MagicComponent.Phase.CAST:
				return ActorState.Action.MAGIC_CAST
			MagicComponent.Phase.RECOVERY:
				return ActorState.Action.MAGIC_RECOVERY
			MagicComponent.Phase.CHANNELING:
				return ActorState.Action.MAGIC_CHANNELING

	if (
		_interaction_component != null
		and _interaction_component.is_enabled
	):
		match _interaction_component.get_phase():
			InteractionComponent.Phase.START:
				return ActorState.Action.INTERACTING_START
			InteractionComponent.Phase.PROGRESS:
				return ActorState.Action.INTERACTING_PROGRESS
			InteractionComponent.Phase.END:
				return ActorState.Action.INTERACTING_END

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

	if (
		_hit_stun_component != null
		and _hit_stun_component.is_enabled
		and _hit_stun_component.is_knocked_down()
	):
		result |= ActorState.Condition.KNOCKED_DOWN

	if _health_component != null and _health_component.is_dead():
		result |= ActorState.Condition.DEAD

	if (
		_respawn_component != null
		and _respawn_component.is_restart_scheduled()
	):
		result |= ActorState.Condition.RESPAWNING

	if (
		_rest_component != null
		and _rest_component.is_enabled
		and _rest_component.is_resting()
	):
		result |= ActorState.Condition.RESTING

	if (
		_progression_component != null
		and _progression_component.is_enabled
		and _progression_component.is_leveling_up()
	):
		result |= ActorState.Condition.LEVEL_UP

	if (
		_status_effect_component != null
		and _status_effect_component.is_enabled
	):
		if _status_effect_component.has_debuff():
			result |= ActorState.Condition.DEBUFFED
		if _status_effect_component.has_buff():
			result |= ActorState.Condition.BUFFED

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
