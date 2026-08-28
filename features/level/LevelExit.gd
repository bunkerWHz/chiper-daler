extends Actor
class_name LevelExit

signal exit_locked(remaining_enemies: int)
signal level_completed(interactor: Actor)

@export var require_enemy_clear: bool = true
@export var next_scene: PackedScene

var _interactable: InteractableComponent
var _marker: Polygon2D
var _is_completed: bool = false


func _ready() -> void:
	_interactable = get_component(InteractableComponent) as InteractableComponent
	_marker = get_node_or_null("Marker") as Polygon2D
	if _interactable == null:
		push_error("LevelExit requires InteractableComponent")
		return

	_interactable.interacted_by.connect(_on_interacted_by)
	_update_prompt()


func try_complete(interactor: Actor) -> bool:
	if _is_completed or interactor == null:
		return false

	var remaining := get_remaining_enemy_count()
	if require_enemy_clear and remaining > 0:
		exit_locked.emit(remaining)
		_update_prompt()
		return false

	_is_completed = true
	_interactable.disable_interaction()
	_interactable.interaction_name = "Level complete"
	if _marker != null:
		_marker.color = Color(0.35, 1.0, 0.45, 1.0)
	level_completed.emit(interactor)

	if next_scene != null and is_inside_tree():
		get_tree().change_scene_to_packed.call_deferred(next_scene)

	return true


func is_completed() -> bool:
	return _is_completed


func get_remaining_enemy_count() -> int:
	var search_root := get_parent()
	if is_inside_tree() and get_tree().current_scene != null:
		search_root = get_tree().current_scene
	if search_root == null:
		return 0

	var remaining := 0
	var candidates: Array[Node] = [search_root]
	candidates.append_array(search_root.find_children("*", "", true, false))
	for node: Node in candidates:
		if not node.is_in_group(&"enemies") or not node is Actor:
			continue
		var health := (node as Actor).get_component(HealthComponent) as HealthComponent
		if health == null or health.is_alive():
			remaining += 1

	return remaining


func _on_interacted_by(interactor: Actor) -> void:
	try_complete(interactor)


func _update_prompt() -> void:
	if _interactable == null or _is_completed:
		return

	var remaining := get_remaining_enemy_count()
	_interactable.interaction_name = (
		"Exit locked (%d enemies)" % remaining
		if require_enemy_clear and remaining > 0
		else "Complete level"
	)
