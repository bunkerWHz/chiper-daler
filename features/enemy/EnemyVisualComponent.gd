extends Component
class_name EnemyVisualComponent

@export var config: EnemyVisualConfig
@export var sprite_path: NodePath = ^"_Visual/AnimatedSprite2D"

var _sprite: AnimatedSprite2D
var _body_component: CharacterBodyComponent
var _locomotion: Component
var _attack_component: AttackComponent
var _health_component: HealthComponent
var _is_attacking: bool = false
var _is_dead: bool = false


func on_initialize() -> void:
	if config == null or config.animation_root.is_empty():
		push_error("EnemyVisualComponent requires EnemyVisualConfig")
		disable()
		return

	_body_component = actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	_locomotion = EnemyLocomotion.find(actor)
	_attack_component = actor.get_component(AttackComponent) as AttackComponent
	_health_component = actor.get_component(HealthComponent) as HealthComponent

	if _attack_component != null:
		_attack_component.attack_started.connect(_on_attack_started)
		_attack_component.attack_finished.connect(_on_attack_finished)
	if _health_component != null:
		_health_component.died.connect(_on_died)


func _ready() -> void:
	_sprite = actor.get_node_or_null(sprite_path) as AnimatedSprite2D
	if _sprite == null:
		push_error("EnemyVisualComponent requires AnimatedSprite2D")
		disable()
		return

	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.position = config.visual_offset
	_sprite.scale = config.visual_scale
	_play(&"idle")


func _process(_delta: float) -> void:
	if _sprite == null or _is_dead:
		return

	_apply_facing()
	if _is_attacking:
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


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", config.idle_folder, true)
	_add_animation(frames, &"move", config.move_folder, true)
	_add_animation(frames, &"airborne", config.airborne_folder, true)
	_add_animation(frames, &"attack", config.attack_folder, false)
	_add_animation(frames, &"death", config.death_folder, false)
	return frames


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	folder: StringName,
	loops: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, config.frames_per_second)
	frames.set_animation_loop(animation_name, loops)
	var directory_path := config.animation_root.path_join(String(folder))
	var files := DirAccess.get_files_at(directory_path)
	files.sort()
	for file_name: String in files:
		if file_name.to_lower().ends_with(".png"):
			var texture := load(directory_path.path_join(file_name)) as Texture2D
			if texture != null:
				frames.add_frame(animation_name, texture)


func _play(animation_name: StringName) -> void:
	if _sprite.sprite_frames.has_animation(animation_name) and _sprite.sprite_frames.get_frame_count(animation_name) > 0:
		if _sprite.animation != animation_name or not _sprite.is_playing():
			_sprite.play(animation_name)


func _apply_facing() -> void:
	if _locomotion == null or not _locomotion.has_method(&"get_facing_direction"):
		return
	var direction := float(_locomotion.call(&"get_facing_direction"))
	if not is_zero_approx(direction):
		_sprite.flip_h = (direction > 0.0) if config.art_faces_left else (direction < 0.0)


func _on_attack_started() -> void:
	_is_attacking = true
	_play(&"attack")


func _on_attack_finished() -> void:
	_is_attacking = false


func _on_died() -> void:
	_is_dead = true
	_play(&"death")
