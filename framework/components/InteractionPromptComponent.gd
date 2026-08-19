extends Component
class_name InteractionPromptComponent

@export var offset: Vector2 = Vector2(0.0, -32.0)

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

	if target == null or target.actor == null:
		prompt.visible = false
		return

	var cam := _get_camera()
	if cam == null:
		prompt.visible = false
		return

	prompt.visible = true
	prompt.text = target.interaction_name
	prompt.reset_size()

	var world_pos: Vector2 = target.actor.global_position + offset
	var screen_pos: Vector2 = world_to_screen(world_pos, cam)

	prompt.global_position = screen_pos - (prompt.size * 0.5)


func world_to_screen(world_pos: Vector2, cam: Camera2D) -> Vector2:
	var viewport_size: Vector2 = cam.get_viewport_rect().size
	var screen_center: Vector2 = viewport_size * 0.5
	var camera_center: Vector2 = cam.get_screen_center_position()
	var offset_from_center: Vector2 = world_pos - camera_center

	if not cam.ignore_rotation:
		offset_from_center = offset_from_center.rotated(cam.global_rotation)

	var screen_pos: Vector2 = screen_center + (offset_from_center * cam.zoom)

	var canvas_transform: Transform2D = prompt.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos


func _get_camera() -> Camera2D:
	if camera != null:
		return camera

	var camera_component := (
		actor.get_component(CameraComponent)
		as CameraComponent
	)
	if camera_component != null:
		camera = camera_component.camera

	return camera


func _find_prompt() -> bool:
	if prompt != null:
		return true

	prompt = get_tree().get_first_node_in_group(
		"interaction_prompt"
	) as Label

	return prompt != null
