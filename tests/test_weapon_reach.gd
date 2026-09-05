@tool
extends McpTestSuite


func suite_name() -> String:
	return "weapon_reach"


func _assert_near(actual: float, expected: float, tolerance: float) -> void:
	assert_true(absf(actual - expected) < tolerance, "%s != %s" % [actual, expected])


func test_reach_changes_horizontal_hit_area_and_restores_after_attack() -> void:
	var setup := _create_actor()
	var hitbox := setup.hitbox as HitboxComponent
	var spatial := setup.hitbox as Node2D
	var attack := setup.attack as AttackComponent
	var shape := spatial.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	var edge := shape.shape.get_rect().end
	var base_edge := shape.to_global(edge)
	assert_true(attack.attack())
	_assert_near(shape.to_global(edge).x, base_edge.x * 1.6, 0.001)
	_assert_near(shape.to_global(edge).y, base_edge.y, 0.001)
	hitbox.set_horizontal_direction(-1.0)
	_assert_near(shape.to_global(edge).x, -base_edge.x * 1.6, 0.001)
	attack._process(attack.config.active_duration)
	assert_false(attack.is_attacking())
	_assert_near(shape.to_global(edge).x, -base_edge.x, 0.001)
	attack._process(attack.config.cooldown)
	assert_true(attack.heavy_attack())
	_assert_near(shape.to_global(edge).x, -base_edge.x * 1.6, 0.001)
	attack.disable()
	_assert_near(shape.to_global(edge).x, -base_edge.x, 0.001)


func test_weapon_change_affects_next_attack_without_compounding_reach() -> void:
	var setup := _create_actor()
	var attack := setup.attack as AttackComponent
	var spatial := setup.hitbox as Node2D
	var equipment := setup.equipment as EquipmentComponent
	var weapon := setup.weapon as ItemData
	assert_true(attack.attack())
	_assert_near(spatial.position.x, 24.0 * 1.6, 0.001)
	weapon.weapon_profile.reach_multiplier = 0.7
	_assert_near(spatial.position.x, 24.0 * 1.6, 0.001)
	attack._process(attack.config.cooldown)
	assert_true(attack.attack())
	_assert_near(spatial.position.x, 24.0 * 0.7, 0.001)
	attack.disable()
	_assert_near(spatial.position.x, 24.0, 0.001)
	weapon.weapon_profile = null
	assert_eq(equipment.get_active_weapon_reach_multiplier(), 1.0)


func _create_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var hitbox := preload("res://features/combat/HitboxComponent.tscn").instantiate()
	hitbox.position = Vector2(24.0, -8.0)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	for component: Node in [input, inventory, equipment, hitbox, attack]:
		components.add_child(component)
	actor._collect_components()
	var weapon := ItemData.new()
	weapon.id = &"reach_test"
	weapon.equipment_profile = ItemEquipmentProfile.new()
	weapon.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	weapon.weapon_profile = ItemWeaponProfile.new()
	weapon.weapon_profile.combat_mode = ItemData.CombatMode.MELEE
	weapon.weapon_profile.available_actions = (
		ItemWeaponProfile.Action.LIGHT_ATTACK | ItemWeaponProfile.Action.HEAVY_ATTACK
	)
	weapon.weapon_profile.reach_multiplier = 1.6
	inventory.add_item(weapon)
	equipment.equip_inventory_item(weapon.id, ItemData.EquipSlot.MAIN_HAND)
	(Engine.get_main_loop() as SceneTree).root.add_child(actor)
	return {"attack": attack, "hitbox": hitbox, "equipment": equipment, "weapon": weapon}
