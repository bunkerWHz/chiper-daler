extends Component
class_name AnimationComponent

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"run",
	&"jump",
	&"fall",
	&"attack",
	&"guard",
]

var _sprite: AnimatedSprite2D
var _animation_player: AnimationPlayer
var _actor_state_component: ActorStateComponent
var _facing_component: FacingComponent
var _current_state: ActorState.Behavior = ActorState.Behavior.IDLE


func on_initialize() -> void:
	_actor_state_component = (
		actor.get_component(ActorStateComponent) as ActorStateComponent
	)
	if _actor_state_component == null or not _actor_state_component.is_enabled:
		push_error("AnimationComponent requires an enabled ActorStateComponent")
		disable()
		return

	_facing_component = actor.get_component(FacingComponent) as FacingComponent
	if _facing_component == null or not _facing_component.is_enabled:
		push_error("AnimationComponent requires an enabled FacingComponent")
		disable()
		return

	if not _actor_state_component.state_changed.is_connected(_on_state_changed):
		_actor_state_component.state_changed.connect(_on_state_changed)
	if not _facing_component.facing_changed.is_connected(_on_facing_changed):
		_facing_component.facing_changed.connect(_on_facing_changed)


func _ready() -> void:
	if not is_enabled:
		return

	_sprite = actor.get_node_or_null("_Visual/AnimatedSprite2D") as AnimatedSprite2D
	if _sprite == null or _sprite.sprite_frames == null:
		push_error("AnimationComponent requires AnimatedSprite2D with SpriteFrames")
		disable()
		return
	_animation_player = actor.get_node_or_null(
		"_Visual/AnimationPlayer"
	) as AnimationPlayer
	if _animation_player == null:
		push_error("AnimationComponent requires AnimationPlayer")
		disable()
		return

	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if (
			not _sprite.sprite_frames.has_animation(animation_name)
			or not _animation_player.has_animation(animation_name)
		):
			push_error(
				"AnimationComponent requires a '%s' animation" % animation_name
			)
			disable()
			return

	_apply_state(_actor_state_component.get_state(), true)
	_apply_facing(_facing_component.get_direction())


func get_state() -> ActorState.Behavior:
	return _current_state


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func _on_state_changed(
	_previous_state: ActorState.Behavior,
	current_state: ActorState.Behavior
) -> void:
	if not is_enabled:
		return
	if _sprite == null:
		_current_state = current_state
		return
	_apply_state(current_state)


func _on_facing_changed(
	_previous_direction: FacingComponent.Direction,
	current_direction: FacingComponent.Direction
) -> void:
	if is_enabled and _sprite != null:
		_apply_facing(current_direction)


func _apply_state(
	new_state: ActorState.Behavior,
	force: bool = false
) -> void:
	if _current_state == new_state and not force:
		return

	_current_state = new_state
	_play_animation(_get_animation_name(new_state))


func _apply_facing(direction: FacingComponent.Direction) -> void:
	_sprite.flip_h = direction == FacingComponent.Direction.LEFT


func _play_animation(animation_name: StringName) -> void:
	if _animation_player.has_animation(animation_name):
		if animation_name == &"equipment_swap":
			var swap := actor.get_component(EquipmentSwapComponent) as EquipmentSwapComponent
			if swap != null and swap.is_swapping() and swap.get_duration() > 0.0:
				var clip_duration := _animation_player.get_animation(animation_name).length
				_animation_player.play(animation_name, -1.0, clip_duration / swap.get_duration())
				return
		_animation_player.play(animation_name)


func _get_animation_name(state: ActorState.Behavior) -> StringName:
	if state == ActorState.Behavior.EQUIPMENT_SWAP:
		return &"equipment_swap" if _animation_player != null and _animation_player.has_animation(&"equipment_swap") else &"idle"
	if state in [
		ActorState.Behavior.RUN,
		ActorState.Behavior.DODGE,
		ActorState.Behavior.CLIMB_UP,
		ActorState.Behavior.CLIMB_DOWN,
	]:
		return &"run"
	if state in [
		ActorState.Behavior.JUMP,
		ActorState.Behavior.DOUBLE_JUMP,
		ActorState.Behavior.WALL_JUMP,
	]:
		return &"jump"
	if state == ActorState.Behavior.FALL:
		return &"fall"
	if state in [
		ActorState.Behavior.GROUND_ATTACK_WINDUP,
		ActorState.Behavior.GROUND_LIGHT_ATTACK,
		ActorState.Behavior.GROUND_HEAVY_ATTACK,
		ActorState.Behavior.AIR_ATTACK_WINDUP,
		ActorState.Behavior.AIR_LIGHT_ATTACK,
		ActorState.Behavior.AIR_HEAVY_ATTACK,
		ActorState.Behavior.GROUND_ATTACK_RECOVERY,
		ActorState.Behavior.USING_ITEM,
		ActorState.Behavior.THROWING_AIM,
		ActorState.Behavior.THROWING_ACTION,
		ActorState.Behavior.THROWING_RECOVERY,
		ActorState.Behavior.AIM_BOW,
		ActorState.Behavior.LOOSE_ARROW,
		ActorState.Behavior.AIM_CROSSBOW,
		ActorState.Behavior.FIRE_CROSSBOW,
		ActorState.Behavior.MAGIC_CHARGE,
		ActorState.Behavior.MAGIC_CAST,
		ActorState.Behavior.MAGIC_RECOVERY,
		ActorState.Behavior.MAGIC_CHANNELING,
		ActorState.Behavior.CRITICAL_ATTACK,
	]:
		return &"attack"
	if state in [
		ActorState.Behavior.BLOCKING,
		ActorState.Behavior.PARRYING,
	]:
		return &"guard"
	return &"idle"
