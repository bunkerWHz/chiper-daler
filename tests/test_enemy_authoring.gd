@tool
extends McpTestSuite

const CHECKS := preload("res://features/enemy/EnemyAuthoringChecks.gd")
const COPIER := preload("res://features/enemy/EnemyTemplateCopy.gd")
var _copy_directories: PackedStringArray = []


func teardown() -> void:
	for directory: String in _copy_directories:
		for filename: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(filename))
		DirAccess.remove_absolute(directory)
	_copy_directories.clear()


func suite_name() -> String:
	return "enemy_authoring"


func test_enemy_templates_pass_checks_without_running_gameplay() -> void:
	for path: String in ["res://game/enemy/monsters/stone_maw/StoneMaw.tscn", "res://game/enemy/monsters/amber_wasp/AmberWasp.tscn"]:
		var enemy := track((load(path) as PackedScene).instantiate()) as Node
		assert_eq(CHECKS.inspect_scene(enemy), PackedStringArray())


func test_blank_dummies_copy_without_art_and_reset_root_scale() -> void:
	for dummy_name: String in ["GroundDummy", "FlyDummy"]:
		var path := "res://game/enemy/" + dummy_name + ".tscn"
		var source := track((load(path) as PackedScene).instantiate()) as Node2D
		assert_eq(source.name, StringName(dummy_name))
		assert_eq(source.scale, Vector2.ONE)
		var source_sprite := source.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
		assert_eq(source_sprite.sprite_frames, null)
		assert_eq(source_sprite.scale, Vector2.ONE)
		assert_eq(source_sprite.position, Vector2.ZERO)
		source.scale = Vector2(3, 3)
		var directory := "res://.godot/dummy_copy_%s" % Time.get_ticks_usec()
		_copy_directories.append(directory)
		assert_eq(COPIER.save_copy(source, directory, "NewMonster"), OK)
		var copied := track((load(directory.path_join("NewMonster.tscn")) as PackedScene).instantiate()) as Node2D
		assert_eq(copied.scale, Vector2.ONE)
		assert_eq(source.scale, Vector2(3, 3))
		assert_eq(source_sprite.sprite_frames, null)
		var frames := (copied.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
		assert_eq(frames.resource_path, directory.path_join("SpriteFrames.tres"))
		for clip: StringName in CHECKS.CLIPS:
			assert_true(frames.has_animation(clip))
			assert_eq(frames.get_frame_count(clip), 0)
		var player := copied.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		assert_eq(player.get_animation_library(&"").resource_path, directory.path_join("AnimationLibrary.tres"))
		assert_contains("\n".join(CHECKS.inspect_scene(copied)), "non-empty")


func test_root_scale_preserves_geometry_and_scales_all_enemy_sensors() -> void:
	for flying: bool in [false, true]:
		var path := "res://game/enemy/monsters/amber_wasp/AmberWasp.tscn" if flying else "res://game/enemy/monsters/stone_maw/StoneMaw.tscn"
		for multiplier: float in [1.0, 2.0]:
			var enemy := track((load(path) as PackedScene).instantiate()) as Actor
			enemy.scale *= multiplier
			enemy.position = Vector2(400, 200)
			(Engine.get_main_loop() as SceneTree).root.add_child(enemy)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			var sprite := enemy.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
			assert_eq(sprite.scale, Vector2.ONE)
			assert_true(sprite.global_scale.is_equal_approx(Vector2.ONE * (0.22 if flying else 0.24) * multiplier))
			assert_true((sprite.global_position - enemy.global_position).is_equal_approx(Vector2(0, -5 if flying else -17) * multiplier))
			for suffix: String in ["CharacterBodyComponent/CharacterBody2D", "HurtboxComponent/Area2D", "HitboxComponent/Area2D"]:
				assert_true(_world_shape_size(enemy, suffix).is_equal_approx(Vector2(20, 20) * multiplier))
			assert_true(_world_shape_size(enemy, "EnemyAttackComponent/DetectionArea2D").is_equal_approx(Vector2(52, 52) * multiplier))
			var chase_size := Vector2(440, 300) if flying else Vector2(360, 160)
			assert_true(_world_shape_size(enemy, "EnemyChaseComponent/DetectionArea2D").is_equal_approx(chase_size * multiplier))
			var hitbox := enemy.get_component(HitboxComponent) as HitboxComponent
			var hitbox_node := enemy.get_node("_Components/HitboxComponent") as Node2D
			for direction: float in [-1.0, 1.0]:
				hitbox.set_horizontal_direction(direction)
				var expected := Vector2((24.0 if flying else 20.0) * direction * multiplier, 0)
				assert_true((hitbox_node.global_position - enemy.global_position).is_equal_approx(expected))
			if not flying:
				var sensor := enemy.get_component(EnemyGroundSensorComponent) as EnemyGroundSensorComponent
				sensor._update_floor_ray(1.0)
				sensor._update_wall_ray(-1.0)
				var floor_ray := sensor.get_node("FloorRayCast2D") as RayCast2D
				var wall_ray := sensor.get_node("WallRayCast2D") as RayCast2D
				assert_true((floor_ray.global_position - enemy.global_position).is_equal_approx(Vector2(14, 0) * multiplier))
				assert_true((floor_ray.to_global(floor_ray.target_position) - floor_ray.global_position).is_equal_approx(Vector2(0, 24) * multiplier))
				assert_true((wall_ray.to_global(wall_ray.target_position) - wall_ray.global_position).is_equal_approx(Vector2(-16, 0) * multiplier))


func _world_shape_size(enemy: Actor, suffix: String) -> Vector2:
	var shape := enemy.get_node("_Components/" + suffix + "/CollisionShape2D") as CollisionShape2D
	return (shape.shape as RectangleShape2D).size * shape.global_scale.abs()


func test_checks_explain_missing_dependency_and_timing_source() -> void:
	var enemy := _create_enemy()
	var hitbox := enemy.get_node("_Components/HitboxComponent")
	hitbox.get_parent().remove_child(hitbox)
	hitbox.free()
	var attack := enemy.get_node("_Components/AttackComponent")
	attack.set("timing_player_path", NodePath())
	var warnings := "\n".join(CHECKS.inspect_scene(enemy))
	assert_contains(warnings, "AttackComponent needs a HitboxComponent")
	assert_contains(warnings, "Timing Player Path")


func test_checks_detect_missing_frames_and_disabled_damage_events() -> void:
	var enemy := _create_enemy()
	var sprite := enemy.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
	sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
	sprite.sprite_frames.remove_animation(&"death")
	var player := enemy.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	var library := player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	player.remove_animation_library(&"")
	player.add_animation_library(&"", library)
	var clip := library.get_animation(&"attack")
	for track: int in clip.get_track_count():
		clip.track_set_enabled(track, false)
	var warnings := "\n".join(CHECKS.inspect_scene(enemy))
	assert_contains(warnings, "non-empty 'death'")
	assert_contains(warnings, "hitbox_on")
	assert_contains(warnings, "hitbox_off")


func _create_enemy() -> Node:
	return track(preload("res://game/enemy/monsters/stone_maw/StoneMaw.tscn").instantiate()) as Node


func test_copy_owns_resources_and_preserves_component_instances() -> void:
	for source_path: String in ["res://game/enemy/monsters/stone_maw/StoneMaw.tscn", "res://game/enemy/monsters/amber_wasp/AmberWasp.tscn"]:
		var source := track((load(source_path) as PackedScene).instantiate()) as Node
		var directory := "res://.godot/enemy_copy_%s" % Time.get_ticks_usec()
		_copy_directories.append(directory)
		assert_eq(COPIER.save_copy(source, directory, "TestEnemy"), OK)
		var packed := load(directory.path_join("TestEnemy.tscn")) as PackedScene
		assert_true(packed != null)
		var copied := track(packed.instantiate()) as Node
		assert_eq(CHECKS.inspect_scene(copied), PackedStringArray())
		assert_eq(packed.get_state().get_node_instance(0), null)
		var hitbox := copied.get_node("_Components/HitboxComponent")
		assert_eq(hitbox.scene_file_path, "res://features/combat/HitboxComponent.tscn")
		var frames := (copied.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
		assert_eq(frames.resource_path, directory.path_join("SpriteFrames.tres"))
		var source_frames := (source.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
		var original_speed := source_frames.get_animation_speed(&"attack")
		var original_texture := source_frames.get_frame_texture(&"attack", 0)
		var replacement := GradientTexture2D.new()
		replacement.gradient = Gradient.new()
		frames.set_frame(&"attack", 0, replacement)
		assert_eq(source_frames.get_frame_texture(&"attack", 0), original_texture)
		frames.set_animation_speed(&"attack", original_speed + 3.0)
		assert_eq(source_frames.get_animation_speed(&"attack"), original_speed)
		var player := copied.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		assert_eq(player.get_animation_library(&"").resource_path, directory.path_join("AnimationLibrary.tres"))
		var source_player := source.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		var original_length := source_player.get_animation(&"attack").length
		player.get_animation(&"attack").length = original_length + 1.0
		assert_eq(source_player.get_animation(&"attack").length, original_length)
		var source_config := source.get_node("_Components/AttackComponent").get("config") as Resource
		var copied_config := copied.get_node("_Components/AttackComponent").get("config") as Resource
		assert_ne(copied_config, source_config)
		hitbox.set("damage", 23.0)
		assert_eq(ResourceSaver.save(frames, frames.resource_path), OK)
		assert_eq(ResourceSaver.save(player.get_animation_library(&""), player.get_animation_library(&"").resource_path), OK)
		copied.scene_file_path = ""
		var edited := PackedScene.new()
		assert_eq(edited.pack(copied), OK)
		assert_eq(ResourceSaver.save(edited, directory.path_join("TestEnemy.tscn")), OK)
		var reloaded := ResourceLoader.load(directory.path_join("TestEnemy.tscn"), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var playable := track(reloaded.instantiate()) as Actor
		(Engine.get_main_loop() as SceneTree).root.add_child(playable)
		var attack := playable.get_component(AttackComponent) as AttackComponent
		assert_true(attack.attack())
		assert_eq(attack.get_attack_duration(), original_length + 1.0)
		assert_eq((playable.get_component(HitboxComponent) as HitboxComponent).damage, 23.0)
		assert_true((playable.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.get_frame_texture(&"attack", 0) is GradientTexture2D)
		assert_eq(COPIER.save_copy(source, directory, "TestEnemy"), ERR_ALREADY_EXISTS)
