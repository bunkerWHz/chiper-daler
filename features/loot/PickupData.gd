extends Resource
class_name PickupData

enum Kind {
	HEALTH,
	ITEM_CHARGE,
	THROWABLE,
	ARROW,
	BOLT,
	MANA,
	EXPERIENCE,
}

@export var display_name: String = "Health Essence"
@export var kind: Kind = Kind.HEALTH
@export_range(0.01, 100000.0, 0.01) var amount: float = 25.0


func is_valid() -> bool:
	return not display_name.is_empty() and amount > 0.0
