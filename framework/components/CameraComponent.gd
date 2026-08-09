extends Component
class_name CameraComponent

var camera: Camera2D


func _ready() -> void:
	var body_component: CharacterBodyComponent = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if body_component == null:
		push_error("CameraComponent requires CharacterBodyComponent")
		return

	var body := body_component.get_body()

	if body == null:
		push_error("CameraComponent requires CharacterBody2D")
		return

	camera = body.get_node("Camera2D") as Camera2D

	if camera == null:
		push_error("CameraComponent requires Camera2D")
		return

	camera.enabled = true
