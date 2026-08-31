extends Resource
class_name CharacterDerivedStatsConfig

@export_range(0, 999, 1) var reference_endurance: int = 5
@export_range(0.0, 10000.0, 0.5) var health_per_endurance: float = 10.0
@export_range(1.0, 10000.0, 0.5) var base_max_equip_load: float = 25.0
@export_range(0.0, 1000.0, 0.5) var equip_load_per_endurance: float = 3.0
