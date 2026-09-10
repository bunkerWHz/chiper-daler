extends Component
class_name InteractableComponent

@export var interaction_name: String = "Interact"
## Optional shape bounds used for interaction distance, including root scale.
@export_node_path("CollisionShape2D") var interaction_shape_path: NodePath

signal interacted
signal interacted_by(interactor: Actor)
var is_interactable: bool = true
var _interaction_shape: CollisionShape2D

func _ready() -> void:
	if not interaction_shape_path.is_empty():
		_interaction_shape = get_node_or_null(interaction_shape_path) as CollisionShape2D
	add_to_group("interactable")


func get_closest_interaction_point(world_position: Vector2) -> Vector2:
	if not is_instance_valid(_interaction_shape) or _interaction_shape.shape == null:
		return actor.global_position
	var bounds := _interaction_shape.shape.get_rect()
	var local_point := _interaction_shape.to_local(world_position)
	return _interaction_shape.to_global(local_point.clamp(bounds.position, bounds.end))

func interact(interactor: Actor = null) -> void:
	interacted.emit()
	interacted_by.emit(interactor)

func can_interact() -> bool:
	return is_interactable

func enable_interaction() -> void:
	is_interactable = true

func disable_interaction() -> void:
	is_interactable = false
