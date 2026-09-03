extends Component
class_name ActorAudioComponent

const HIT_CONFIRMED: StringName = &"hit_confirmed"
const HURT: StringName = &"hurt"
const DEATH: StringName = &"death"

@export var profile: ActorAudioProfile

var _animation_events: AnimationEventComponent
var _effects_player: AudioStreamPlayer2D
var _voice_player: AudioStreamPlayer2D
var _random := RandomNumberGenerator.new()


func on_initialize() -> void:
	if profile == null:
		push_error("ActorAudioComponent requires ActorAudioProfile")
		disable()
		return
	_random.randomize()

	_animation_events = (
		actor.get_component(AnimationEventComponent) as AnimationEventComponent
	)
	if (
		_animation_events != null
		and not _animation_events.event_emitted.is_connected(_on_animation_event)
	):
		_animation_events.event_emitted.connect(_on_animation_event)

	var hitbox := actor.get_component(HitboxComponent) as HitboxComponent
	if hitbox != null and not hitbox.hit_landed.is_connected(_on_hit_landed):
		hitbox.hit_landed.connect(_on_hit_landed)

	var health := actor.get_component(HealthComponent) as HealthComponent
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)


func _ready() -> void:
	_effects_player = get_node_or_null("EffectsPlayer2D") as AudioStreamPlayer2D
	_voice_player = get_node_or_null("VoicePlayer2D") as AudioStreamPlayer2D
	if _effects_player == null or _voice_player == null:
		push_error("ActorAudioComponent requires effects and voice players")
		disable()
		return

	_effects_player.volume_db = profile.effects_volume_db
	_effects_player.max_distance = profile.max_distance
	_voice_player.volume_db = profile.voice_volume_db
	_voice_player.max_distance = profile.max_distance


func play_cue(event_name: StringName) -> bool:
	if not is_enabled or profile == null:
		return false

	var streams := profile.get_streams(event_name)
	if streams.is_empty():
		return false

	var player := _voice_player if profile.is_voice_event(event_name) else _effects_player
	if player == null:
		return false

	var stream := streams[_random.randi_range(0, streams.size() - 1)]
	if stream == null:
		return false

	player.stream = stream
	player.pitch_scale = _random.randf_range(
		1.0 - profile.pitch_variation,
		1.0 + profile.pitch_variation
	)
	player.play()
	return true


func should_disable_on_actor_death() -> bool:
	return false


func _on_animation_event(event_name: StringName) -> void:
	play_cue(event_name)


func _on_hit_landed(
	_hurtbox: HurtboxComponent,
	_applied_damage: float
) -> void:
	play_cue(HIT_CONFIRMED)


func _on_damaged(_amount: float, current_health: float) -> void:
	if current_health > 0.0:
		play_cue(HURT)


func _on_died() -> void:
	play_cue(DEATH)
