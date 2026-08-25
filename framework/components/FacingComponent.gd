extends Component
class_name FacingComponent

enum Direction {
	LEFT = -1,
	RIGHT = 1
}

signal facing_changed(
	previous_direction: Direction,
	current_direction: Direction
)

var _input_component: InputComponent
var _direction: Direction = Direction.RIGHT


func on_initialize() -> void:
	_input_component = actor.get_component(InputComponent) as InputComponent

	if _input_component == null or not _input_component.is_enabled:
		push_error("FacingComponent requires an enabled InputComponent")
		disable()


func _physics_process(_delta: float) -> void:
	var move_axis := _input_component.get_move_axis()

	if move_axis < 0.0:
		_set_direction(Direction.LEFT)
	elif move_axis > 0.0:
		_set_direction(Direction.RIGHT)


func _set_direction(new_direction: Direction) -> void:
	if new_direction == _direction:
		return

	var previous_direction := _direction
	_direction = new_direction
	facing_changed.emit(previous_direction, _direction)


func get_direction() -> Direction:
	return _direction
