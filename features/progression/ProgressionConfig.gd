extends Resource
class_name ProgressionConfig

@export_range(1, 100000, 1) var initial_experience_required: int = 100
@export_range(1.0, 10.0, 0.05) var requirement_growth: float = 1.25
@export_range(0.05, 5.0, 0.05) var level_up_state_duration: float = 0.8
