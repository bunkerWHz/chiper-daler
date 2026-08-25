extends Component
class_name CombatFactionComponent

enum Faction {
	NEUTRAL,
	PLAYER,
	ENEMY,
}

@export_enum("Neutral", "Player", "Enemy") var faction: int = Faction.NEUTRAL


func is_hostile_to(other_faction: int) -> bool:
	return faction != other_faction
