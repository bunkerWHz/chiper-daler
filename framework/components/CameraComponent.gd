extends Component
class_name CameraComponent

@export var config: CameraConfig

var _camera: Camera2D


func _ready() -> void:
	if config == null:
		push_error("CameraComponent requires CameraConfig")
		disable()
		return

	if not _validate_config():
		disable()
		return

	_camera = get_camera()

	if _camera == null:
		push_error("CameraComponent requires Camera2D")
		disable()
		return

	_apply_config()
	_camera.enabled = true


func get_camera() -> Camera2D:
	if _camera == null:
		_camera = get_node_or_null("Camera2D") as Camera2D

	return _camera


func _apply_config() -> void:
	_camera.offset = config.offset
	_camera.ignore_rotation = config.ignore_rotation
	_camera.position_smoothing_enabled = config.position_smoothing_enabled
	_camera.position_smoothing_speed = config.position_smoothing_speed
	_camera.zoom = config.zoom
	_camera.limit_left = config.limit_left
	_camera.limit_top = config.limit_top
	_camera.limit_right = config.limit_right
	_camera.limit_bottom = config.limit_bottom
	_camera.limit_smoothed = config.limit_smoothed


func _validate_config() -> bool:
	if config.zoom.x <= 0.0 or config.zoom.y <= 0.0:
		push_error("CameraConfig zoom must be greater than zero")
		return false

	if config.limit_left >= config.limit_right:
		push_error("CameraConfig left limit must be less than right limit")
		return false

	if config.limit_top >= config.limit_bottom:
		push_error("CameraConfig top limit must be less than bottom limit")
		return false

	return true
