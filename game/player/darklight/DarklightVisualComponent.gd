extends AnimationComponent
class_name DarklightVisualComponent

@export_group("Bow aiming pose")
@export_range(0.0, 1.0, 0.01) var bow_head_follow: float = 0.25
@export_range(-90.0, 90.0, 0.1) var bow_shoulder_offset_degrees: float = 0.0

@export_group("Item effects")
@export var heal_effect_frames: SpriteFrames
@export var mana_effect_frames: SpriteFrames
@export var rage_effect_frames: SpriteFrames
@export var buff_effect_frames: SpriteFrames

var _equipment: EquipmentComponent
var _item_use: ItemUseComponent
var _status_effects: StatusEffectComponent
var _item_effect_sprite: AnimatedSprite2D
var _buff_effect_sprite: AnimatedSprite2D
var _effect_frames: Dictionary = {}
var _rig: Node2D
var _main_hand: Sprite2D
var _off_hand: Sprite2D
var _quiver: Sprite2D
var _hand_visuals: Dictionary = {}
var _aim: AimingComponent
var _ranged: RangedWeaponComponent
var _bow_pose_active: bool = false
var _bow_arm: Node2D
var _head_ik: SoupLookAt
var _saved_fk_angles := Vector3.ZERO
var _saved_head_rotation: float = 0.0
var _saved_head_enabled: bool = true
var _saved_arm_mode: int = 0
var _saved_wrist_target: Transform2D


func on_initialize() -> void:
	super.on_initialize()
	if not is_enabled:
		return
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_item_use = actor.get_component(ItemUseComponent) as ItemUseComponent
	_status_effects = (
		actor.get_component(StatusEffectComponent) as StatusEffectComponent
	)
	if _equipment == null or _item_use == null or _status_effects == null:
		push_error(
			"DarklightVisualComponent requires equipment, item use, and status effects"
		)
		disable()
		return
	if not _equipment.loadout_item_changed.is_connected(
		_on_loadout_item_changed
	):
		_equipment.loadout_item_changed.connect(_on_loadout_item_changed)
	if not _equipment.weapon_set_changed.is_connected(_on_weapon_set_changed):
		_equipment.weapon_set_changed.connect(_on_weapon_set_changed)
	if not _item_use.item_use_started.is_connected(_on_item_use_started):
		_item_use.item_use_started.connect(_on_item_use_started)
	if not _item_use.item_use_cancelled.is_connected(_on_item_use_cancelled):
		_item_use.item_use_cancelled.connect(_on_item_use_cancelled)
	if not _status_effects.effect_applied.is_connected(
		_on_status_effect_applied
	):
		_status_effects.effect_applied.connect(_on_status_effect_applied)


func _ready() -> void:
	if not is_enabled:
		return
	_rig = actor.get_node("_Visual/DarklightRig") as Node2D
	_aim = actor.get_component(AimingComponent) as AimingComponent
	if _aim != null and not _aim.launch_position_requested.is_connected(_sync_bow_launch_origin):
		_aim.launch_position_requested.connect(_sync_bow_launch_origin)
	_ranged = actor.get_component(RangedWeaponComponent) as RangedWeaponComponent
	_bow_arm = _rig.get_node("CharacterContainer/Anim Targets/BackArmFK") as Node2D
	_head_ik = _rig.get_node("CharacterContainer/Skeleton2D/SoupGroup/Head/Head_AT") as SoupLookAt
	# Apply the dynamic pose after animation and SoupIK/FK evaluation.
	process_priority = 2
	_animation_player = _rig.get_node("AnimationPlayer") as AnimationPlayer
	_main_hand = _rig.get_node("CharacterContainer/VisualDetails/MainHand") as Sprite2D
	_off_hand = _rig.get_node("CharacterContainer/VisualDetails/OffHand") as Sprite2D
	_quiver = _rig.get_node("CharacterContainer/VisualDetails/Arrows") as Sprite2D
	_item_effect_sprite = actor.get_node("_Visual/ItemEffectSprite") as AnimatedSprite2D
	_buff_effect_sprite = actor.get_node("_Visual/BuffEffectSprite") as AnimatedSprite2D
	_build_effect_frames()
	_item_effect_sprite.animation_finished.connect(_hide_item_effect)
	_buff_effect_sprite.animation_finished.connect(_hide_buff_effect)
	_refresh_equipment_visuals()
	_apply_state(_actor_state_component.get_state(), true)
	_apply_facing(_facing_component.get_direction())


