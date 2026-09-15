extends SceneTree

const ROOT := "res://game/enemy/monsters/stone_golem/"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var packed := load(ROOT + "StoneGolem.tscn") as PackedScene
	var golem := packed.instantiate() as Actor
	check(packed.get_state().get_node_instance(0) == null, "Standalone composition")
	check(EnemyAuthoringChecks.inspect_scene(golem).is_empty(), "Enemy authoring checks pass")
	check(golem.scale == Vector2(3, 3), "Size authored at root")
	var sprite := golem.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
	check(sprite.scale == Vector2.ONE and not sprite.flip_h, "Native right-facing sprite")
	var frames := sprite.sprite_frames
	var counts := {"idle": 4, "move": 4, "glowing": 8, "ranged_attack": 9,
		"melee_attack": 7, "laser_cast": 7, "armor_buff": 10, "block": 8,
		"defeated": 14, "appearance": 14, "attack": 7, "death": 14}
	for name: String in counts:
		check(frames.get_frame_count(name) == counts[name], name + " frame count")
		check(frames.get_animation_speed(name) == 10.0, name + " source timing")
		for i: int in counts[name]:
			var texture := frames.get_frame_texture(name, i) as AtlasTexture
			check(texture != null and texture.get_size() == Vector2(100, 100), name + " native atlas frame")
	for i in 14:
		check((frames.get_frame_texture(&"appearance", i) as AtlasTexture).region == (frames.get_frame_texture(&"death", 13-i) as AtlasTexture).region, "Appearance reverses defeat")
	var effects := load(ROOT + "EffectSpriteFrames.tres") as SpriteFrames
	check(effects.get_frame_count(&"laser_beam") == 14, "14 laser frames")
	check((effects.get_frame_texture(&"laser_beam", 0) as AtlasTexture).region.position.y == 100, "Empty laser row excluded")
	check(effects.get_frame_count(&"arm_projectile_glowing") == 6, "Six glowing projectile frames")
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = RectangleShape2D.new()
	floor_shape.shape.size = Vector2(1000, 20)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 200)
	world.add_child(floor_body)
	world.add_child(golem)
	await create_timer(0.8).timeout
	var body := golem.get_component(CharacterBodyComponent) as CharacterBodyComponent
	check(body.is_on_floor(), "Boss lands on floor")
	check(absf(golem.global_position.y + 23 * golem.scale.y - 190) < 1.0, "Native body and visible feet align on floor")
	for shape: Node in golem.find_children("*", "CollisionShape2D", true, false):
		check(shape.scale == Vector2.ONE, "Collision local scale remains one")
	check(not golem.has_component(EnemyAttackComponent), "No autonomous boss combat in asset phase")
	(golem.get_component(EnemyVisualComponent) as EnemyVisualComponent).disable()
	var timeline := golem.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	for name: String in counts:
		timeline.play(name)
		timeline.advance(0)
		timeline.seek(timeline.get_animation(name).length - 0.01, true)
		check(sprite.animation == name and sprite.frame == counts[name]-1, name + " timeline reaches last frame")
	timeline.play(&"laser")
	timeline.advance(0)
	check(not golem.get_node("_Visual/LaserBeam").visible, "Combined laser starts with cast")
	timeline.seek(0.71, true)
	check(golem.get_node("_Visual/LaserBeam").visible, "Beam appears after casting")
	timeline.play(&"idle")
	timeline.advance(0)
	check(not golem.get_node("_Visual/LaserBeam").visible, "Changing clip clears effect")
	world.queue_free()
	await process_frame
	check(change_scene_to_file("res://tests/StoneGolemPreview.tscn") == OK, "Preview opens")
	await process_frame
	await process_frame
	for i in current_scene.CLIPS.size():
		current_scene.picker.select(i)
		current_scene.play_selected()
		check(current_scene.timeline.current_animation == current_scene.CLIPS[i], "Preview selects clip")
	current_scene._set_facing(true)
	check(current_scene.sprite.flip_h, "Preview faces left via flip_h")
	print("Stone Golem: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
