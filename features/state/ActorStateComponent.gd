extends Component
class_name ActorStateComponent

signal state_changed(
	previous_state: ActorState.Behavior,
	current_state: ActorState.Behavior
)
signal statuses_changed(previous_statuses: int, current_statuses: int)

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

var _state: ActorState.Behavior = ActorState.Behavior.IDLE
var _statuses: int = ActorState.Status.NONE


func on_initialize() -> void:
	_movement_component = actor.get_component(MovementComponent) as MovementComponent
	_body_component = actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	_attack_component = actor.get_component(AttackComponent) as AttackComponent
	_guard_component = actor.get_component(GuardComponent) as GuardComponent
	_interaction_component = actor.get_component(InteractionComponent) as InteractionComponent
	_item_use_component = actor.get_component(ItemUseComponent) as ItemUseComponent
	_throwing_component = actor.get_component(ThrowingComponent) as ThrowingComponent
	_ranged_weapon_component = actor.get_component(RangedWeaponComponent) as RangedWeaponComponent
	_magic_component = actor.get_component(MagicComponent) as MagicComponent
	_hit_reaction_component = actor.get_component(HitReactionComponent) as HitReactionComponent
	_hit_stun_component = actor.get_component(HitStunComponent) as HitStunComponent
	_health_component = actor.get_component(HealthComponent) as HealthComponent
	_respawn_component = actor.get_component(PlayerRespawnComponent) as PlayerRespawnComponent
	_rest_component = actor.get_component(RestComponent) as RestComponent
	_progression_component = actor.get_component(ProgressionComponent) as ProgressionComponent
	_status_effect_component = actor.get_component(StatusEffectComponent) as StatusEffectComponent
	refresh_state()


func _process(_delta: float) -> void:
	refresh_state()


func refresh_state() -> void:
	_set_state(_resolve_state())
	_set_statuses(_resolve_statuses())


func get_state() -> ActorState.Behavior:
	return _state


func get_statuses() -> int:
	return _statuses


func has_status(status: ActorState.Status) -> bool:
	return ActorState.has_status(_statuses, status)


func get_active_state_names() -> PackedStringArray:
	var names := PackedStringArray([ActorState.get_behavior_name(_state)])
	names.append_array(ActorState.get_status_names(_statuses))
	return names


func should_disable_on_actor_death() -> bool:
	return false


