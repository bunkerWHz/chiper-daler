extends Actor
class_name TestLever

@onready var interactable: InteractableComponent = (
	get_component(InteractableComponent)
	as InteractableComponent
)


func _ready() -> void:
	if interactable == null:
		push_error("TestLever requires InteractableComponent")
		return

	interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	print("Lever pulled")
