extends Resource
class_name ItemWeaponProfile

enum Family {
	NONE,
	SWORD,
	RAPIER,
	KATANA,
	DAGGER,
	AXE,
	MACE,
	GREAT_SWORD,
	GREAT_HAMMER,
	SPEAR,
	POLEARM,
	SCYTHE,
	WAND,
	STAFF,
	BOW,
	CROSSBOW,
}

enum Handedness {
	ONE_HANDED,
	TWO_HANDED,
}

enum DamageType {
	NONE,
	SLASH,
	PIERCE,
	STRIKE,
	MAGIC,
}

enum Action {
	LIGHT_ATTACK = 1 << 0,
	HEAVY_ATTACK = 1 << 1,
	GUARD = 1 << 2,
	PARRY = 1 << 3,
	AIM = 1 << 4,
	FIRE = 1 << 5,
	RELOAD = 1 << 6,
	CAST = 1 << 7,
	CHANNEL = 1 << 8,
}

@export var combat_mode: ItemData.CombatMode = ItemData.CombatMode.NONE
@export var visual_archetype: ItemData.VisualArchetype = (
	ItemData.VisualArchetype.DEFAULT
)
@export var family: Family = Family.NONE
@export var handedness: Handedness = Handedness.ONE_HANDED
@export var primary_damage_type: DamageType = DamageType.NONE
@export var moveset_id: StringName
@export_flags(
	"Light Attack",
	"Heavy Attack",
	"Guard",
	"Parry",
	"Aim",
	"Fire",
	"Reload",
	"Cast",
	"Channel"
) var available_actions: int = 0
@export_range(0.1, 3.0, 0.05) var attack_speed_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.05) var reach_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var stagger_power: float = 1.0
@export_range(0.0, 2.0, 0.05) var strength_scaling: float = 0.0
@export_range(0.0, 2.0, 0.05) var dexterity_scaling: float = 0.0
@export_range(0.0, 2.0, 0.05) var magic_scaling: float = 0.0
@export var ammunition_type: StringName


func is_two_handed() -> bool:
	return handedness == Handedness.TWO_HANDED


func has_action(action: Action) -> bool:
	return (available_actions & action) != 0
