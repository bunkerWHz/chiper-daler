@tool
extends Node2D
## Fit equipment in the editor, then explicitly save its placement into ItemData.

const RIG_PATH := "res://game/player/darklight/DarklightRig.tscn"
const MAIN_HAND_PATH := "CharacterContainer/Skeleton2D/Hip/FrontArmTop/FrontArmMid/FrontArmBot/MainHand"
const OFF_HAND_PATH := "CharacterContainer/Skeleton2D/Hip/BackArmTop/BackArmMid/BackArmBot/OffHand"
const SIZING := preload("res://features/inventory/ItemVisualSizing.gd")

@export_group("Pose")
@export var animation: StringName = &"idle":
	set(value):
		animation = value
		_schedule_refresh()
@export_range(0.0, 10.0, 0.01) var pose_time: float = 0.0:
	set(value):
		pose_time = value
		_schedule_refresh()
@export var face_left: bool = false:
	set(value):
		face_left = value
		_schedule_refresh()
@export var show_quiver: bool = false:
	set(value):
		show_quiver = value
		_schedule_refresh()

@export_group("MainHand")
@export var main_hand_item: ItemData:
	set(value):
		main_hand_item = value
		_load_item_fit(true)
		_schedule_refresh()
@export_range(0.01, 5.0, 0.01, "or_greater") var main_hand_scale: float = 1.0:
	set(value):
		main_hand_scale = value
		_schedule_refresh()
@export var main_hand_offset := Vector2.ZERO:
	set(value):
		main_hand_offset = value
		_schedule_refresh()
@export_range(-180.0, 180.0, 0.1) var main_hand_rotation_degrees: float = 0.0:
	set(value):
		main_hand_rotation_degrees = value
		_schedule_refresh()
@export_tool_button("Save MainHand to item") var save_main_hand = _save_main_hand
@export_tool_button("Reload MainHand from item") var reload_main_hand = _load_item_fit.bind(true)

@export_group("OffHand")
@export var off_hand_item: ItemData:
	set(value):
		off_hand_item = value
		_load_item_fit(false)
		_schedule_refresh()
@export_range(0.01, 5.0, 0.01, "or_greater") var off_hand_scale: float = 1.0:
	set(value):
		off_hand_scale = value
		_schedule_refresh()
@export var off_hand_offset := Vector2.ZERO:
	set(value):
		off_hand_offset = value
		_schedule_refresh()
@export_range(-180.0, 180.0, 0.1) var off_hand_rotation_degrees: float = 0.0:
	set(value):
		off_hand_rotation_degrees = value
		_schedule_refresh()
@export_tool_button("Save OffHand to item") var save_off_hand = _save_off_hand
@export_tool_button("Reload OffHand from item") var reload_off_hand = _load_item_fit.bind(false)

@export_group("Save result")
@export_multiline var save_status: String = "Choose an item .tres, fit it, then press Save for that hand."

var _rig: Node2D
var _pending: bool = false
var _holders: Array[Node2D] = []


func _load_item_fit(main: bool) -> void:
	var item := main_hand_item if main else off_hand_item
	var size := item.equipped_scale if item != null else 1.0
	var offset := item.equipped_offset if item != null else Vector2.ZERO
	var angle := item.equipped_rotation_degrees if item != null else 0.0
	if main:
		main_hand_scale = size
		main_hand_offset = offset
		main_hand_rotation_degrees = angle
	else:
		off_hand_scale = size
		off_hand_offset = offset
		off_hand_rotation_degrees = angle


func _save_main_hand() -> void:
	_save_item_fit(true)


func _save_off_hand() -> void:
	_save_item_fit(false)


func _save_item_fit(main: bool) -> Error:
	var item := main_hand_item if main else off_hand_item
	if item == null or not item.resource_path.begins_with("res://") or not item.resource_path.ends_with(".tres") or item.is_built_in():
		save_status = "Assign an external item .tres first. For a new item, use Save As in its Inspector."
		return ERR_INVALID_PARAMETER
	# Save a copy first so failure cannot change the loaded gameplay resource.
	var saved := item.duplicate() as ItemData
	saved.equipped_scale = main_hand_scale if main else off_hand_scale
	saved.equipped_offset = main_hand_offset if main else off_hand_offset
	saved.equipped_rotation_degrees = main_hand_rotation_degrees if main else off_hand_rotation_degrees
	var error := ResourceSaver.save(saved, item.resource_path)
	if error != OK:
		save_status = "Save failed: " + error_string(error)
		return error
	item.equipped_scale = saved.equipped_scale
	item.equipped_offset = saved.equipped_offset
	item.equipped_rotation_degrees = saved.equipped_rotation_degrees
	item.emit_changed()
	save_status = "Saved: " + item.resource_path
	notify_property_list_changed()
	return OK


