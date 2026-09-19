@tool
extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var preview := load("res://tests/EquipmentFittingPreview.tscn").instantiate() as Node2D
	# The user can save any fitting setup; tests supply their own items.
	preview.main_hand_item = load("res://game/items/weapons/TrainingKatana.tres")
	preview.off_hand_item = load("res://game/items/offhand/TrainingBuckler.tres")
	root.add_child(preview)
	await process_frame
	await process_frame
	var rig := preview.get_node("FittingRig")
	# Save only a disposable fixture; never overwrite the player's real items.
	var fixture_path := "res://.godot/fitting_item_test.tres"
	var fixture := preview.main_hand_item.duplicate() as ItemData
	ResourceSaver.save(fixture, fixture_path)
	preview.main_hand_item = load(fixture_path)
	var main := rig.get_node("CharacterContainer/Skeleton2D/Hip/FrontArmTop/FrontArmMid/FrontArmBot/MainHand") as Sprite2D
	var off := rig.get_node("CharacterContainer/Skeleton2D/Hip/BackArmTop/BackArmMid/BackArmBot/OffHand") as Sprite2D
	var holder := main.get_node("FittingItem") as Node2D
	var base_scale := holder.scale.x
	if not _require(main.visible and off.visible and holder.get_child(0).scale == Vector2.ONE, "Default items and native sprite scale"):
		return
	var shield := off.get_node("FittingItem") as Node2D
	if not _require(is_equal_approx(shield.rotation, -0.7690259) and shield.z_index == 5, "Saved shield placement replaces the removed marker"):
		return
	var bounds: Rect2 = preload("res://features/inventory/ItemVisualSizing.gd").visible_rect(shield.get_child(0).texture)
	if not _require(is_equal_approx(bounds.size.y * shield.scale.y, minf(bounds.size.y, 970.0 * 0.3)), "Shield matches gameplay height"):
		return
	preview.main_hand_scale = 2.0
	preview.main_hand_offset = Vector2(35, -22)
	preview.main_hand_rotation_degrees = 17.0
	preview.off_hand_scale = 0.5
	preview.animation = &"heavy_attack"
	preview.pose_time = 0.2
	preview.face_left = true
	await process_frame
	await process_frame
	holder = main.get_node("FittingItem") as Node2D
	if not _require(is_equal_approx(holder.scale.x, base_scale * 2.0) and rig.scale.x == -1.0, "Live size and facing edits"):
		return
	var animation := rig.get_node("AnimationPlayer") as AnimationPlayer
	if not _require(not animation.is_playing() and is_equal_approx(animation.current_animation_position, 0.2), "Frozen authored pose"):
		return
	if not _require(preview._save_item_fit(true) == OK, "Save fitted item"):
		return
	var saved := ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
	if not _require(saved.equipped_offset == Vector2(35, -22) and saved.equipped_scale == 2.0 and saved.equipped_rotation_degrees == 17.0, "Placement survives disk reload"):
		return
	preview.main_hand_scale = 0.5
	preview.main_hand_item = saved
	await process_frame
	if not _require(preview.main_hand_scale == 2.0 and preview.main_hand_offset == saved.equipped_offset, "Selecting an item restores its saved fitting"):
		return
	preview.main_hand_item = null
	preview.off_hand_item = null
	await process_frame
	await process_frame
	if not _require(not main.visible and not off.visible and preview._holders.is_empty(), "Clearing slots removes preview items"):
		return
	# Reproduce an already-open editor preview retaining the pre-migration rig:
	# the old wrist child was a RemoteTransform2D, not a Sprite2D.
	var wrist := off.get_parent()
	off.reparent(rig.get_node("CharacterContainer/VisualDetails"))
	var old_proxy := RemoteTransform2D.new()
	old_proxy.name = "OffHand"
	wrist.add_child(old_proxy)
	var bow := load("res://game/items/weapons/TrainingBow.tres") as ItemData
	preview.off_hand_item = bow
	await process_frame
	await process_frame
	rig = preview.get_node("FittingRig")
	off = rig.get_node(preview.OFF_HAND_PATH) as Sprite2D
	if not _require(off != null and off.visible and off.get_node("FittingItem").get_child(0).texture == bow.equipped_texture, "TrainingBow recovers an obsolete editor rig"):
		return
	# A tool-script reload can also discard script fields while children survive.
	preview._rig = null
	preview._holders.clear()
	preview.off_hand_scale = 1.25
	await process_frame
	await process_frame
	rig = preview.get_node("FittingRig")
	off = rig.get_node(preview.OFF_HAND_PATH) as Sprite2D
	if not _require(off.get_child_count() == 1 and preview._holders.size() == 1, "Script reload rebuilds without duplicate items"):
		return
	var thrown := (load("res://game/items/throwables/TrainingStone.tres") as ItemData).duplicate(true) as ItemData
	var image := Image.create(1000, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	thrown.projectile_profile.texture = ImageTexture.create_from_image(image)
	thrown.equipped_scale = 4.0
	preview.projectile_item = thrown
	preview.projectile_angle_degrees = 30.0
	for player_scale in [0.1, 0.2]:
		preview.projectile_player_scale = player_scale
		await process_frame
		await process_frame
		var flight := preview.get_node("ProjectilePreview/FlightVisual") as Node2D
		if not _require(is_equal_approx(flight.scale.x * 1000.0, 970.0 * 0.3), "Projectile matches gameplay body ratio, independent of equipped scale"):
			return
		if not _require(flight.get_child(0).scale == Vector2.ONE and is_equal_approx(flight.rotation_degrees, 150.0), "Native projectile sprite and left-facing angle"):
			return
	preview.projectile_scale = 2.0
	await process_frame
	await process_frame
	var resized := preview.get_node("ProjectilePreview/FlightVisual") as Node2D
	if not _require(is_equal_approx(resized.scale.x * 1000.0, 970.0 * 0.3 * 2.0), "Projectile Scale immediately changes the visible flight size"):
		return
	var resized_scale := resized.scale.x
	preview.refresh_preview.call()
	await process_frame
	if not _require(is_equal_approx(preview.get_node("ProjectilePreview/FlightVisual").scale.x, resized_scale), "Explicit refresh preserves fitted size"):
		return
	preview._toggle_projectile()
	await process_frame
	if not _require(not preview.has_node("ProjectilePreview"), "Projectile button hides the sample"):
		return
	preview.projectile_item = null
	preview.main_hand_item = load("res://game/items/throwables/TrainingStone.tres")
	preview._toggle_projectile()
	await process_frame
	await process_frame
	if not _require(preview.get_node("ProjectilePreview/FlightVisual").get_child(0) is Polygon2D, "Untextured hand item uses the gameplay projectile fallback"):
		return
	var projectile_path := "res://.godot/fitting_projectile_test.tres"
	var projectile_fixture := (load("res://game/items/throwables/TrainingStone.tres") as ItemData).duplicate(true) as ItemData
	ResourceSaver.save(projectile_fixture, projectile_path)
	preview.projectile_item = ResourceLoader.load(projectile_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	preview.projectile_scale = 1.75
	if not _require(preview._save_projectile_fit() == OK, "Save projectile size"):
		return
	var reloaded_projectile := ResourceLoader.load(projectile_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
	if not _require(reloaded_projectile.projectile_profile.visual_scale == 1.75, "Flight size persists in item profile"):
		return
	preview.projectile_item = reloaded_projectile
	if not _require(preview.projectile_scale == 1.75, "Selecting the item loads its saved flight size"):
		return
	DirAccess.remove_absolute(projectile_path)
	preview.free()
	DirAccess.remove_absolute(fixture_path)
	print("Equipment fitting preview checks passed; editor_hint=", Engine.is_editor_hint())
	quit(0)


func _require(condition: bool, label: String) -> bool:
	if not condition:
		push_error(label)
		quit(1)
	return condition
