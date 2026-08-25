extends Component
class_name HitboxComponent

signal hit_landed(hurtbox: HurtboxComponent, applied_damage: float)

@export_range(0.0, 100000.0, 1.0) var damage: float = 10.0

var _area: Area2D


func _ready() -> void:
	_area = get_node_or_null("Area2D") as Area2D

	if _area == null:
		push_error("HitboxComponent requires Area2D")
		disable()
		return

	if not _area.area_entered.is_connected(_on_area_entered):
		_area.area_entered.connect(_on_area_entered)


func activate() -> void:
	if _area != null:
		_area.monitoring = true


func deactivate() -> void:
	if _area != null:
		_area.monitoring = false


func _on_area_entered(other_area: Area2D) -> void:
	if not is_enabled:
		return

	var hurtbox := other_area.get_parent() as HurtboxComponent

	if hurtbox == null or hurtbox.actor == actor:
		return

	var hit := HitData.new(damage, actor)
	var applied_damage := hurtbox.receive_hit(hit)

	if applied_damage > 0.0:
		hit_landed.emit(hurtbox, applied_damage)
