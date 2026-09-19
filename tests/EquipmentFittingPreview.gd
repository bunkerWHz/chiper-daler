@tool
extends Node2D
## Editor-only fitting adjustments are saved in this scene, not in item resources.

const RIG := preload("res://game/player/darklight/DarklightRig.tscn")
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

@export_group("OffHand")
@export var off_hand_item: ItemData:
	set(value):
		off_hand_item = value
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

var _rig: Node2D
var _pending: bool = false
var _holders: Array[Node2D] = []


func _ready() -> void:
	# Generated children have no owner: saving the preview never bakes rig edits.
	_rig = RIG.instantiate() as Node2D
	_rig.name = "FittingRig"
	add_child(_rig)
	_refresh()


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
	if not is_instance_valid(_rig):
		return
	for holder: Node2D in _holders:
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
	var hand := _rig.get_node("CharacterContainer/VisualDetails/" + hand_name) as Sprite2D
	hand.texture = null
	hand.visible = item != null
	if item == null:
		return
	var holder := Node2D.new()
	holder.name = "FittingItem"
	holder.position = offset
	holder.rotation_degrees = angle
	holder.scale = Vector2.ONE * size
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
		var grip := hand.get_node("ShieldGrip") if ratio > 0.0 else hand
		grip.add_child(holder)
	else:
		hand.add_child(holder)
		if item.equipped_visual != null:
			holder.add_child(item.equipped_visual.instantiate())


func _draw() -> void:
	draw_line(Vector2(-700, 735), Vector2(700, 735), Color(0.4, 0.5, 0.6, 0.5), 2.0)
