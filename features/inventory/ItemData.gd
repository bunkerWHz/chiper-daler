extends Resource
class_name ItemData

const PLACEHOLDER_ICON: Texture2D = preload("res://assets/icon_placeholder.png")

enum Category {
	WEAPON,
	ARMOR,
	RING,
	AMULET,
	CONSUMABLE,
	SCROLL,
	THROWABLE,
	AMMUNITION,
	MATERIAL,
	KEY,
	LORE,
}

enum EquipSlot {
	NONE,
	MAIN_HAND,
	OFF_HAND,
	HEAD,
	CHEST,
	HANDS,
	LEGS,
	RING,
	EARRING,
	AMULET,
	BELT,
	FEET,
	SHOULDER,
	ARTIFACT,
	BROOCH,
	RUNE,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum CombatMode {
	NONE,
	MELEE,
	THROWABLE,
	BOW,
	CROSSBOW,
	MAGIC,
}

enum UseEffect {
	NONE,
	HEAL,
	RESTORE_MANA,
	GRANT_EXPERIENCE,
	APPLY_BUFF,
}

enum VisualArchetype {
	DEFAULT,
	WARRIOR,
	ARCHER,
	LANCER,
}

enum UseVisualEffect {
	NONE,
	HEAL,
	MANA,
	RAGE,
}

@export var id: StringName
@export var display_name: String = "New Item"
@export_multiline var description: String
@export var icon: Texture2D
@export var category: Category = Category.MATERIAL
@export var stackable: bool = false
@export_range(1, 999, 1) var max_stack_size: int = 1
@export_range(0.0, 1000.0, 0.01) var weight: float = 0.0
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 1000000, 1) var sell_price: int = 0
@export var is_key_item: bool = false
@export var usable_in_combat: bool = false

@export_group("Profiles")
@export var equipment_profile: ItemEquipmentProfile
@export var weapon_profile: ItemWeaponProfile
@export var consumable_profile: ItemConsumableProfile

# Kept as serialized fallback data while old resources and saves are migrated.
@export_storage var equip_slot: EquipSlot = EquipSlot.NONE
@export_storage var combat_mode: CombatMode = CombatMode.NONE
@export_storage var use_effect: UseEffect = UseEffect.NONE
@export_storage var use_value: float = 0.0
@export_storage var use_visual_effect: UseVisualEffect = UseVisualEffect.NONE
@export_storage var status_effect: StatusEffect
@export_storage var visual_archetype: VisualArchetype = VisualArchetype.DEFAULT
@export_storage var stats: ItemStats


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and max_stack_size > 0
		and (stackable or max_stack_size == 1)
	)


func get_effective_stack_size() -> int:
	return max_stack_size if stackable else 1


func can_equip_in(slot: EquipSlot) -> bool:
	if equipment_profile != null:
		return equipment_profile.can_equip_in(slot)
	return equip_slot != EquipSlot.NONE and equip_slot == slot


func get_primary_equip_slot() -> EquipSlot:
	if equipment_profile != null:
		return equipment_profile.get_primary_slot()
	return equip_slot


func get_equipment_stats() -> ItemStats:
	return equipment_profile.stats if equipment_profile != null else stats


func get_combat_mode() -> CombatMode:
	return weapon_profile.combat_mode if weapon_profile != null else combat_mode


func get_visual_archetype() -> VisualArchetype:
	return (
		weapon_profile.visual_archetype
		if weapon_profile != null
		else visual_archetype
	)


func get_use_effect() -> UseEffect:
	return (
		consumable_profile.use_effect
		if consumable_profile != null
		else use_effect
	)


func get_use_value() -> float:
	return (
		consumable_profile.use_value
		if consumable_profile != null
		else use_value
	)


func get_use_visual_effect() -> UseVisualEffect:
	return (
		consumable_profile.use_visual_effect
		if consumable_profile != null
		else use_visual_effect
	)


func get_status_effect() -> StatusEffect:
	return (
		consumable_profile.status_effect
		if consumable_profile != null
		else status_effect
	)


func get_display_icon() -> Texture2D:
	return icon if icon != null else PLACEHOLDER_ICON
