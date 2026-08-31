extends Resource
class_name ItemConsumableProfile

@export var use_effect: ItemData.UseEffect = ItemData.UseEffect.NONE
@export var use_value: float = 0.0
@export var use_visual_effect: ItemData.UseVisualEffect = (
	ItemData.UseVisualEffect.NONE
)
@export var status_effect: StatusEffect
