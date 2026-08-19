extends Component
class_name InteractionPromptComponent

var prompt: Label
var camera: Camera2D
var interaction_component: InteractionComponent


func _ready() -> void:

	var camera_component: CameraComponent = (
	actor.get_component(CameraComponent)
	as CameraComponent
	)

	if camera_component == null:
		push_error("InteractionPromptComponent requires CameraComponent")
		return

	camera = camera_component.camera

	if camera == null:
		push_error("InteractionPromptComponent requires Camera2D")
		return
	interaction_component = (
		actor.get_component(InteractionComponent)
		as InteractionComponent
	)

	if interaction_component == null:
		push_error("InteractionPromptComponent requires InteractionComponent")
		return


func _process(_delta: float) -> void:
	if interaction_component == null:
		return
	if not _find_prompt():
		return

	var target := interaction_component.get_target()

	if target == null:
		prompt.visible = false
		return

	prompt.visible = true
	prompt.text = target.interaction_name
	var world_position := target.actor.global_position
	prompt.position = camera.get_screen_center_position() + (
		world_position - camera.global_position )


func _find_prompt() -> bool:
	if prompt != null:
		return true

	prompt = get_tree().get_first_node_in_group(
		"interaction_prompt"
	) as Label

	return prompt != null
