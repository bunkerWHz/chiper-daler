extends Component
class_name AnimationComponent

@export var sprite: AnimatedSprite2D
var movement_component: MovementComponent

func _ready() -> void:
	movement_component = actor.get_component(MovementComponent)
	if movement_component == null:
		push_error("AnimationComponent requires MovementComponent")

func _process(_delta: float) -> void:
	if movement_component == null:
		return

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
	pass


func _update_fall() -> void:
	pass
