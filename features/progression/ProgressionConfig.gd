extends Resource
class_name ProgressionConfig

## Hard ceiling for max_level; the level table in docs/Level_Progression.md
## covers exactly this many levels.
const ABSOLUTE_MAX_LEVEL := 100

@export_range(1, 100000, 1) var initial_experience_required: int = 100
@export_range(1.0, 10.0, 0.001) var requirement_growth: float = 1.05
@export_range(2, ABSOLUTE_MAX_LEVEL, 1) var max_level: int = ABSOLUTE_MAX_LEVEL
@export_range(0.05, 5.0, 0.05) var level_up_state_duration: float = 0.8
