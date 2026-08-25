extends Component
class_name DebugOverlayComponent

@export var visible_on_start: bool = true
@export_range(0.05, 1.0, 0.05) var update_interval: float = 0.1

var _label: Label
var _panel: Control
var _update_timer: float = 0.0


func _ready() -> void:
	_label = get_node_or_null("CanvasLayer/Panel/Label") as Label
	_panel = get_node_or_null("CanvasLayer/Panel") as Control

	if _label == null or _panel == null:
		push_error("DebugOverlayComponent requires Panel and Label")
		disable()
		return

	set_debug_visible(visible_on_start)
	_update_overlay()


func _process(delta: float) -> void:
	if not is_debug_visible():
		return

	_update_timer -= delta

	if _update_timer > 0.0:
		return

	_update_timer = update_interval
	_update_overlay()


func set_debug_visible(value: bool) -> void:
	if _panel != null:
		_panel.visible = value


func toggle_debug_visible() -> void:
	set_debug_visible(not is_debug_visible())


func is_debug_visible() -> bool:
	return _panel != null and _panel.visible


func _update_overlay() -> void:
	var lines := PackedStringArray()
	lines.append("Actor: %s" % actor.name)
	lines.append("Components:")

	for component: Component in actor.get_components():
		lines.append(
			"  %s: %s" % [
				component.name,
				"ON" if component.is_enabled else "OFF"
			]
		)

	_append_movement_info(lines)
	_append_interaction_info(lines)
	_append_health_info(lines)
	_append_guard_info(lines)
	_label.text = "\n".join(lines)


func _append_movement_info(lines: PackedStringArray) -> void:
	var movement := actor.get_component(MovementComponent) as MovementComponent
	var body := (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if movement != null and movement.is_enabled:
		lines.append(
			"Movement: %s" % MovementState.Type.keys()[movement.get_state()]
		)

	if body != null and body.is_enabled:
		lines.append("Velocity: %s" % body.get_velocity())


func _append_interaction_info(lines: PackedStringArray) -> void:
	var interaction := (
		actor.get_component(InteractionComponent)
		as InteractionComponent
	)

	if interaction == null or not interaction.is_enabled:
		return

	var target := interaction.get_target()
	var target_name := str(target.actor.name) if target != null else "none"
	lines.append("Target: %s" % target_name)


func _append_health_info(lines: PackedStringArray) -> void:
	var health := actor.get_component(HealthComponent) as HealthComponent

	if health == null or not health.is_enabled:
		return

	lines.append(
		"Health: %.1f / %.1f" % [
			health.get_current_health(),
			health.get_max_health()
		]
	)


func _append_guard_info(lines: PackedStringArray) -> void:
	var guard := actor.get_component(GuardComponent) as GuardComponent

	if guard == null:
		return

	var status := "DISABLED"

	if guard.is_enabled:
		status = "GUARDING" if guard.is_guarding() else "READY"

	lines.append("Guard: %s" % status)
