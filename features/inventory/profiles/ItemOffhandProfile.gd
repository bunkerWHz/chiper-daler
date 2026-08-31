extends Resource
class_name ItemOffhandProfile

enum Family {
	NONE,
	BUCKLER,
	MEDIUM_SHIELD,
	GREATSHIELD,
	CATALYST,
	PARRYING_DAGGER,
	TORCH,
	HAND_CROSSBOW,
}

enum Action {
	GUARD = 1 << 0,
	PARRY = 1 << 1,
	CAST = 1 << 2,
	AIM = 1 << 3,
	FIRE = 1 << 4,
}

@export var family: Family = Family.NONE
@export_flags("Guard", "Parry", "Cast", "Aim", "Fire") var available_actions: int = 0
@export_range(0.0, 1.0, 0.01) var block_damage_reduction: float = 0.0
@export_range(0.0, 10.0, 0.05) var guard_stability: float = 0.0
@export_range(0.1, 3.0, 0.05) var parry_window_multiplier: float = 1.0


func has_action(action: Action) -> bool:
	return (available_actions & action) != 0
