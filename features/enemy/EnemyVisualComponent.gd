extends Component
class_name EnemyVisualComponent

@export var config: EnemyVisualConfig
@export var sprite_path: NodePath = ^"_Visual/AnimatedSprite2D"
@export var animation_player_path: NodePath = ^"_Visual/AnimationPlayer"

var _sprite: AnimatedSprite2D
var _animation_player: AnimationPlayer
var _body_component: CharacterBodyComponent
var _locomotion: Component
var _attack_component: AttackComponent
var _health_component: HealthComponent
var _current_animation: StringName

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle", &"move", &"airborne", &"attack", &"death",
]


func on_initialize() -> void:
	if config == null:
		push_error("EnemyVisualComponent requires EnemyVisualConfig")
		disable()
		return

	_body_component = actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	_locomotion = EnemyLocomotion.find(actor)
	_attack_component = actor.get_component(AttackComponent) as AttackComponent
	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _attack_component != null:
		if not _attack_component.attack_started.is_connected(_on_attack_started):
			_attack_component.attack_started.connect(_on_attack_started)
		if not _attack_component.attack_finished.is_connected(_on_attack_finished):
			_attack_component.attack_finished.connect(_on_attack_finished)
	if _health_component != null and not _health_component.died.is_connected(_on_died):
		_health_component.died.connect(_on_died)


func _ready() -> void:
	_sprite = actor.get_node_or_null(sprite_path) as AnimatedSprite2D
	_animation_player = actor.get_node_or_null(
		animation_player_path
	) as AnimationPlayer
	if _sprite == null or _sprite.sprite_frames == null:
		push_error("EnemyVisualComponent requires AnimatedSprite2D with SpriteFrames")
		disable()
		return
	if _animation_player == null:
		push_error("EnemyVisualComponent requires AnimationPlayer")
		disable()
		return
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if (
			not _sprite.sprite_frames.has_animation(animation_name)
			or not _animation_player.has_animation(animation_name)
		):
			push_error(
				"EnemyVisualComponent requires a '%s' animation"
				% animation_name
			)
			disable()
			return
	_validate_attack_timeline()
	_sprite.position = config.visual_offset
	_sprite.scale = config.visual_scale
	_process(0.0)


func _process(_delta: float) -> void:
	if not is_enabled or _sprite == null:
		return
	if _health_component != null and _health_component.is_dead():
		_play(&"death")
		return

	_apply_facing()
	if _attack_component != null and _attack_component.is_attacking():
		_play(&"attack")
		return

	var velocity := _body_component.get_velocity() if _body_component != null else Vector2.ZERO
	if _locomotion is EnemyFlightComponent:
		_play(&"move")
	elif _body_component != null and not _body_component.is_on_floor():
		_play(&"airborne")
	elif not is_zero_approx(velocity.x):
		_play(&"move")
	else:
		_play(&"idle")


func should_disable_on_actor_death() -> bool:
	return false


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func _play(animation_name: StringName) -> void:
	if _current_animation == animation_name:
		return
	if _animation_player.has_animation(animation_name):
		_current_animation = animation_name
		_animation_player.play(animation_name)


func _validate_attack_timeline() -> void:
	if (
		_attack_component == null
		or not _attack_component.animation_driven_damage_window
	):
		return

	var attack_animation := _animation_player.get_animation(&"attack")
	for event_name: StringName in [
		AnimationEventComponent.HITBOX_ON,
		AnimationEventComponent.HITBOX_OFF,
	]:
		if not _animation_has_event(attack_animation, event_name):
			push_error(
				"Enemy attack animation requires a '%s' event" % event_name
			)

func _animation_has_event(
	animation: Animation,
	event_name: StringName
) -> bool:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_METHOD:
			continue
		for key_index: int in animation.track_get_key_count(track_index):
			var key: Dictionary = animation.track_get_key_value(
				track_index,
				key_index
			)
			if key.get(&"method", StringName()) != &"emit_event":
				continue
			var arguments: Array = key.get(&"args", [])
			if not arguments.is_empty() and arguments[0] == event_name:
				return true
	return false


func _apply_facing() -> void:
	if _locomotion == null or not _locomotion.has_method(&"get_facing_direction"):
		return
	var direction := float(_locomotion.call(&"get_facing_direction"))
	if not is_zero_approx(direction):
		_sprite.flip_h = (direction > 0.0) if config.art_faces_left else (direction < 0.0)


func _on_attack_started() -> void:
	_process(0.0)


func _on_attack_finished() -> void:
	_process(0.0)


func _on_died() -> void:
	_process(0.0)
