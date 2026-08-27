extends Resource
class_name ItemUseConfig

@export_range(0.01, 5.0, 0.01) var use_duration: float = 0.4
@export_range(0.0, 10.0, 0.01) var cooldown: float = 0.8
@export_range(1.0, 100000.0, 1.0) var heal_amount: float = 35.0
@export_range(0, 99, 1) var max_charges: int = 3