func _on_state_changed(_previous: ActorState.Behavior, current: ActorState.Behavior) -> void:
	if is_enabled and _animation_player != null:
		_apply_state(current)


func _on_facing_changed(_previous: FacingComponent.Direction, current: FacingComponent.Direction) -> void:
	if is_enabled and _rig != null:
		_apply_facing(current)


func _apply_facing(direction: FacingComponent.Direction) -> void:
	# Skeleton2D and skinned polygons have no flip_h. Reflect the whole visual rig,
	# including IK targets and hand attachments; physics stays on the actor root.
	_rig.transform = Transform2D(Vector2(float(direction), 0), Vector2.DOWN, Vector2.ZERO)


func _play_animation(animation_name: StringName) -> void:
	_end_bow_pose()
	# Source attack clips animate only the arms. Restore the base pose first so a
	# previous dodge/jump cannot leave stale leg/hip targets in a later animation.
	_animation_player.play(&"RESET")
	_animation_player.advance(0.0)
	_refresh_equipment_visuals()
	var speed := 1.0
	if animation_name in [&"attack", &"heavy_attack", &"air_attack", &"air_heavy_attack"]:
		var attack := actor.get_component(AttackComponent) as AttackComponent
		var heavy := animation_name in [&"heavy_attack", &"air_heavy_attack"]
		speed = _animation_player.get_animation(animation_name).length / attack.get_attack_duration(heavy)
	elif animation_name == &"dodge":
		var dodge := actor.get_component(DodgeComponent) as DodgeComponent
		speed = _animation_player.get_animation(animation_name).length / dodge.config.duration
	elif animation_name == &"equipment_swap":
		var swap := actor.get_component(EquipmentSwapComponent) as EquipmentSwapComponent
		if swap.is_swapping():
			speed = _animation_player.get_animation(animation_name).length / swap.get_duration()
	_animation_player.play(animation_name, 0.0, speed)
	_animation_player.advance(0.0)
	if _current_state in [ActorState.Behavior.DEAD, ActorState.Behavior.RESPAWNING]:
		_animation_player.pause()


func _process(_delta: float) -> void:
	if _bow_arm == null:
		return
	var aiming_bow := (is_enabled and _ranged != null and _aim != null
		and _ranged.get_phase() == RangedWeaponComponent.Phase.BOW_AIM
		and _aim.is_aiming())
	if not aiming_bow:
		_end_bow_pose()
		return
	var shoulder := _bow_arm.get_node("Shoulder") as Marker2D
	var elbow := _bow_arm.get_node("Shoulder/Elbow") as Marker2D
	var wrist := _bow_arm.get_node("Shoulder/Elbow/Wrist") as Marker2D
	if not _bow_pose_active:
		_saved_fk_angles = Vector3(shoulder.rotation, elbow.rotation, wrist.rotation)
		_saved_arm_mode = _bow_arm.mode
		_saved_head_rotation = _head_ik.bone_node.rotation
		_saved_head_enabled = _head_ik.enabled
		_saved_wrist_target = _bow_arm.wrist_ik.target_node.transform
		_bow_pose_active = true
	_bow_arm.mode = 1
	_head_ik.enabled = false
	# Convert world aim to the right-facing rig's local angle; reflection handles left.
	var direction := _aim.get_direction()
	var aim_angle := atan2(direction.y, absf(direction.x))
	var upper_angle: float = _bow_arm.elbow_bone.position.angle()
	var forearm_angle: float = _bow_arm.wrist_bone.position.angle()
	var hip := _bow_arm.shoulder_bone.get_parent() as Node2D
	var arm_angle := aim_angle + deg_to_rad(bow_shoulder_offset_degrees)
	shoulder.rotation = -upper_angle + arm_angle - hip.rotation
	elbow.rotation = upper_angle - forearm_angle
	# The drawn hand reaches toward the authored grip, not the bone's +X axis.
	var grip := _bow_arm.wrist_bone.get_node("OffHand") as Node2D
	var grip_angle := grip.position.angle()
	wrist.rotation = forearm_angle - grip_angle
	_bow_arm._process(0.0)
	# Move the wrist look-at around the shoulder together with the bow hand.
	# Its original stationary target would bend the wrist away from the shot.
	var aim_axis := Vector2.from_angle(
		arm_angle - grip_angle + _bow_arm.wrist_bone.get_bone_angle()
	)
	var world_axis := _rig.global_transform.basis_xform(aim_axis)
	_bow_arm.wrist_ik.target_node.global_position = (
		_bow_arm.wrist_bone.global_position + world_axis * 100.0
	)
	_bow_arm.wrist_ik.enabled = true
	_bow_arm.wrist_ik._process_loop(0.0)
	_head_ik.bone_node.rotation = _saved_head_rotation + aim_angle * bow_head_follow
	_aim.set_launch_origin(_ranged, grip)


