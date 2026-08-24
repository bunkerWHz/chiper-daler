extends Actor
class_name TestChest

@onready var interactable: InteractableComponent = (
	get_component(InteractableComponent)
	as InteractableComponent
)

enum State {
	CLOSED,
	OPEN
}

var state: State = State.CLOSED

func _ready() -> void:
	if interactable == null:
		push_error("TestChest requires InteractableComponent")
		return

	interactable.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	print("Interaction. Current state: ", State.keys()[state])
	if state == State.OPEN:
		return

	state = State.OPEN
	interactable.disable_interaction()
	print("Chest opened")
