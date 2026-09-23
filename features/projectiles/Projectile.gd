extends Area2D
class_name Projectile

## Shared projectile fired by bows, crossbows, thrown items and spells.
##
## The scene owns what the projectile looks like, how big it is and what happens
## on impact: artwork, collision shape, root scale, `sticks` and `pierce`. The
## ability that fires it passes only flight and damage numbers through
## `setup_direction()`, and never picks the weapon or spends ammunition.
##
## One scene per ammunition type is the point: arrows, bolts and thrown items
## differ by art, hit shape and impact behaviour, and both are authored by eye in
## the editor. An effect that has no scene of its own (spells, prototype
## throwables) uses `create_generic()` instead.

const COMBAT_TARGETING := preload("res://features/combat/CombatTargeting.gd")
const VISUAL_SIZING := preload("res://features/inventory/ItemVisualSizing.gd")

const GENERIC_RADIUS := 5.0

@export_group("Impact")
## Stick into world geometry instead of vanishing on contact.
@export var sticks: bool = false
## Seconds a stuck projectile stays in the world. Zero keeps it until the level ends.
@export_range(0.0, 60.0, 0.1) var stick_lifetime: float = 6.0
## Hostile targets the projectile passes through after the one it stops on. Zero
## stops at the first target it damages.
@export_range(0, 20, 1) var pierce: int = 0

var _source_actor: Actor
var _velocity: Vector2
var _damage: float = 0.0
var is_magic: bool = false
var _knockback: float = 0.0
var _lifetime: float = 0.0
var _has_hit: bool = false
var _default_visual: CanvasItem
var _projectile_sprite: Sprite2D
var _gravity: float = 0.0
var _orient_to_velocity: bool = false
var _rotation_speed: float = 0.0
var _status_effects: Array[StatusEffect] = []
var _pierce_left: int = 0
var _hit_targets: Array[HurtboxComponent] = []


## Builds the generic projectile in code, for effects that ship no scene: a plain
## shape with a round hit area that artwork can replace at runtime.
static func create_generic() -> Projectile:
	var projectile := Projectile.new()
	projectile.name = "GenericProjectile"
	projectile.collision_layer = 0
	projectile.collision_mask = 5

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-6.0, -3.0), Vector2(6.0, -3.0), Vector2(6.0, 3.0), Vector2(-6.0, 3.0),
	])
	visual.color = Color(0.85, 0.75, 0.35, 1.0)
	projectile.add_child(visual)

	var sprite := Sprite2D.new()
	sprite.name = "ProjectileSprite"
	sprite.visible = false
	projectile.add_child(sprite)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = GENERIC_RADIUS
	collision.shape = circle
	projectile.add_child(collision)
	return projectile


## Fits artwork that arrives at runtime, as thrown items do. Scene-authored
## artwork already carries its own size, so those scenes never call this.
## Called before entering the tree.
func fit_throwable(source_actor: Actor, texture: Texture2D, visual_scale: float = 1.0) -> void:
	var factor := VISUAL_SIZING.throwable_scale(texture, VISUAL_SIZING.body_height(source_actor), source_actor.global_scale.y, visual_scale)
	scale = Vector2.ONE * factor
	var collision := get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape.duplicate() as CircleShape2D
	circle.radius /= factor
	collision.shape = circle
	if texture != null:
		var sprite := get_node("ProjectileSprite") as Sprite2D
		sprite.centered = false
		sprite.offset = -VISUAL_SIZING.visible_rect(texture).get_center()


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


## Artwork is overridden only when a texture is passed. A scene that authors its
## own sprite keeps it, and the placeholder shape shows only without any art.
func _apply_visual(texture: Texture2D, direction: float) -> void:
	if _projectile_sprite == null:
		return

	if texture != null:
		_projectile_sprite.texture = texture
	var has_art := _projectile_sprite.texture != null
	_projectile_sprite.visible = has_art
	_projectile_sprite.flip_h = has_art and direction < 0.0

	if _default_visual != null:
		_default_visual.visible = not has_art


func _physics_process(delta: float) -> void:
	position += _velocity * delta + Vector2.DOWN * _gravity * delta * delta * 0.5
	_velocity.y += _gravity * delta
	if _rotation_speed != 0.0:
		rotation += _rotation_speed * delta
	elif _orient_to_velocity and not _velocity.is_zero_approx():
		rotation = _velocity.angle()
	_lifetime = maxf(_lifetime - delta, 0.0)

	if _lifetime == 0.0:
		queue_free()


func setup_direction(
	source_actor: Actor, direction: Vector2, speed: float, damage: float,
	knockback: float, lifetime: float, visual_texture: Texture2D = null,
	projectile_gravity: float = 0.0, projectile_rotation_speed: float = 0.0,
	projectile_status_effects: Array[StatusEffect] = []
) -> void:
	setup(source_actor, 1.0, speed, damage, knockback, lifetime, visual_texture)
	_velocity = direction.normalized() * speed
	_gravity = projectile_gravity
	_rotation_speed = deg_to_rad(projectile_rotation_speed)
	_status_effects = projectile_status_effects.duplicate()
	_orient_to_velocity = true
	_pierce_left = maxi(pierce, 0)
	rotation = direction.angle()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	var hurtbox := area.get_parent() as HurtboxComponent

	if (
		_source_actor == null
		or not COMBAT_TARGETING.is_valid_hostile(_source_actor, hurtbox)
	):
		return

	# More than one Area2D can report an overlap during the same physics frame, so
	# every target is remembered: each hostile takes damage once, and piercing
	# only spends on a target it actually damaged.
	if hurtbox in _hit_targets:
		return
	_hit_targets.append(hurtbox)

	var direction := signf(_velocity.x)
	var hit := HitData.new(
		_damage,
		_source_actor,
		Vector2(direction * _knockback, -_knockback * 0.35)
	)
	hit.status_effects = _status_effects
	hit.is_magic = is_magic
	hurtbox.receive_hit(hit)

	if _pierce_left > 0:
		_pierce_left -= 1
		return
	_has_hit = true
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	if _has_hit:
		return
	_has_hit = true
	if sticks:
		_stick()
		return
	queue_free()


## Freezes the projectile where it landed. It keeps rendering and stops watching
## for hits, so it can be picked up later or simply fade out of the world.
func _stick() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	if stick_lifetime > 0.0:
		var timer := get_tree().create_timer(stick_lifetime)
		timer.timeout.connect(queue_free)