func _ready() -> void:
	_refresh()


func _ensure_rig() -> bool:
	# Tool scripts reload without rerunning _ready; their generated scene may
	# still contain the old RemoteTransform2D hands after the rig was reparented.
	if is_instance_valid(_rig) and _rig.get_node_or_null(MAIN_HAND_PATH) is Sprite2D and _rig.get_node_or_null(OFF_HAND_PATH) is Sprite2D:
		return true
	if not is_instance_valid(_rig):
		_rig = get_node_or_null("FittingRig") as Node2D
	# Bypass the editor's cached PackedScene when recovering an obsolete rig.
	var packed := ResourceLoader.load(RIG_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		save_status = "Cannot load the Darklight rig."
		return false
	var replacement := packed.instantiate() as Node2D
	if replacement == null or not replacement.get_node_or_null(MAIN_HAND_PATH) is Sprite2D or not replacement.get_node_or_null(OFF_HAND_PATH) is Sprite2D:
		if replacement != null:
			replacement.free()
		save_status = "Darklight rig must have MainHand / OffHand sprites under the wrist bones."
		return false
	_holders.clear()
	if is_instance_valid(_rig):
		remove_child(_rig)
		_rig.queue_free()
	_rig = replacement
	_rig.name = "FittingRig"
	# No owner: the generated rig is never baked into the fitting scene.
	add_child(_rig)
	return true


func _validate_property(property: Dictionary) -> void:
	if property.name == "animation" and is_instance_valid(_rig):
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join((_rig.get_node("AnimationPlayer") as AnimationPlayer).get_animation_list())


func _schedule_refresh() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_refresh.call_deferred()


func _refresh() -> void:
	_pending = false
	if not is_inside_tree() or not _ensure_rig():
		return
	for holder: Node2D in _holders:
		if is_instance_valid(holder):
			if holder.get_parent() != null:
				holder.get_parent().remove_child(holder)
			holder.queue_free()
	_holders.clear()
	var player := _rig.get_node("AnimationPlayer") as AnimationPlayer
	player.play(&"RESET")
	player.advance(0.0)
	var clip := animation if player.has_animation(animation) else &"idle"
	player.play(clip)
	player.seek(minf(pose_time, player.get_animation(clip).length), true)
	player.pause()
	_rig.scale = Vector2(-1.0 if face_left else 1.0, 1.0)
	_rig.get_node("CharacterContainer/VisualDetails/Arrows").visible = show_quiver
	_fit_hand("MainHand", main_hand_item, main_hand_scale, main_hand_offset, main_hand_rotation_degrees)
	_fit_hand("OffHand", off_hand_item, off_hand_scale, off_hand_offset, off_hand_rotation_degrees)
	notify_property_list_changed()
	queue_redraw()


func _fit_hand(hand_name: String, item: ItemData, size: float, offset: Vector2, angle: float) -> void:
	var hand := _rig.get_node_or_null(MAIN_HAND_PATH if hand_name == "MainHand" else OFF_HAND_PATH) as Sprite2D
	if hand == null:
		return
	hand.texture = null
	hand.visible = item != null
	if item == null:
		return
	var holder := Node2D.new()
	holder.name = "FittingItem"
	holder.position = offset
	holder.rotation_degrees = angle
	holder.scale = Vector2.ONE * size
	holder.z_index = item.equipped_z_index
	_holders.append(holder)
	if item.equipped_texture != null:
		var ratio := SIZING.shield_ratio(item)
		var maximum := 970.0 * (ratio if ratio > 0.0 else 1.0)
		holder.scale *= SIZING.fit_scale(item.equipped_texture, maximum, ratio > 0.0)
		var sprite := Sprite2D.new()
		sprite.texture = item.equipped_texture
		sprite.centered = false if ratio > 0.0 else hand.centered
		sprite.offset = -SIZING.visible_rect(item.equipped_texture).get_center() if ratio > 0.0 else hand.offset
		holder.add_child(sprite)
		hand.add_child(holder)
	else:
		hand.add_child(holder)
		if item.equipped_visual != null:
			holder.add_child(item.equipped_visual.instantiate())


func _draw() -> void:
	draw_line(Vector2(-700, 735), Vector2(700, 735), Color(0.4, 0.5, 0.6, 0.5), 2.0)
