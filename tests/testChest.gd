extends Actor

@export var save_id: String = ""

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
	add_to_group(&"persistent_world")
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
	if is_inside_tree():
		get_node("/root/GameFlow").saves.set_flag(self, save_id, "opened", true)
	print("Chest opened")


func restore_persistent_state() -> void:
	if get_node("/root/GameFlow").saves.get_flag(self, save_id, "opened"):
		state = State.OPEN
		interactable.disable_interaction()
