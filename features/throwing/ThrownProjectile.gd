extends Area2D
class_name ThrownProjectile

var _source_actor: Actor
var _velocity: Vector2
var _damage: float = 0.0
var _knockback: float = 0.0
var _lifetime: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(
	source_actor: Actor,
	direction: float,
	speed: float,
	damage: float,
	knockback: float,
	lifetime: float
) -> void:
	_source_actor = source_actor
	_velocity = Vector2(signf(direction) * speed, 0.0)
	_damage = damage
	_knockback = knockback
	_lifetime = lifetime


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	_lifetime = maxf(_lifetime - delta, 0.0)

	if _lifetime == 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area.get_parent() as HurtboxComponent

	if (
		hurtbox == null
		or hurtbox.actor == _source_actor
		or _source_actor == null
	):
		return

	var direction := signf(_velocity.x)
	hurtbox.receive_hit(HitData.new(
		_damage,
		_source_actor,
		Vector2(direction * _knockback, -_knockback * 0.35)
	))
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()
