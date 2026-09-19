extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := load("res://game/player/darklight/DarklightRig.tscn").instantiate() as Node2D
	root.add_child(rig)
	rig.position = Vector2(600, 400)
	rig.scale = Vector2(0.65, 0.65)
	var cloak := rig.get_node("CharacterContainer/VisualDetails/Cloak")
	var wind := cloak.get_node("CloakAnimation") as AnimationPlayer
	var fabric := cloak.get_node("Fabric") as Polygon2D
	var anchor := cloak.get_node("Skeleton2D/Anchor") as Bone2D
	var hem := anchor.get_node("Upper/Middle/Hem") as Bone2D
	var body := rig.get_node("AnimationPlayer") as AnimationPlayer
	assert(wind.current_animation == "wind")
	for vertex in fabric.polygon.size():
		var total := 0.0
		for bone in fabric.get_bone_count():
			total += fabric.get_bone_weights(bone)[vertex]
		assert(is_equal_approx(total, 1.0), "Every cloth vertex must be fully weighted")
	wind.pause()
	wind.seek(0.0, true)
	var initial := hem.rotation
	wind.seek(1.0, true)
	assert(absf(hem.rotation - initial) > 0.01, "Hem should move in the wind")
	wind.seek(4.0, true)
	assert(is_equal_approx(hem.rotation, initial), "Wind loop must join seamlessly")
	for facing in [1.0, -1.0]:
		rig.scale.x = 0.65 * facing
		for clip in ["idle", "run", "bow_aim", "throw_aim"]:
			body.play("RESET")
			body.advance(0.0)
			body.play(clip)
			body.advance(0.2)
			wind.seek(1.0, true)
			await process_frame
			assert(anchor.rotation == 0.0, "Cloak neckline must stay anchored")
			assert(fabric.scale == Vector2.ONE)
			assert(absf(hem.rotation - initial) > 0.01, "Body clips must not reset wind")
			if clip == "idle" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/cloak_%s.png" % ("right" if facing > 0 else "left"))
	for facing in [1.0, -1.0]:
		rig.scale.x = 0.65 * facing
		for clip in ["jump", "fall"]:
			body.play("RESET")
			body.advance(0.0)
			body.play(clip)
			body.advance(0.2)
			wind.play(clip)
			wind.advance(0.0)
			wind.pause()
			wind.seek(0.0, true)
			var start_rotation := hem.rotation
			wind.seek(2.0, true)
			assert(is_equal_approx(hem.rotation, start_rotation), "Air cloth loops must join")
			wind.seek(0.5, true)
			var upper := anchor.get_node("Upper") as Bone2D
			assert(upper.rotation < -0.4 if clip == "jump" else upper.rotation > 0.6)
			assert(anchor.rotation == 0.0)
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/cloak_%s_%s.png" % [clip, "right" if facing > 0 else "left"])
	var upper := anchor.get_node("Upper") as Bone2D
	wind.play("wind")
	wind.advance(0.1)
	for clip in ["jump", "fall", "wind"]:
		var previous_rotation := upper.rotation
		wind.play(clip, 0.22)
		wind.advance(0.01)
		assert(absf(upper.rotation - previous_rotation) < 0.1, "Cloth transitions must not snap")
		wind.advance(0.3)
		assert(wind.current_animation == clip)
	rig.queue_free()
	await process_frame
	print("Darklight cloak: PASS (weights, wind/jump/fall, loops, blends, anchor, both facings)")
	quit()
