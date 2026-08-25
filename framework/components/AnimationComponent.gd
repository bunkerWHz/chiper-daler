extends Component
class_name AnimationComponent

var _sprite: AnimatedSprite2D
var _movement_component: MovementComponent
var _facing_component: FacingComponent
var _current_state: AnimationState.Type = AnimationState.Type.IDLE


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
		
func _ready() -> void:
	_sprite = actor.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D

	if _sprite == null:
		push_error("AnimationComponent requires AnimatedSprite2D")
		disable()
		return

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
