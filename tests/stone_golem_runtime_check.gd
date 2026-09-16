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
		"melee_attack": 7, "laser": 7, "armor_buff": 10, "block": 8,
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
	check(effects.get_frame_count(&"laser") == 14, "14 laser frames")
	check((effects.get_frame_texture(&"laser", 0) as AtlasTexture).region.position.y == 100, "Empty laser row excluded")
	check(not effects.has_animation(&"arm_projectile"), "Projectile is not a character effect")
	var projectile := load(ROOT + "ArmProjectile.tscn").instantiate() as Area2D
	var projectile_sprite := projectile.get_node("AnimatedSprite2D") as AnimatedSprite2D
	check(projectile_sprite.sprite_frames.get_frame_count(&"glowing") == 6, "Six glowing frames belong to projectile")
	check(projectile_sprite.sprite_frames.get_frame_texture(&"idle", 0).get_size() == Vector2(35, 14), "Projectile art excludes transparent padding")
	check(projectile.scale == Vector2(3, 3) and projectile_sprite.scale == Vector2.ONE, "Projectile uses native scale convention")
	projectile.free()
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
	check(not timeline.has_animation(&"laser_cast") and not timeline.has_animation(&"laser_beam"), "Only one laser clip in AnimationPlayer")
	check(not frames.has_animation(&"laser_cast"), "No separate cast animation in character SpriteFrames")
	check(not timeline.has_animation(&"arm_projectile") and not golem.has_node("_Visual/ArmProjectile"), "Projectile removed from boss animation and visual tree")
	for name: String in counts:
		timeline.play(name)
		timeline.advance(0)
		timeline.seek(timeline.get_animation(name).length - 0.01, true)
		check(sprite.animation == name and sprite.frame == counts[name]-1, name + " timeline reaches last frame")
	timeline.play(&"laser")
	timeline.advance(0)
	check(not golem.get_node("_Visual/LaserBeam").visible, "Combined laser starts with cast")
	timeline.seek(0.599, true)
	check(not golem.get_node("_Visual/LaserBeam").visible and sprite.frame == 5, "No beam before final cast frame")
	timeline.seek(0.6001, true)
	check(golem.get_node("_Visual/LaserBeam").visible and sprite.frame == 6, "Beam starts on final cast frame")
	timeline.seek(1.99, true)
	check(golem.get_node("_Visual/LaserBeam").frame == 13, "Full 14-frame beam plays")
	timeline.play(&"idle")
	timeline.advance(0)
	check(not golem.get_node("_Visual/LaserBeam").visible, "Changing clip clears effect")
	world.queue_free()
	await process_frame
	check(change_scene_to_file("res://tests/StoneGolemPreview.tscn") == OK, "Preview opens")
	await process_frame
	await process_frame
	check("laser_cast" not in current_scene.CLIPS and "laser_beam" not in current_scene.CLIPS, "Preview exposes only combined laser")
	for i in current_scene.CLIPS.size():
		current_scene.picker.select(i)
		current_scene.play_selected()
		check(current_scene.timeline.current_animation == current_scene.CLIPS[i], "Preview selects clip")
	current_scene._set_facing(true)
	check(current_scene.sprite.flip_h, "Preview faces left via flip_h")
	current_scene.picker.select(current_scene.CLIPS.find("ranged_attack"))
	current_scene.play_selected()
	current_scene.timeline.seek(0.51, true)
	current_scene._process(0.0)
	check(is_instance_valid(current_scene._projectile), "Ranged attack launches separate preview projectile")
	var projectile_x: float = current_scene._projectile.position.x
	current_scene._process(0.1)
	check(current_scene._projectile.position.x < projectile_x, "Left-facing preview shoots to the left")
	current_scene.picker.select(current_scene.CLIPS.find("laser"))
	current_scene.play_selected()
	current_scene.timeline.seek(0.599, true)
	check(current_scene.interrupt_laser_cast(), "Cast can be interrupted before release")
	current_scene.timeline.advance(1.0)
	check(not current_scene.golem.get_node("_Visual/LaserBeam").visible, "Interrupted cast never emits delayed beam")
	current_scene.play_selected()
	current_scene.timeline.seek(0.6001, true)
	check(not current_scene.interrupt_laser_cast(), "Completed cast has already released beam")
	check(current_scene.golem.get_node("_Visual/LaserBeam").visible, "Uninterrupted cast emits beam")
	print("Stone Golem: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
