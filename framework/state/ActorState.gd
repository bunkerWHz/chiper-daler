extends RefCounted
class_name ActorState

enum Locomotion {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	WALL_JUMPING,
	FALLING,
	DODGING,
	CLIMBING_IDLE,
	CLIMBING_UP,
	CLIMBING_DOWN,
}

enum Action {
	NONE,
	LIGHT_ATTACK,
	HEAVY_ATTACK,
	USING_ITEM,
	THROWING_AIM,
	THROWING_ACTION,
	THROWING_RECOVERY,
	AIM_BOW,
	LOOSE_ARROW,
	AIM_CROSSBOW,
	FIRE_CROSSBOW,
	MAGIC_CHARGE,
	MAGIC_CAST,
	MAGIC_RECOVERY,
	MAGIC_CHANNELING,
	BLOCKING,
	PARRYING,
	CRITICAL_ATTACK,
	INTERACTING_START,
	INTERACTING_PROGRESS,
	INTERACTING_END,
}

enum Condition {
	NONE = 0,
	HIT = 1 << 0,
	STUNNED = 1 << 1,
	KNOCKED_DOWN = 1 << 2,
	DEAD = 1 << 3,
	RESPAWNING = 1 << 4,
	LEVEL_UP = 1 << 5,
	RESTING = 1 << 6,
	DEBUFFED = 1 << 7,
	BUFFED = 1 << 8,
}


static func get_locomotion_name(state: Locomotion) -> String:
	return _format_enum_name(Locomotion.keys()[state])


static func get_action_name(state: Action) -> String:
	return _format_enum_name(Action.keys()[state])


static func get_condition_names(mask: int) -> PackedStringArray:
	var names := PackedStringArray()

	for condition_name: String in Condition.keys():
		var condition_value: int = Condition[condition_name]

		if condition_value != Condition.NONE and mask & condition_value:
			names.append(_format_enum_name(condition_name))

	return names


static func has_condition(mask: int, condition: Condition) -> bool:
	return condition != Condition.NONE and bool(mask & condition)


static func _format_enum_name(value: String) -> String:
	return value.to_pascal_case().replace("_", " ")
