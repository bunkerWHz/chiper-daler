extends Component
class_name HitboxComponent

signal hit_landed(hurtbox: HurtboxComponent, applied_damage: float)
signal critical_hit_landed(hurtbox: HurtboxComponent, applied_damage: float)

@export_range(0.0, 100000.0, 1.0) var damage: float = 10.0
@export_range(0.0, 1000.0, 1.0) var horizontal_knockback: float = 180.0
@export_range(0.0, 1000.0, 1.0) var vertical_knockback: float = 100.0
@export_range(1.0, 10.0, 0.1) var critical_damage_multiplier: float = 2.0

var _area: Area2D
var _horizontal_direction: float = 1.0


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


func disable() -> void:
	deactivate()
	super.disable()


func set_horizontal_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return

	_horizontal_direction = signf(direction)
	var spatial_root := get_node(".") as Node2D

	if spatial_root == null:
		return

	var offset_x := absf(spatial_root.position.x)
	spatial_root.position.x = (
		offset_x if _horizontal_direction > 0.0 else -offset_x
	)


func get_horizontal_direction() -> float:
	return _horizontal_direction


func _on_area_entered(other_area: Area2D) -> void:
	if not is_enabled:
		return

	var hurtbox := other_area.get_parent() as HurtboxComponent

	if hurtbox == null or hurtbox.actor == actor or not _can_hit(hurtbox):
		return

	var direction := signf(hurtbox.actor.global_position.x - actor.global_position.x)

	if is_zero_approx(direction):
		direction = 1.0

	var knockback_velocity := Vector2(
		direction * horizontal_knockback,
		-vertical_knockback
	)
	var is_critical := _is_backstab(hurtbox.actor, direction)
	var hit_damage := damage * critical_damage_multiplier if is_critical else damage
	var hit := HitData.new(
		hit_damage,
		actor,
		knockback_velocity,
		is_critical
	)
	var applied_damage := hurtbox.receive_hit(hit)

	if applied_damage > 0.0:
		hit_landed.emit(hurtbox, applied_damage)
		if is_critical:
			critical_hit_landed.emit(hurtbox, applied_damage)


func _is_backstab(target: Actor, attack_direction: float) -> bool:
	if target == null or is_zero_approx(attack_direction):
		return false

	var target_direction := 0.0
	var facing := target.get_component(FacingComponent) as FacingComponent
	if facing != null and facing.is_enabled:
		target_direction = float(facing.get_direction())
	else:
		var enemy_movement := (
			target.get_component(EnemyMovementComponent)
			as EnemyMovementComponent
		)
		if enemy_movement != null and enemy_movement.is_enabled:
			target_direction = enemy_movement.get_move_direction()

	return (
		not is_zero_approx(target_direction)
		and signf(attack_direction) == signf(target_direction)
	)


func _can_hit(hurtbox: HurtboxComponent) -> bool:
	var source_faction := (
		actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)
	var target_faction := (
		hurtbox.actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)

	if source_faction == null or target_faction == null:
		return true

	return source_faction.is_hostile_to(target_faction.faction)
