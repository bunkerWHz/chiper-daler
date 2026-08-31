extends Resource
class_name StaminaConfig

@export_range(1.0, 10000.0, 1.0) var max_stamina: float = 100.0
@export_range(0.0, 1000.0, 1.0) var regeneration_per_second: float = 25.0
@export_range(0.0, 10.0, 0.05) var regeneration_delay: float = 0.75
