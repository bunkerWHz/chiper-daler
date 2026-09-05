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
	for path: String in ["res://game/enemy/Enemy.tscn", "res://game/enemy/FlyingEnemy.tscn"]:
		var enemy := track((load(path) as PackedScene).instantiate()) as Node
		assert_eq(CHECKS.inspect_scene(enemy), PackedStringArray())


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
	return track(preload("res://game/enemy/Enemy.tscn").instantiate()) as Node


func test_copy_owns_resources_and_preserves_component_instances() -> void:
	for source_path: String in ["res://game/enemy/Enemy.tscn", "res://game/enemy/FlyingEnemy.tscn"]:
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
		assert_eq(COPIER.save_copy(source, directory, "TestEnemy"), ERR_ALREADY_EXISTS)