func _sync_bow_launch_origin() -> void:
	# A tap can fire before the visual's first process tick. Pose it before reading
	# the origin; use the bone attachment, not the deferred RemoteTransform sprite.
	if is_enabled and _ranged != null and _ranged.get_phase() == RangedWeaponComponent.Phase.BOW_AIM:
		_process(0.0)


func _end_bow_pose() -> void:
	if not _bow_pose_active:
		return
	_bow_pose_active = false
	_aim.set_launch_origin(_ranged, null)
	_bow_arm.get_node("Shoulder").rotation = _saved_fk_angles.x
	_bow_arm.get_node("Shoulder/Elbow").rotation = _saved_fk_angles.y
	_bow_arm.get_node("Shoulder/Elbow/Wrist").rotation = _saved_fk_angles.z
	_bow_arm.mode = _saved_arm_mode
	_bow_arm.wrist_ik.target_node.transform = _saved_wrist_target
	_head_ik.enabled = _saved_head_enabled
	_head_ik.bone_node.rotation = _saved_head_rotation
	_bow_arm.arm_ik._process_loop(0.0)
	_bow_arm.wrist_ik._process_loop(0.0)
	if _saved_arm_mode == 1:
		_bow_arm._process(0.0)


func disable() -> void:
	_end_bow_pose()
	super.disable()


func get_item_effect_sprite() -> AnimatedSprite2D:
	return _item_effect_sprite


func get_buff_effect_sprite() -> AnimatedSprite2D:
	return _buff_effect_sprite


func _get_animation_name(state: ActorState.Behavior) -> StringName:
	match state:
		ActorState.Behavior.RUN: return &"run"
		ActorState.Behavior.JUMP, ActorState.Behavior.DOUBLE_JUMP: return &"jump"
		ActorState.Behavior.WALL_JUMP: return &"wall_jump"
		ActorState.Behavior.FALL: return &"fall"
		ActorState.Behavior.DODGE: return &"dodge"
		ActorState.Behavior.GROUND_LIGHT_ATTACK, ActorState.Behavior.CRITICAL_ATTACK: return &"attack"
		ActorState.Behavior.GROUND_HEAVY_ATTACK: return &"heavy_attack"
		ActorState.Behavior.AIR_LIGHT_ATTACK: return &"air_attack"
		ActorState.Behavior.AIR_HEAVY_ATTACK: return &"air_heavy_attack"
		ActorState.Behavior.BLOCKING, ActorState.Behavior.PARRYING: return &"block"
		ActorState.Behavior.EQUIPMENT_SWAP: return &"equipment_swap"
	# Bow aim uses a procedural upper-body pose over the idle clip.
	# The source has no magic, item-use, climbing, hit or death clips yet.
	# Keep those states controlled by gameplay, with an explicit idle-pose fallback.
	return &"idle"


