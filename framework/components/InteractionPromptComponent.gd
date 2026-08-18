extends Component
class_name InteractionPromptComponent

@export var prompt: Label

var interaction_component: InteractionComponent


func _ready() -> void:
	interaction_component = (
		actor.get_component(InteractionComponent)
		as InteractionComponent
	)

	if interaction_component == null:
		push_error("InteractionPromptComponent requires InteractionComponent")
		return

	if prompt == null:
		push_error("InteractionPromptComponent requires Label")
		return

	prompt.visible = false


func _process(_delta: float) -> void:
	if interaction_component == null:
		return

	var target := interaction_component.get_target()

	if target == null:
		prompt.visible = false
		return

	prompt.visible = true
	prompt.text = target.interaction_name
