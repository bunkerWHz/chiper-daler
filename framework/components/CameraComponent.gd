extends Component
class_name CameraComponent

var camera: Camera2D
@export var config: CameraConfig

func _ready() -> void:
	if config == null:
		push_error("CameraComponent requires CameraConfig")
		disable()
		return
	
	var body_component: CharacterBodyComponent = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if body_component == null:
		push_error("CameraComponent requires CharacterBodyComponent")
		disable()
		return

	var body := body_component.get_body()

	if body == null:
		push_error("CameraComponent requires CharacterBody2D")
		disable()
		return

	camera = body.get_node("Camera2D") as Camera2D

	if camera == null:
		push_error("CameraComponent requires Camera2D")
		disable()
		return
	
	camera.enabled = true
	camera.position_smoothing_enabled = config.position_smoothing_enabled
	camera.position_smoothing_speed = config.position_smoothing_speed
	camera.zoom = config.zoom
	camera.limit_left = config.limit_left
	camera.limit_top = config.limit_top
	camera.limit_right = config.limit_right
	camera.limit_bottom = config.limit_bottom
