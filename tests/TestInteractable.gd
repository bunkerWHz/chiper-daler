extends Actor
class_name TestInteractable

func _ready() -> void:
	var interactable := get_component(InteractableComponent)

	if interactable:
		interactable.interact()
