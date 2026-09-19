@tool
extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var preview := load("res://tests/EquipmentFittingPreview.tscn").instantiate() as Node2D
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
	preview.free()
	DirAccess.remove_absolute(fixture_path)
	print("Equipment fitting preview checks passed; editor_hint=", Engine.is_editor_hint())
	quit(0)


func _require(condition: bool, label: String) -> bool:
	if not condition:
		push_error(label)
		quit(1)
	return condition
