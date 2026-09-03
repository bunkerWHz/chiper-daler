@tool
extends McpTestSuite


const ENEMY_SCENES: Array[Dictionary] = [
	{
		"scene": "res://game/enemy/Enemy.tscn",
		"frames": "res://game/enemy/animations/GroundEnemySpriteFrames.tres",
		"animation_library": "res://game/enemy/animations/GroundEnemyAnimationLibrary.tres",
		"movement_cue": AnimationEventComponent.FOOTSTEP,
	},
	{
		"scene": "res://game/enemy/FlyingEnemy.tscn",
		"frames": "res://game/enemy/animations/FlyingEnemySpriteFrames.tres",
		"animation_library": "res://game/enemy/animations/FlyingEnemyAnimationLibrary.tres",
		"movement_cue": AnimationEventComponent.WING_FLAP,
	},
]


func suite_name() -> String:
	return "animation_pipeline"


func test_player_uses_serialized_frames_and_animation_player() -> void:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Node
	var sprite := player.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
	var animation_player := (
		player.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	)
	var archer_frames := load(
		"res://game/player/animations/ArcherSpriteFrames.tres"
	) as SpriteFrames
	var lancer_frames := load(
		"res://game/player/animations/LancerSpriteFrames.tres"
	) as SpriteFrames

	assert_true(animation_player.has_animation(&"attack"))
	assert_eq(
		sprite.sprite_frames.resource_path,
		"res://game/player/animations/WarriorSpriteFrames.tres"
	)
	assert_eq(
		archer_frames.resource_path,
		"res://game/player/animations/ArcherSpriteFrames.tres"
	)
	assert_eq(
		lancer_frames.resource_path,
		"res://game/player/animations/LancerSpriteFrames.tres"
	)


func test_enemies_use_serialized_frames_and_animation_player() -> void:
	for entry: Dictionary in ENEMY_SCENES:
		var packed := load(entry.scene as String) as PackedScene
		var enemy := track(packed.instantiate()) as Node
		var sprite := (
			enemy.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
		)
		var animation_player := (
			enemy.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		)

		assert_true(animation_player.has_animation(&"death"))
		assert_eq(sprite.sprite_frames.resource_path, entry.frames as String)
		assert_eq(
			animation_player.get_animation_library(&"").resource_path,
			entry.animation_library as String
		)
		assert_eq(
			animation_player.get_animation(&"move").loop_mode,
			Animation.LOOP_LINEAR
		)

		var attack: Node = enemy.get_node("_Components/AttackComponent")
		var attack_config := attack.get("config") as AttackConfig
		var events: Node = enemy.get_node_or_null(
			"_Components/AnimationEventComponent"
		)
		var audio: Node = enemy.get_node_or_null(
			"_Components/ActorAudioComponent"
		)
		assert_true(attack.get("animation_driven_damage_window") as bool)
		assert_eq(
			attack_config.active_duration,
			animation_player.get_animation(&"attack").length
		)
		assert_true(events != null)
		assert_true(audio != null)
		assert_true(_animation_has_event(
			animation_player.get_animation(&"move"),
			entry.movement_cue as StringName
		))
		assert_true(_animation_has_event(
			animation_player.get_animation(&"attack"),
			AnimationEventComponent.HITBOX_ON
		))
		assert_true(_animation_has_event(
			animation_player.get_animation(&"attack"),
			AnimationEventComponent.HITBOX_OFF
		))


func test_audio_profile_maps_semantic_cues_to_streams() -> void:
	var profile := ActorAudioProfile.new()
	var footstep := AudioStreamWAV.new()
	var hurt := AudioStreamWAV.new()
	profile.footsteps = [footstep]
	profile.hurt_voices = [hurt]

	assert_eq(
		profile.get_streams(AnimationEventComponent.FOOTSTEP)[0],
		footstep
	)
	assert_eq(profile.get_streams(ActorAudioComponent.HURT)[0], hurt)
	assert_true(profile.is_voice_event(ActorAudioComponent.HURT))
	assert_false(profile.is_voice_event(AnimationEventComponent.FOOTSTEP))


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
