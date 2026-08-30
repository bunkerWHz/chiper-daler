extends AnimationComponent
class_name TemporaryPlayerVisualComponent

const WARRIOR_IDLE := preload(
	"res://assets/Test/Hero/Warrior/Warrior_Idle.png"
)
const WARRIOR_RUN := preload(
	"res://assets/Test/Hero/Warrior/Warrior_Run.png"
)
const WARRIOR_ATTACK := preload(
	"res://assets/Test/Hero/Warrior/Warrior_Attack1.png"
)
const WARRIOR_GUARD := preload(
	"res://assets/Test/Hero/Warrior/Warrior_Guard.png"
)
const ARCHER_IDLE := preload(
	"res://assets/Test/Hero/Archer/Archer_Idle.png"
)
const ARCHER_RUN := preload(
	"res://assets/Test/Hero/Archer/Archer_Run.png"
)
const ARCHER_ATTACK := preload(
	"res://assets/Test/Hero/Archer/Archer_Shoot.png"
)
const LANCER_IDLE := preload(
	"res://assets/Test/Hero/Lancer/Lancer_Idle.png"
)
const LANCER_RUN := preload(
	"res://assets/Test/Hero/Lancer/Lancer_Run.png"
)
const LANCER_ATTACK := preload(
	"res://assets/Test/Hero/Lancer/Lancer_Right_Attack.png"
)
const LANCER_GUARD := preload(
	"res://assets/Test/Hero/Lancer/Lancer_Right_Defence.png"
)
const HEAL_EFFECT := preload("res://assets/Test/Heal_Effect.png")
const MANA_EFFECT := preload("res://assets/Test/Mana_Effect.png")
const RAGE_EFFECT := preload("res://assets/Test/Rage_effect.png")
const BUFF_EFFECT := preload("res://assets/Test/buff_effect.png")

const STANDARD_FRAME_SIZE := Vector2i(192, 192)
const LANCER_FRAME_SIZE := Vector2i(320, 320)
const EFFECT_FRAME_SIZE := Vector2i(192, 192)
const EFFECT_FRAME_RATE := 22.0

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
	_profiles[ItemData.VisualArchetype.WARRIOR] = _create_profile(
		WARRIOR_IDLE,
		WARRIOR_RUN,
		WARRIOR_ATTACK,
		WARRIOR_GUARD,
		STANDARD_FRAME_SIZE
	)
	_profiles[ItemData.VisualArchetype.ARCHER] = _create_profile(
		ARCHER_IDLE,
		ARCHER_RUN,
		ARCHER_ATTACK,
		ARCHER_IDLE,
		STANDARD_FRAME_SIZE,
		1
	)
	_profiles[ItemData.VisualArchetype.LANCER] = _create_profile(
		LANCER_IDLE,
		LANCER_RUN,
		LANCER_ATTACK,
		LANCER_GUARD,
		LANCER_FRAME_SIZE
	)


func _create_profile(
	idle_texture: Texture2D,
	run_texture: Texture2D,
	attack_texture: Texture2D,
	guard_texture: Texture2D,
	frame_size: Vector2i,
	guard_frame_limit: int = -1
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_strip(frames, &"idle", idle_texture, frame_size, 8.0, true)
	_add_strip(frames, &"run", run_texture, frame_size, 8.0, true)
	_add_strip(frames, &"attack", attack_texture, frame_size, 16.0, false)
	_add_strip(
		frames,
		&"guard",
		guard_texture,
		frame_size,
		10.0,
		false,
		guard_frame_limit
	)
	_add_strip(frames, &"jump", idle_texture, frame_size, 1.0, false, 1)
	_add_strip(frames, &"fall", idle_texture, frame_size, 1.0, false, 1)
	return frames


func _build_effect_frames() -> void:
	var item_effect_speed := (
		float(HEAL_EFFECT.get_width() / EFFECT_FRAME_SIZE.x)
		/ maxf(_item_use.config.use_duration, 0.01)
	)
	_effect_frames[ItemData.UseVisualEffect.HEAL] = _create_effect_frames(
		HEAL_EFFECT, item_effect_speed
	)
	_effect_frames[ItemData.UseVisualEffect.MANA] = _create_effect_frames(
		MANA_EFFECT, item_effect_speed
	)
	_effect_frames[ItemData.UseVisualEffect.RAGE] = _create_effect_frames(
		RAGE_EFFECT, item_effect_speed
	)
	_buff_effect_sprite.sprite_frames = _create_effect_frames(
		BUFF_EFFECT, EFFECT_FRAME_RATE
	)


func _create_effect_frames(texture: Texture2D, speed: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_strip(
		frames,
		&"effect",
		texture,
		EFFECT_FRAME_SIZE,
		speed,
		false
	)
	return frames


func _add_strip(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	frame_size: Vector2i,
	speed: float,
	loop: bool,
	frame_limit: int = -1
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, loop)
	var frame_count := int(texture.get_width() / frame_size.x)
	if frame_limit > 0:
		frame_count = mini(frame_count, frame_limit)
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			frame_index * frame_size.x,
			0,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(animation_name, atlas)


func _refresh_visual_profile() -> void:
	if _sprite == null or _profiles.is_empty():
		return
	var item := _equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	var profile := ItemData.VisualArchetype.WARRIOR
	if item != null:
		profile = item.visual_archetype
		if profile == ItemData.VisualArchetype.DEFAULT:
			profile = (
				ItemData.VisualArchetype.ARCHER
				if item.combat_mode in [
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
		item.use_visual_effect
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
