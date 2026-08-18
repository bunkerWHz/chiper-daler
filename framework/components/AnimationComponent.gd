extends Component
class_name AnimationComponent

var sprite: AnimatedSprite2D
var movement_component: MovementComponent
var current_state: AnimationState.Type = AnimationState.Type.IDLE

func _ready() -> void:
	movement_component = actor.get_component(MovementComponent)

	if movement_component == null:
		push_error("AnimationComponent requires MovementComponent")
		return

	sprite = actor.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D

	if sprite == null:
		push_error("AnimationComponent requires AnimatedSprite2D")
		
func _update_facing() -> void:
	var direction := movement_component.get_move_direction()

	if direction > 0.0:
		sprite.flip_h = false
	elif direction < 0.0:
		sprite.flip_h = true
		
func _change_state(new_state: AnimationState.Type) -> void:
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		AnimationState.Type.IDLE:
			_play_animation("idle")

		AnimationState.Type.RUN:
			_play_animation("run")

		AnimationState.Type.JUMP:
			_play_animation("jump")

		AnimationState.Type.FALL:
			_play_animation("fall")
	
func _play_animation(animation_name: StringName) -> void:
	if sprite.animation != animation_name:
		sprite.play(animation_name)

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

func _process(_delta: float) -> void:
	if movement_component == null:
		return
	_update_facing()
	
	var movement_state := movement_component.get_state()
	var animation_state := _get_animation_state(movement_state)

	_change_state(animation_state)

func _update_idle() -> void:
	if sprite.animation != "idle":
		sprite.play("idle")


func _update_run() -> void:
	if sprite.animation != "run":
		sprite.play("run")


func _update_jump() -> void:
	if sprite.animation != "jump":
		sprite.play("jump")


func _update_fall() -> void:
	if sprite.animation != "fall":
		sprite.play("fall")
