extends Component
class_name InteractionComponent

enum Phase {
	NONE,
	START,
	PROGRESS,
	END,
}

signal phase_changed(previous_phase: Phase, current_phase: Phase)

@export var interaction_distance: float = 48.0
@export var interaction_cooldown: float = 0.15
@export_range(0.01, 2.0, 0.01) var start_duration: float = 0.08
@export_range(0.01, 5.0, 0.01) var progress_duration: float = 0.15
@export_range(0.01, 2.0, 0.01) var end_duration: float = 0.12

var cooldown_timer: float = 0.0
var _phase_timer: float = 0.0
var _phase: Phase = Phase.NONE

var input_component: InputComponent
var current_target: InteractableComponent = null



func on_initialize() -> void:
	if (
		interaction_distance <= 0.0
		or interaction_cooldown < 0.0
		or start_duration <= 0.0
		or progress_duration <= 0.0
		or end_duration <= 0.0
	):
		push_error("InteractionComponent has an invalid config")
		disable()
		return

	input_component = actor.get_component(InputComponent) as InputComponent

	if input_component == null:
		push_error("InteractionComponent requires InputComponent")
		disable()
		return


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = max(cooldown_timer - delta, 0.0)

	_update_interaction_phase(delta)
		
	_update_target()

	if input_component.consume_interact_pressed():
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


func interact() -> bool:
	if cooldown_timer > 0.0 or is_interacting():
		return false

	if current_target == null:
		return false

	if not current_target.can_interact():
		return false

	current_target.interact()
	cooldown_timer = interaction_cooldown
	_set_phase(Phase.START, start_duration)
	return true


func has_target() -> bool:
	return current_target != null


func get_target() -> InteractableComponent:
	return current_target


func get_phase() -> Phase:
	return _phase


func is_interacting() -> bool:
	return _phase != Phase.NONE


func _update_interaction_phase(delta: float) -> void:
	if _phase == Phase.NONE:
		return

	_phase_timer = maxf(_phase_timer - delta, 0.0)

	if _phase_timer > 0.0:
		return

	match _phase:
		Phase.START:
			_set_phase(Phase.PROGRESS, progress_duration)
		Phase.PROGRESS:
			_set_phase(Phase.END, end_duration)
		Phase.END:
			_set_phase(Phase.NONE, 0.0)


func _set_phase(new_phase: Phase, duration: float) -> void:
	if new_phase == _phase:
		_phase_timer = duration
		return

	var previous_phase := _phase
	_phase = new_phase
	_phase_timer = duration
	phase_changed.emit(previous_phase, _phase)
