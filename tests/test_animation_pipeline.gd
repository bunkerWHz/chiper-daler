@tool
extends McpTestSuite


const ENEMY_SCENES: Array[Dictionary] = [
	{
		"scene": "res://game/enemy/Enemy.tscn",
		"frames": "res://game/enemy/animations/GroundEnemySpriteFrames.tres",
	},
	{
		"scene": "res://game/enemy/FlyingEnemy.tscn",
		"frames": "res://game/enemy/animations/FlyingEnemySpriteFrames.tres",
	},
]


func suite_name() -> String:
	return "animation_pipeline"


func test_player_uses_serialized_frames_and_animation_player() -> void:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Actor
	player._collect_components()
	var visual := (
		player.get_component(TemporaryPlayerVisualComponent)
		as TemporaryPlayerVisualComponent
	)
	visual._ready()
	var sprite := player.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
	var animation_player := (
		player.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	)

	assert_true(visual.is_enabled)
	assert_eq(visual.get_animation_player(), animation_player)
	assert_true(animation_player.has_animation(&"attack"))
	assert_eq(
		sprite.sprite_frames.resource_path,
		"res://game/player/animations/WarriorSpriteFrames.tres"
	)
	assert_eq(
		visual.archer_frames.resource_path,
		"res://game/player/animations/ArcherSpriteFrames.tres"
	)
	assert_eq(
		visual.lancer_frames.resource_path,
		"res://game/player/animations/LancerSpriteFrames.tres"
	)


func test_enemies_use_serialized_frames_and_animation_player() -> void:
	for entry: Dictionary in ENEMY_SCENES:
		var packed := load(entry.scene as String) as PackedScene
		var enemy := track(packed.instantiate()) as Actor
		enemy._collect_components()
		var visual := (
			enemy.get_component(EnemyVisualComponent) as EnemyVisualComponent
		)
		visual._ready()
		var sprite := (
			enemy.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
		)
		var animation_player := (
			enemy.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		)

		assert_true(visual.is_enabled)
		assert_eq(visual.get_animation_player(), animation_player)
		assert_true(animation_player.has_animation(&"death"))
		assert_eq(sprite.sprite_frames.resource_path, entry.frames as String)
