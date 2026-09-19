extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := load("res://game/player/darklight/DarklightRig.tscn").instantiate() as Node2D
	root.add_child(rig)
	rig.position = Vector2(400, 300)
	var animation := rig.get_node("AnimationPlayer") as AnimationPlayer
	var polygons := rig.get_node("CharacterContainer/Polygons").get_children()
	var main := rig.get_node("CharacterContainer/Skeleton2D/Hip/FrontArmTop/FrontArmMid/FrontArmBot/MainHand") as Sprite2D
	var off := rig.get_node("CharacterContainer/Skeleton2D/Hip/BackArmTop/BackArmMid/BackArmBot/OffHand") as Sprite2D
	var bases: Array[Transform2D] = []
	for polygon: Node2D in polygons:
		bases.append(polygon.transform)
	# Exercise deferred RemoteTransform2D notifications, not just the facing setter.
	for turn in 48:
		rig.transform = Transform2D(Vector2(0.5 if turn % 2 == 0 else -0.5, 0), Vector2(0, 0.5), rig.position)
		if turn % 8 == 0:
			animation.play(&"RESET")
			animation.advance(0.0)
			animation.play(&"idle" if turn % 16 == 0 else &"run")
		for frame in 8:
			await process_frame
			for hand: Sprite2D in [main, off]:
				if not hand.scale.is_equal_approx(Vector2.ONE) or hand.global_transform.determinant() * rig.global_transform.determinant() <= 0.0:
					push_error("Hand attachment lost native scale or facing: " + str(hand.name))
					quit(1)
					return
			for index in polygons.size():
				var polygon := polygons[index] as Node2D
				if not polygon.transform.x.is_equal_approx(bases[index].x) or not polygon.transform.y.is_equal_approx(bases[index].y):
					push_error("Skinned polygon basis changed after turn %s: %s" % [turn, polygon.name])
					quit(1)
					return
		if turn >= 46 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/darklight_facing_%s.png" % ("right" if turn % 2 == 0 else "left"))
	print("Darklight repeated facing: PASS (48 turns, idle/run, all skinned polygons)")
	rig.queue_free()
	await process_frame
	quit(0)
