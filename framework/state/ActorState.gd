extends RefCounted
class_name ActorState

enum Behavior {
	IDLE,
	RUN,
	JUMP,
	DOUBLE_JUMP,
	WALL_JUMP,
	FALL,
	DODGE,
	CLIMB_IDLE,
	CLIMB_UP,
	CLIMB_DOWN,
	GROUND_ATTACK_WINDUP,
	GROUND_LIGHT_ATTACK,
	GROUND_HEAVY_ATTACK,
	AIR_ATTACK_WINDUP,
	AIR_LIGHT_ATTACK,
	AIR_HEAVY_ATTACK,
	GROUND_ATTACK_RECOVERY,
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
	HIT,
	STUNNED,
	KNOCKED_DOWN,
	DEAD,
	RESPAWNING,
	LEVEL_UP,
	RESTING,
}

enum Status {
	NONE = 0,
	DEBUFFED = 1 << 0,
	BUFFED = 1 << 1,
}


static func get_behavior_name(state: Behavior) -> String:
	return _format_enum_name(Behavior.keys()[state])


static func get_status_names(mask: int) -> PackedStringArray:
	var names := PackedStringArray()
	for status_name: String in Status.keys():
		var status_value: int = Status[status_name]
		if status_value != Status.NONE and mask & status_value:
			names.append(_format_enum_name(status_name))
	return names


static func has_status(mask: int, status: Status) -> bool:
	return status != Status.NONE and bool(mask & status)


static func _format_enum_name(value: String) -> String:
	return value.to_pascal_case().replace("_", " ")
