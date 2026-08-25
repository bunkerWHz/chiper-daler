extends Component
class_name InteractionComponent

@export var interaction_distance: float = 48.0
@export var interaction_cooldown: float = 0.15

var cooldown_timer: float = 0.0

var input_component: InputComponent
var current_target: InteractableComponent = null



func on_initialize() -> void:
	input_component = actor.get_component(InputComponent) as InputComponent

	if input_component == null:
		push_error("InteractionComponent requires InputComponent")
		return


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = max(cooldown_timer - delta, 0.0)
		
	if input_component == null:
		return

	_update_target()

	if input_component.is_interact_pressed():
		interact()


func _update_target() -> void:
	current_target = find_nearest_interactable()


func find_nearest_interactable() -> InteractableComponent:
	var nearest: InteractableComponent = null
	var nearest_distance: float = interaction_distance

	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is InteractableComponent:
			continue
		var interactable: InteractableComponent = node as InteractableComponent
		if not interactable.can_interact():
			continue

		var distance: float = actor.global_position.distance_to(
			interactable.actor.global_position
		)

		if distance <= nearest_distance:
			nearest = interactable
			nearest_distance = distance
	
	return nearest


func interact() -> void:
	if cooldown_timer > 0.0:
		return

	if current_target == null:
		return

	if not current_target.can_interact():
		return

	current_target.interact()
	cooldown_timer = interaction_cooldown


func has_target() -> bool:
	return current_target != null


func get_target() -> InteractableComponent:
	return current_target