func _build_effect_frames() -> void:
	_effect_frames[ItemData.UseVisualEffect.HEAL] = heal_effect_frames
	_effect_frames[ItemData.UseVisualEffect.MANA] = mana_effect_frames
	_effect_frames[ItemData.UseVisualEffect.RAGE] = rage_effect_frames
	_buff_effect_sprite.sprite_frames = buff_effect_frames


func _refresh_equipment_visuals() -> void:
	if _main_hand == null:
		return
	var displayed: Dictionary = {}
	var show_quiver := false
	# Main-hand equipment wins if both items target the same visual attachment.
	for slot: ItemData.EquipSlot in [ItemData.EquipSlot.OFF_HAND, ItemData.EquipSlot.MAIN_HAND]:
		var item := _equipment.get_equipped_item(slot)
		if item == null:
			continue
		if item.category == ItemData.Category.AMMUNITION:
			show_quiver = show_quiver or item.get_ammunition_type() in [&"arrow", &"bolt"]
			continue
		displayed[item.get_display_slot(slot)] = item
	_update_hand(_main_hand, displayed.get(ItemData.EquipSlot.MAIN_HAND) as ItemData)
	_update_hand(_off_hand, displayed.get(ItemData.EquipSlot.OFF_HAND) as ItemData)
	_quiver.visible = show_quiver


func _update_hand(hand: Sprite2D, item: ItemData) -> void:
	# Pose resets preserve the authored grip offsets and existing attachments.
	if hand.has_meta(&"equipped_item") and hand.get_meta(&"equipped_item") == item:
		return
	hand.set_meta(&"equipped_item", item)
	var previous := _hand_visuals.get(hand) as Node
	if is_instance_valid(previous):
		hand.remove_child(previous)
		previous.queue_free()
	_hand_visuals.erase(hand)
	hand.texture = null
	hand.visible = item != null
	if item == null:
		return
	if item.equipped_texture != null:
		hand.texture = item.equipped_texture
		return
	if item.equipped_visual != null:
		var visual := item.equipped_visual.instantiate()
		if visual is Node2D:
			hand.add_child(visual)
			_hand_visuals[hand] = visual
			return
		visual.free()
	hand.visible = false


func _on_loadout_item_changed(
	slot: ItemData.EquipSlot,
	_slot_index: int,
	weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	if (
		slot in [ItemData.EquipSlot.MAIN_HAND, ItemData.EquipSlot.OFF_HAND]
		and weapon_set == _equipment.get_active_weapon_set()
	):
		_refresh_equipment_visuals()


func _on_weapon_set_changed(_previous: int, _current: int) -> void:
	_refresh_equipment_visuals()


func _on_item_use_started(item: ItemData) -> void:
	var visual_effect := (
		item.get_use_visual_effect()
		if item != null
		else ItemData.UseVisualEffect.HEAL
	)
	if not _effect_frames.has(visual_effect):
		_hide_item_effect()
		return
	_item_effect_sprite.sprite_frames = (
		_effect_frames[visual_effect] as SpriteFrames
	)
	_item_effect_sprite.visible = true
	_item_effect_sprite.play(&"effect")


func _on_item_use_cancelled() -> void:
	_hide_item_effect()


func _on_status_effect_applied(_effect: StatusEffect) -> void:
	_buff_effect_sprite.visible = true
	_buff_effect_sprite.play(&"effect")


func _hide_item_effect() -> void:
	if _item_effect_sprite == null:
		return
	_item_effect_sprite.stop()
	_item_effect_sprite.visible = false


func _hide_buff_effect() -> void:
	if _buff_effect_sprite == null:
		return
	_buff_effect_sprite.stop()
	_buff_effect_sprite.visible = false


func should_disable_on_actor_death() -> bool:
	return false
