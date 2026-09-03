extends Resource
class_name ActorAudioProfile

@export_category("Animation cues")
@export var footsteps: Array[AudioStream] = []
@export var wing_flaps: Array[AudioStream] = []
@export var attack_swings: Array[AudioStream] = []
@export var body_impacts: Array[AudioStream] = []

@export_category("Gameplay cues")
@export var hit_confirmations: Array[AudioStream] = []
@export var hurt_voices: Array[AudioStream] = []
@export var death_voices: Array[AudioStream] = []

@export_category("Playback")
@export_range(-80.0, 24.0, 0.1) var effects_volume_db: float = 0.0
@export_range(-80.0, 24.0, 0.1) var voice_volume_db: float = 0.0
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.05
@export_range(1.0, 4096.0, 1.0) var max_distance: float = 600.0


func get_streams(event_name: StringName) -> Array[AudioStream]:
	match event_name:
		AnimationEventComponent.FOOTSTEP:
			return footsteps
		AnimationEventComponent.WING_FLAP:
			return wing_flaps
		AnimationEventComponent.ATTACK_SWING:
			return attack_swings
		AnimationEventComponent.BODY_IMPACT:
			return body_impacts
		ActorAudioComponent.HIT_CONFIRMED:
			return hit_confirmations
		ActorAudioComponent.HURT:
			return hurt_voices
		ActorAudioComponent.DEATH:
			return death_voices
		_:
			return []


func is_voice_event(event_name: StringName) -> bool:
	return event_name == ActorAudioComponent.HURT or event_name == ActorAudioComponent.DEATH
