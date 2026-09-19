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
	var main := rig.get_node("CharacterContainer/VisualDetails/MainHand") as Sprite2D
	var off := rig.get_node("CharacterContainer/VisualDetails/OffHand") as Sprite2D
	var holder := main.get_node("FittingItem") as Node2D
	var base_scale := holder.scale.x
	if not _require(main.visible and off.visible and holder.get_child(0).scale == Vector2.ONE, "Default items and native sprite scale"):
		return
	var shield := off.get_node("ShieldGrip/FittingItem") as Node2D
	var bounds: Rect2 = preload("res://features/inventory/ItemVisualSizing.gd").visible_rect(shield.get_child(0).texture)
	if not _require(is_equal_approx(bounds.size.y * shield.scale.y, minf(bounds.size.y, 970.0 * 0.3)), "Shield matches gameplay height"):
		return
	preview.main_hand_scale = 2.0
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
	preview.main_hand_item = null
	preview.off_hand_item = null
	await process_frame
	await process_frame
	if not _require(not main.visible and not off.visible and preview._holders.is_empty(), "Clearing slots removes preview items"):
		return
	preview.free()
	print("Equipment fitting preview checks passed; editor_hint=", Engine.is_editor_hint())
	quit(0)


func _require(condition: bool, label: String) -> bool:
	if not condition:
		push_error(label)
		quit(1)
	return condition
