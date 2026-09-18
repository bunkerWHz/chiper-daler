extends AnimationComponent
class_name DarklightVisualComponent

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
var _main_hand: Polygon2D
var _off_hand: Polygon2D


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
	_animation_player = _rig.get_node("AnimationPlayer") as AnimationPlayer
	_main_hand = _rig.get_node("CharacterContainer/VisualDetails/MainHand") as Polygon2D
	_off_hand = _rig.get_node("CharacterContainer/VisualDetails/OffHand") as Polygon2D
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
	# The source has no bow, magic, item-use, climbing, hit or death clips yet.
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
	_update_hand(_main_hand, ItemData.EquipSlot.MAIN_HAND)
	_update_hand(_off_hand, ItemData.EquipSlot.OFF_HAND)


func _update_hand(hand: Polygon2D, slot: ItemData.EquipSlot) -> void:
	var item := _equipment.get_equipped_item(slot)
	# Rebuild only on an actual equipment change; pose resets must keep attachments.
	if hand.has_meta(&"equipped_item") and hand.get_meta(&"equipped_item") == item:
		return
	hand.set_meta(&"equipped_item", item)
	for child in hand.get_children():
		hand.remove_child(child)
		child.queue_free()
	hand.texture = null
	hand.color = Color.TRANSPARENT
	hand.visible = item != null
	if item == null:
		return
	if item.equipped_visual != null:
		var visual := item.equipped_visual.instantiate()
		if visual is Node2D:
			hand.add_child(visual)
			return
		visual.free()
	# Items without authored world art retain the inventory icon as a placeholder.
	hand.color = Color.WHITE
	hand.texture = item.icon
	if hand.texture == null:
		hand.visible = false
		return
	var size := hand.texture.get_size()
	hand.uv = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var fitted := size * (450.0 / maxf(size.x, size.y))
	hand.polygon = PackedVector2Array([Vector2(0, -fitted.y / 2), Vector2(fitted.x, -fitted.y / 2), Vector2(fitted.x, fitted.y / 2), Vector2(0, fitted.y / 2)])


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
