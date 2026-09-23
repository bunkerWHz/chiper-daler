extends Resource
class_name DodgeConfig

@export_range(1.0, 2000.0, 1.0) var speed: float = 420.0
## Air dodge. The ground dodge is the authored `dodge_roll` clip and uses
## roll_duration instead, so the roll can play at a readable speed without
## retiming the short airborne clip.
@export_range(0.01, 2.0, 0.01) var duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var roll_duration: float = 0.45
@export_range(0.0, 5.0, 0.01) var cooldown: float = 0.35
@export_range(0.0, 2.0, 0.01) var invulnerability_duration: float = 0.15
@export var allow_air_dodge: bool = true


func get_duration(is_air_dodge: bool) -> float:
	return duration if is_air_dodge else roll_duration
