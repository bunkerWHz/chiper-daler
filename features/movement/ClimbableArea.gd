extends Area2D
class_name ClimbableArea


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	var body_component := body.get_parent() as CharacterBodyComponent

	if body_component == null or body_component.actor == null:
		return

	var climbing := body_component.actor.get_component(ClimbingComponent)

	if climbing != null and climbing.is_enabled:
		climbing.enter_climbable(self)


func _on_body_exited(body: Node2D) -> void:
	var body_component := body.get_parent() as CharacterBodyComponent

	if body_component == null or body_component.actor == null:
		return

	var climbing := body_component.actor.get_component(ClimbingComponent)

	if climbing != null and climbing.is_enabled:
		climbing.exit_climbable(self)
