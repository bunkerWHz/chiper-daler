extends Component
class_name AnimationComponent

var _sprite: AnimatedSprite2D
var _movement_component: MovementComponent
var _facing_component: FacingComponent
var _attack_component: AttackComponent
var _guard_component: GuardComponent
var _current_state: AnimationState.Type = AnimationState.Type.IDLE
var _is_attack_animation_playing: bool = false


func on_initialize() -> void:
	_movement_component = actor.get_component(MovementComponent) as MovementComponent

	if _movement_component == null or not _movement_component.is_enabled:
		push_error("AnimationComponent requires an enabled MovementComponent")
		disable()
		return

	_facing_component = actor.get_component(FacingComponent) as FacingComponent

	if _facing_component == null or not _facing_component.is_enabled:
		push_error("AnimationComponent requires an enabled FacingComponent")
		disable()
		return

	if not _movement_component.state_changed.is_connected(
		_on_movement_state_changed
	):
		_movement_component.state_changed.connect(_on_movement_state_changed)

	if not _facing_component.facing_changed.is_connected(_on_facing_changed):
		_facing_component.facing_changed.connect(_on_facing_changed)

	_attack_component = actor.get_component(AttackComponent) as AttackComponent

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and not _attack_component.attack_started.is_connected(_on_attack_started)
	):
		_attack_component.attack_started.connect(_on_attack_started)

	_guard_component = actor.get_component(GuardComponent) as GuardComponent

	if _guard_component != null and _guard_component.is_enabled:
		if not _guard_component.guard_started.is_connected(_on_guard_started):
			_guard_component.guard_started.connect(_on_guard_started)

		if not _guard_component.guard_finished.is_connected(_on_guard_finished):
			_guard_component.guard_finished.connect(_on_guard_finished)
		
func _ready() -> void:
	_sprite = actor.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D

	if _sprite == null:
		push_error("AnimationComponent requires AnimatedSprite2D")
		disable()
		return

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and not _sprite.sprite_frames.has_animation(&"attack")
	):
		push_error("AnimationComponent requires an attack animation")
		disable()
		return

	if (
		_guard_component != null
		and _guard_component.is_enabled
		and not _sprite.sprite_frames.has_animation(&"guard")
	):
		push_error("AnimationComponent requires a guard animation")
		disable()
		return

	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)

	if not is_enabled:
		return

	_apply_movement_state(_movement_component.get_state(), true)
	_apply_facing(_facing_component.get_direction())
		
func _change_state(
	new_state: AnimationState.Type,
	force: bool = false
) -> void:
	if _current_state == new_state and not force:
		return

	_current_state = new_state

	match _current_state:
		AnimationState.Type.IDLE:
			_play_animation("idle")

		AnimationState.Type.RUN:
			_play_animation("run")

		AnimationState.Type.JUMP:
			_play_animation("jump")

		AnimationState.Type.FALL:
			_play_animation("fall")

		AnimationState.Type.ATTACK:
			_play_animation("attack")

		AnimationState.Type.GUARD:
			_play_animation("guard")
	
func _play_animation(animation_name: StringName) -> void:
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)

func _get_animation_state(
	movement_state: MovementState.Type
) -> AnimationState.Type:

	match movement_state:
		MovementState.Type.IDLE:
			return AnimationState.Type.IDLE

		MovementState.Type.RUN:
			return AnimationState.Type.RUN

		MovementState.Type.JUMP:
			return AnimationState.Type.JUMP

		MovementState.Type.FALL:
			return AnimationState.Type.FALL

	return AnimationState.Type.IDLE


func _on_movement_state_changed(
	_previous_state: MovementState.Type,
	current_movement_state: MovementState.Type
) -> void:
	if not is_enabled:
		return

	if _is_attack_animation_playing:
		return

	if _guard_component != null and _guard_component.is_guarding():
		return

	_apply_movement_state(current_movement_state)


func _on_facing_changed(
	_previous_direction: FacingComponent.Direction,
	current_direction: FacingComponent.Direction
) -> void:
	if not is_enabled:
		return

	_apply_facing(current_direction)


func _apply_facing(direction: FacingComponent.Direction) -> void:
	_sprite.flip_h = direction == FacingComponent.Direction.LEFT


func _apply_movement_state(
	movement_state: MovementState.Type,
	force: bool = false
) -> void:
	var animation_state := _get_animation_state(movement_state)
	_change_state(animation_state, force)


func get_state() -> AnimationState.Type:
	return _current_state


func _on_attack_started() -> void:
	if not is_enabled:
		return

	_is_attack_animation_playing = true
	_change_state(AnimationState.Type.ATTACK, true)


func _on_animation_finished() -> void:
	if _current_state != AnimationState.Type.ATTACK:
		return

	_is_attack_animation_playing = false
	_apply_movement_state(_movement_component.get_state(), true)


func _on_guard_started() -> void:
	if not is_enabled or _is_attack_animation_playing:
		return

	_change_state(AnimationState.Type.GUARD, true)


func _on_guard_finished() -> void:
	if not is_enabled or _is_attack_animation_playing:
		return

	_apply_movement_state(_movement_component.get_state(), true)
