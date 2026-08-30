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
}

@export var id: StringName
@export var display_name: String = "New Item"
@export_multiline var description: String
@export var icon: Texture2D
@export var category: Category = Category.MATERIAL
@export var stackable: bool = false
@export_range(1, 999, 1) var max_stack_size: int = 1
@export_range(0.0, 1000.0, 0.01) var weight: float = 0.0
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var combat_mode: CombatMode = CombatMode.NONE
@export var use_effect: UseEffect = UseEffect.NONE
@export var use_value: float = 0.0
@export var stats: ItemStats
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 1000000, 1) var sell_price: int = 0
@export var is_key_item: bool = false
@export var usable_in_combat: bool = false


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
	return equip_slot != EquipSlot.NONE and equip_slot == slot


func get_display_icon() -> Texture2D:
	return icon if icon != null else PLACEHOLDER_ICON