func _resolve_state() -> ActorState.Behavior:
	if (
		_respawn_component != null
		and _respawn_component.is_enabled
		and _respawn_component.is_restart_scheduled()
	):
		return ActorState.Behavior.RESPAWNING
	if _health_component != null and _health_component.is_dead():
		return ActorState.Behavior.DEAD
	if _hit_stun_component != null and _hit_stun_component.is_enabled:
		if _hit_stun_component.is_knocked_down():
			return ActorState.Behavior.KNOCKED_DOWN
		if _hit_stun_component.is_stunned():
			return ActorState.Behavior.STUNNED
	if _rest_component != null and _rest_component.is_enabled:
		if _rest_component.is_resting():
			return ActorState.Behavior.RESTING
	if _attack_component != null and _attack_component.is_enabled:
		if _attack_component.is_critical_attacking():
			return ActorState.Behavior.CRITICAL_ATTACK
		if _attack_component.is_landing_recovery():
			return ActorState.Behavior.GROUND_ATTACK_RECOVERY
		if _attack_component.is_charging_heavy_attack():
			return (
				ActorState.Behavior.AIR_ATTACK_WINDUP
				if _attack_component.is_air_attack()
				else ActorState.Behavior.GROUND_ATTACK_WINDUP
			)
		if _attack_component.is_attacking():
			if _attack_component.is_air_attack():
				return (
					ActorState.Behavior.AIR_HEAVY_ATTACK
					if _attack_component.is_heavy_attacking()
					else ActorState.Behavior.AIR_LIGHT_ATTACK
				)
			return (
				ActorState.Behavior.GROUND_HEAVY_ATTACK
				if _attack_component.is_heavy_attacking()
				else ActorState.Behavior.GROUND_LIGHT_ATTACK
			)
	if _guard_component != null and _guard_component.is_enabled:
		if _guard_component.is_parrying():
			return ActorState.Behavior.PARRYING
		if _guard_component.is_guarding():
			return ActorState.Behavior.BLOCKING
	if _item_use_component != null and _item_use_component.is_enabled:
		if _item_use_component.is_using_item():
			return ActorState.Behavior.USING_ITEM
	if _throwing_component != null and _throwing_component.is_enabled:
		match _throwing_component.get_phase():
			ThrowingComponent.Phase.AIM:
				return ActorState.Behavior.THROWING_AIM
			ThrowingComponent.Phase.ACTION:
				return ActorState.Behavior.THROWING_ACTION
			ThrowingComponent.Phase.RECOVERY:
				return ActorState.Behavior.THROWING_RECOVERY
	if _ranged_weapon_component != null and _ranged_weapon_component.is_enabled:
		match _ranged_weapon_component.get_phase():
			RangedWeaponComponent.Phase.BOW_AIM:
				return ActorState.Behavior.AIM_BOW
			RangedWeaponComponent.Phase.BOW_LOOSE:
				return ActorState.Behavior.LOOSE_ARROW
			RangedWeaponComponent.Phase.CROSSBOW_AIM:
				return ActorState.Behavior.AIM_CROSSBOW
			RangedWeaponComponent.Phase.CROSSBOW_FIRE:
				return ActorState.Behavior.FIRE_CROSSBOW
	if _magic_component != null and _magic_component.is_enabled:
		match _magic_component.get_phase():
			MagicComponent.Phase.CHARGE:
				return ActorState.Behavior.MAGIC_CHARGE
			MagicComponent.Phase.CAST:
				return ActorState.Behavior.MAGIC_CAST
			MagicComponent.Phase.RECOVERY:
				return ActorState.Behavior.MAGIC_RECOVERY
			MagicComponent.Phase.CHANNELING:
				return ActorState.Behavior.MAGIC_CHANNELING
	if _interaction_component != null and _interaction_component.is_enabled:
		match _interaction_component.get_phase():
			InteractionComponent.Phase.START:
				return ActorState.Behavior.INTERACTING_START
			InteractionComponent.Phase.PROGRESS:
				return ActorState.Behavior.INTERACTING_PROGRESS
			InteractionComponent.Phase.END:
				return ActorState.Behavior.INTERACTING_END
	if _progression_component != null and _progression_component.is_enabled:
		if _progression_component.is_leveling_up():
			return ActorState.Behavior.LEVEL_UP
	if _hit_reaction_component != null and _hit_reaction_component.is_enabled:
		if _hit_reaction_component.is_reacting():
			return ActorState.Behavior.HIT
	return _resolve_movement_state()


func _resolve_movement_state() -> ActorState.Behavior:
	if _movement_component != null and _movement_component.is_enabled:
		match _movement_component.get_state():
			MovementState.Type.RUN:
				return ActorState.Behavior.RUN
			MovementState.Type.JUMP:
				return ActorState.Behavior.JUMP
			MovementState.Type.DOUBLE_JUMP:
				return ActorState.Behavior.DOUBLE_JUMP
			MovementState.Type.WALL_JUMP:
				return ActorState.Behavior.WALL_JUMP
			MovementState.Type.DODGE:
				return ActorState.Behavior.DODGE
			MovementState.Type.CLIMB_IDLE:
				return ActorState.Behavior.CLIMB_IDLE
			MovementState.Type.CLIMB_UP:
				return ActorState.Behavior.CLIMB_UP
			MovementState.Type.CLIMB_DOWN:
				return ActorState.Behavior.CLIMB_DOWN
			MovementState.Type.FALL:
				return ActorState.Behavior.FALL
			_:
				return ActorState.Behavior.IDLE
	if _body_component == null or not _body_component.is_enabled:
		return ActorState.Behavior.IDLE
	var velocity := _body_component.get_velocity()
	if not _body_component.is_on_floor():
		return ActorState.Behavior.JUMP if velocity.y < 0.0 else ActorState.Behavior.FALL
	if not is_zero_approx(velocity.x):
		return ActorState.Behavior.RUN
	return ActorState.Behavior.IDLE


func _resolve_statuses() -> int:
	var result: int = int(ActorState.Status.NONE)
	if _status_effect_component != null and _status_effect_component.is_enabled:
		if _status_effect_component.has_debuff():
			result |= int(ActorState.Status.DEBUFFED)
		if _status_effect_component.has_buff():
			result |= int(ActorState.Status.BUFFED)
	return result


func _set_state(new_state: ActorState.Behavior) -> void:
	if new_state == _state:
		return
	var previous_state := _state
	_state = new_state
	state_changed.emit(previous_state, _state)


func _set_statuses(new_statuses: int) -> void:
	if new_statuses == _statuses:
		return
	var previous_statuses := _statuses
	_statuses = new_statuses
	statuses_changed.emit(previous_statuses, _statuses)
