extends Component
class_name DamageModifierComponent


func modify_damage(_hit: HitData, damage: float) -> float:
	return damage


func allows_hit_reactions(_hit: HitData) -> bool:
	return true
