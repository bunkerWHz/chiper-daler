extends AnimationComponent
class_name TemporaryPlayerVisualComponent

@export var warrior_frames: SpriteFrames
@export var archer_frames: SpriteFrames
@export var lancer_frames: SpriteFrames
@export var heal_effect_frames: SpriteFrames
@export var mana_effect_frames: SpriteFrames
@export var rage_effect_frames: SpriteFrames
@export var buff_effect_frames: SpriteFrames

var _equipment: EquipmentComponent
var _item_use: ItemUseComponent
var _status_effects: StatusEffectComponent
var _item_effect_sprite: AnimatedSprite2D
var _buff_effect_sprite: AnimatedSprite2D
var _profiles: Dictionary = {}
var _effect_frames: Dictionary = {}
var _current_profile: ItemData.VisualArchetype = (
	ItemData.VisualArchetype.WARRIOR
)


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
			"TemporaryPlayerVisualComponent requires equipment, item use, and status effects"
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
	super._ready()
	if not is_enabled:
		return
	_item_effect_sprite = actor.get_node_or_null(
		"_Visual/ItemEffectSprite"
	) as AnimatedSprite2D
	_buff_effect_sprite = actor.get_node_or_null(
		"_Visual/BuffEffectSprite"
	) as AnimatedSprite2D
	if _item_effect_sprite == null or _buff_effect_sprite == null:
		push_error(
			"TemporaryPlayerVisualComponent requires both visual effect sprites"
		)
		disable()
		return
	_build_profiles()
	_build_effect_frames()
	if _profiles.values().has(null) or _effect_frames.values().has(null):
		push_error("TemporaryPlayerVisualComponent requires configured SpriteFrames")
		disable()
		return
	_item_effect_sprite.animation_finished.connect(_hide_item_effect)
	_buff_effect_sprite.animation_finished.connect(_hide_buff_effect)
	_refresh_visual_profile()


func get_visual_profile() -> ItemData.VisualArchetype:
	return _current_profile


func get_item_effect_sprite() -> AnimatedSprite2D:
	return _item_effect_sprite


func get_buff_effect_sprite() -> AnimatedSprite2D:
	return _buff_effect_sprite


func _get_animation_name(state: ActorState.Behavior) -> StringName:
	if state == ActorState.Behavior.USING_ITEM:
		return &"idle"
	return super._get_animation_name(state)


func _build_profiles() -> void:
	_profiles[ItemData.VisualArchetype.WARRIOR] = warrior_frames
	_profiles[ItemData.VisualArchetype.ARCHER] = archer_frames
	_profiles[ItemData.VisualArchetype.LANCER] = lancer_frames


func _build_effect_frames() -> void:
	_effect_frames[ItemData.UseVisualEffect.HEAL] = heal_effect_frames
	_effect_frames[ItemData.UseVisualEffect.MANA] = mana_effect_frames
	_effect_frames[ItemData.UseVisualEffect.RAGE] = rage_effect_frames
	_buff_effect_sprite.sprite_frames = buff_effect_frames


func _refresh_visual_profile() -> void:
	if _sprite == null or _profiles.is_empty():
		return
	var item := _equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	var profile := ItemData.VisualArchetype.WARRIOR
	if item != null:
		profile = item.get_visual_archetype()
		if profile == ItemData.VisualArchetype.DEFAULT:
			profile = (
				ItemData.VisualArchetype.ARCHER
				if item.get_combat_mode() in [
					ItemData.CombatMode.BOW,
					ItemData.CombatMode.CROSSBOW,
				]
				else ItemData.VisualArchetype.WARRIOR
			)
	_current_profile = profile
	_sprite.sprite_frames = _profiles[profile] as SpriteFrames
	_apply_state(_actor_state_component.get_state(), true)


func _on_loadout_item_changed(
	slot: ItemData.EquipSlot,
	_slot_index: int,
	weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	if (
		slot == ItemData.EquipSlot.MAIN_HAND
		and weapon_set == _equipment.get_active_weapon_set()
	):
		_refresh_visual_profile()


func _on_weapon_set_changed(_previous: int, _current: int) -> void:
	_refresh_visual_profile()


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
