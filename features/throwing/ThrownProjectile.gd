extends Area2D
class_name ThrownProjectile

const COMBAT_TARGETING := preload("res://features/combat/CombatTargeting.gd")

var _source_actor: Actor
var _velocity: Vector2
var _damage: float = 0.0
var _knockback: float = 0.0
var _lifetime: float = 0.0
var _has_hit: bool = false
var _default_visual: CanvasItem
var _projectile_sprite: Sprite2D


func _ready() -> void:
	_default_visual = get_node_or_null("Visual") as CanvasItem
	_projectile_sprite = get_node_or_null("ProjectileSprite") as Sprite2D
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(
	source_actor: Actor,
	direction: float,
	speed: float,
	damage: float,
	knockback: float,
	lifetime: float,
	visual_texture: Texture2D = null
) -> void:
	_source_actor = source_actor
	_velocity = Vector2(signf(direction) * speed, 0.0)
	_damage = damage
	_knockback = knockback
	_lifetime = lifetime
	_apply_visual(visual_texture, direction)


func _apply_visual(texture: Texture2D, direction: float) -> void:
	if _projectile_sprite == null:
		return

	var has_custom_visual := texture != null
	_projectile_sprite.texture = texture
	_projectile_sprite.visible = has_custom_visual
	_projectile_sprite.flip_h = has_custom_visual and direction < 0.0

	if _default_visual != null:
		_default_visual.visible = not has_custom_visual


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	_lifetime = maxf(_lifetime - delta, 0.0)

	if _lifetime == 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	var hurtbox := area.get_parent() as HurtboxComponent

	if (
		_source_actor == null
		or not COMBAT_TARGETING.is_valid_hostile(_source_actor, hurtbox)
	):
		return

	# Consume the projectile before applying damage. More than one Area2D can
	# report an overlap during the same physics frame, but only the first valid
	# hostile target is allowed to receive this projectile.
	_has_hit = true
	var direction := signf(_velocity.x)
	hurtbox.receive_hit(HitData.new(
		_damage,
		_source_actor,
		Vector2(direction * _knockback, -_knockback * 0.35)
	))
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	if _has_hit:
		return
	_has_hit = true
	queue_free()
