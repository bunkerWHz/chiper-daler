extends Component
class_name AnimationEventComponent

signal event_emitted(event_name: StringName)

const FOOTSTEP: StringName = &"footstep"
const WING_FLAP: StringName = &"wing_flap"
const ATTACK_SWING: StringName = &"attack_swing"
const HITBOX_ON: StringName = &"hitbox_on"
const HITBOX_OFF: StringName = &"hitbox_off"
const BODY_IMPACT: StringName = &"body_impact"


func emit_event(event_name: StringName) -> void:
	if is_enabled and not event_name.is_empty():
		event_emitted.emit(event_name)


func should_disable_on_actor_death() -> bool:
	return false
