@tool
extends McpTestSuite

const SIZING := preload("res://features/inventory/ItemVisualSizing.gd")


func suite_name() -> String:
	return "item_visual_sizing"


func test_padding_and_uniform_limits() -> void:
	var image := Image.create(1200, 1200, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(100, 200, 900, 600), Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	assert_eq(SIZING.visible_rect(texture), Rect2(100, 200, 900, 600))
	assert_true(is_equal_approx(SIZING.fit_scale(texture, 300), 1.0 / 3.0))
	assert_true(is_equal_approx(SIZING.fit_scale(texture, 300, true), 0.5))
	assert_eq(SIZING.fit_scale(texture, 1500), 1.0)
	var item := ItemData.new()
	item.offhand_profile = ItemOffhandProfile.new()
	for family in [1, 2, 3]:
		item.offhand_profile.family = family
		assert_true(is_equal_approx(SIZING.shield_ratio(item), family * 0.3))


func test_shield_grip_and_all_three_sizes() -> void:
	var player := track(load("res://game/player/Player.tscn").instantiate()) as Actor
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
	var hand := visual._off_hand
	var grip := hand.get_node("ShieldGrip") as Marker2D
	assert_true(is_equal_approx(grip.rotation, -0.7690259))
	var image := Image.create(500, 1200, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for family in [1, 2, 3]:
		var item := ItemData.new()
		item.offhand_profile = ItemOffhandProfile.new()
		item.offhand_profile.family = family
		item.equipped_texture = ImageTexture.create_from_image(image)
		visual._update_hand(hand, item)
		assert_eq(grip.get_child_count(), 1)
		var holder := grip.get_child(0) as Node2D
		assert_true(is_equal_approx(holder.scale.y * 1200.0, 970.0 * family * 0.3))
		assert_eq(holder.scale.x, holder.scale.y)
		assert_eq((holder.get_child(0) as Sprite2D).scale, Vector2.ONE)
	visual._update_hand(hand, null)
	assert_eq(grip.get_child_count(), 0)


func test_throwable_scales_with_actor_and_preserves_hit_radius() -> void:
	var player := track(load("res://game/player/Player.tscn").instantiate()) as Actor
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	var image := Image.create(1000, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for hero_scale in [0.1, 0.2]:
		player.scale = Vector2.ONE * hero_scale
		var projectile := track(load("res://features/throwing/ThrownProjectile.tscn").instantiate()) as ThrownProjectile
		projectile.fit_throwable(player, texture)
		var expected: float = 970.0 * hero_scale * 0.3
		assert_true(is_equal_approx(projectile.scale.x * 1000.0, expected))
		assert_eq(projectile.scale.x, projectile.scale.y)
		var collision := projectile.get_node("CollisionShape2D") as CollisionShape2D
		assert_true(is_equal_approx((collision.shape as CircleShape2D).radius * projectile.scale.x, 5.0))
		assert_eq(collision.scale, Vector2.ONE)
		assert_eq((projectile.get_node("ProjectileSprite") as Sprite2D).scale, Vector2.ONE)
