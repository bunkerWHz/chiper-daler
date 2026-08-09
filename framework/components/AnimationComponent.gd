extends Component
class_name AnimationComponent

@export var sprite: AnimatedSprite2D
var movement_component: MovementComponent

func _ready() -> void:
	movement_component = actor.get_component(MovementComponent)
	if movement_component == null:
		push_error("AnimationComponent requires MovementComponent")
		
		
func _update_facing() -> void:
	var direction := movement_component.get_move_direction()

	if direction > 0.0:
		sprite.flip_h = false
	elif direction < 0.0:
		sprite.flip_h = true

func _process(_delta: float) -> void:
	if movement_component == null:
		return
	_update_facing()
	
	var state := movement_component.get_state()

	match state:
		MovementState.Type.IDLE:
			_update_idle()

		MovementState.Type.RUN:
			_update_run()

		MovementState.Type.JUMP:
			_update_jump()

		MovementState.Type.FALL:
			_update_fall()

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
