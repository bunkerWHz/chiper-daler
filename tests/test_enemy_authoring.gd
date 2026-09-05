@tool
extends McpTestSuite

const CHECKS := preload("res://features/enemy/EnemyAuthoringChecks.gd")


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
