extends RefCounted
## Shared native-art sizing; percentages are relative to the actor's body height.

static var _bounds_cache: Dictionary = {}


static func visible_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	if not _bounds_cache.has(texture):
		var image := texture.get_image()
		var bounds := Rect2(Vector2.ZERO, texture.get_size())
		if image != null and not image.is_empty():
			bounds = Rect2(image.get_used_rect())
		_bounds_cache[texture] = bounds
	return _bounds_cache[texture]


static func body_height(actor: Actor) -> float:
	var body := actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	if body == null:
		return 0.0
	var collision := body.get_node_or_null("CharacterBody2D/CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 0.0
	return collision.shape.get_rect().size.y


static func shield_ratio(item: ItemData) -> float:
	if item.offhand_profile == null:
		return 0.0
	match item.offhand_profile.family:
		ItemOffhandProfile.Family.BUCKLER: return 0.3
		ItemOffhandProfile.Family.HEATER: return 0.6
		ItemOffhandProfile.Family.TOWER: return 0.9
	return 0.0


static func fit_scale(texture: Texture2D, maximum: float, height_only: bool = false) -> float:
	var size := visible_rect(texture).size
	var extent := size.y if height_only else maxf(size.x, size.y)
	if extent <= 0.0 or maximum <= 0.0:
		return 1.0
	return minf(1.0, maximum / extent)


static func throwable_scale(texture: Texture2D, native_body_height: float, actor_scale: float) -> float:
	return fit_scale(texture, native_body_height * absf(actor_scale) * 0.3)
