@tool
extends McpTestSuite


func suite_name() -> String:
	return "equipment_stats"


func test_attribute_requirements_gate_equipping() -> void:
	var setup := _create_equipment_actor()
	var attributes := setup.attributes as CharacterAttributesComponent
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	attributes.set_dexterity(1)
	var crossbow := load(
		"res://features/inventory/items/LightCrossbow.tres"
	) as ItemData
	inventory.add_item(crossbow)

	assert_false(equipment.meets_item_requirements(crossbow))
	assert_eq(equipment.get_requirement_failure(crossbow), "DEX 3")
	assert_false(equipment.equip_inventory_item(
		crossbow.id, ItemData.EquipSlot.MAIN_HAND
	))

	attributes.set_dexterity(3)
	assert_true(equipment.meets_item_requirements(crossbow))
	assert_true(equipment.equip_inventory_item(
		crossbow.id, ItemData.EquipSlot.MAIN_HAND
	))
	attributes.set_dexterity(1)
	assert_true(equipment.get_equipped_item_id(
		ItemData.EquipSlot.MAIN_HAND
	).is_empty())
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.MELEE)


func test_all_five_attributes_persist_and_gate_requirements() -> void:
	var attributes := track(
		CharacterAttributesComponent.new()
	) as CharacterAttributesComponent
	attributes.set_strength(1)
	attributes.set_dexterity(2)
	attributes.set_intelligence(3)
	attributes.set_endurance(4)
	attributes.set_wisdom(5)
	var state := attributes.capture_runtime_state() as Dictionary
	assert_eq(state, {
		"strength": 1,
		"dexterity": 2,
		"intelligence": 3,
		"endurance": 4,
		"wisdom": 5,
	})

	var item := _create_stat_item(
		&"five_attribute_item", ItemData.EquipSlot.HEAD, 0.0, 0.0
	)
	item.stats.strength_requirement = 2
	item.stats.dexterity_requirement = 3
	item.stats.intelligence_requirement = 4
	item.stats.endurance_requirement = 5
	item.stats.wisdom_requirement = 6
	assert_false(attributes.meets_item_requirements(item))
	assert_eq(
		attributes.get_requirement_failure(item),
		"STR 2, DEX 3, INT 4, END 5, WIS 6"
	)

	attributes.restore_runtime_state({
		"strength": 6,
		"dexterity": 6,
		"intelligence": 6,
		"endurance": 6,
		"wisdom": 6,
	})
	assert_true(attributes.meets_item_requirements(item))
	assert_eq(attributes.intelligence, 6)
	assert_eq(attributes.endurance, 6)
	assert_eq(attributes.wisdom, 6)


func test_weapon_damage_applies_before_heavy_multiplier() -> void:
	var setup := _create_equipment_actor(true)
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var hitbox := setup.hitbox as HitboxComponent
	var attack := setup.attack as AttackComponent
	var sword := load(
		"res://features/inventory/items/RustySword.tres"
	) as ItemData
	inventory.add_item(sword)
	equipment.equip_inventory_item(sword.id, ItemData.EquipSlot.MAIN_HAND)
	hitbox._ready()
	attack._ready()

	assert_true(attack.attack())
	assert_eq(hitbox.damage, 20.0)
	attack._process(attack.config.cooldown)
	assert_true(attack.heavy_attack())
	assert_eq(hitbox.damage, 40.0)


func test_active_weapon_controls_critical_damage_multiplier() -> void:
	var setup := _create_equipment_actor(true)
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var hitbox := setup.hitbox as HitboxComponent
	var attack := setup.attack as AttackComponent
	var dagger := load(
		"res://features/inventory/items/TrainingDagger.tres"
	) as ItemData
	inventory.add_item(dagger)
	equipment.equip_inventory_item(dagger.id, ItemData.EquipSlot.MAIN_HAND)
	hitbox._ready()
	attack._ready()

	assert_true(attack.attack())
	assert_eq(hitbox.critical_damage_multiplier, 3.0)


func test_equipment_defense_reduces_incoming_damage() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = 200.0
	var hurtbox := HurtboxComponent.new()
	var input := InputComponent.new()
	var attributes := CharacterAttributesComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var defense := EquipmentDefenseComponent.new()
	for component: Component in [
		health,
		hurtbox,
		input,
		attributes,
		inventory,
		equipment,
		defense,
	]:
		components.add_child(component)
	actor._collect_components()

	var armor := _create_stat_item(
		&"test_armor", ItemData.EquipSlot.CHEST, 0.0, 100.0
	)
	inventory.add_item(armor)
	equipment.equip_inventory_item(armor.id, ItemData.EquipSlot.CHEST)

	assert_eq(equipment.get_total_defense(), 100.0)
	assert_eq(hurtbox.receive_hit(HitData.new(100.0, null)), 50.0)
	assert_eq(health.get_current_health(), 150.0)


func test_endurance_controls_load_from_all_equipped_weapon_sets() -> void:
	var setup := _create_equipment_actor()
	var attributes := setup.attributes as CharacterAttributesComponent
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var sword := _create_stat_item(
		&"load_sword", ItemData.EquipSlot.MAIN_HAND, 0.0, 0.0
	)
	sword.weight = 4.0
	var bow := _create_stat_item(
		&"load_bow", ItemData.EquipSlot.MAIN_HAND, 0.0, 0.0
	)
	bow.weight = 2.0
	var armor := _create_stat_item(
		&"load_armor", ItemData.EquipSlot.CHEST, 0.0, 0.0
	)
	armor.weight = 3.0
	for item: ItemData in [sword, bow, armor]:
		inventory.add_item(item)
	equipment.equip_inventory_item(
		sword.id, ItemData.EquipSlot.MAIN_HAND, 0, 0
	)
	equipment.equip_inventory_item(
		bow.id, ItemData.EquipSlot.MAIN_HAND, 0, 1
	)
	equipment.equip_inventory_item(armor.id, ItemData.EquipSlot.CHEST)

	assert_eq(equipment.get_total_equipped_weight(), 9.0)
	assert_eq(equipment.get_max_equip_load(), 25.0)
	assert_true(is_equal_approx(equipment.get_equip_load_ratio(), 0.36))
	attributes.set_endurance(10)
	assert_eq(equipment.get_max_equip_load(), 40.0)
	assert_true(is_equal_approx(equipment.get_equip_load_ratio(), 0.225))
	assert_eq(inventory.get_total_weight(), 9.0)


func test_ranged_and_magic_projectiles_add_active_weapon_damage() -> void:
	var world := track(Node2D.new()) as Node2D
	var actor := Actor.new()
	world.add_child(actor)
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var ranged := RangedWeaponComponent.new()
	ranged.config = RangedWeaponConfig.new()
	var magic := MagicComponent.new()
	magic.config = MagicConfig.new()
	for component: Component in [
		input,
		inventory,
		equipment,
		facing,
		ranged,
		magic,
	]:
		components.add_child(component)
	actor._collect_components()

	var bow := load(
		"res://features/inventory/items/ShortBow.tres"
	) as ItemData
	var focus := load(
		"res://features/inventory/items/ApprenticeFocus.tres"
	) as ItemData
	inventory.add_item(bow)
	inventory.add_item(focus)
	equipment.equip_inventory_item(bow.id, ItemData.EquipSlot.MAIN_HAND)
	ranged._spawn_projectile(100.0, ranged.config.arrow_damage)
	var arrow := world.get_child(world.get_child_count() - 1) as ThrownProjectile
	assert_eq(arrow._damage, 26.0)

	equipment.equip_inventory_item(focus.id, ItemData.EquipSlot.MAIN_HAND)
	magic._cast_spell()
	var spell := world.get_child(world.get_child_count() - 1) as ThrownProjectile
	assert_eq(spell._damage, 35.0)


func _create_equipment_actor(with_attack: bool = false) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var attributes := CharacterAttributesComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var hitbox: HitboxComponent
	var attack: AttackComponent
	for component: Component in [input, attributes, inventory, equipment]:
		components.add_child(component)
	if with_attack:
		hitbox = HitboxComponent.new()
		var area := Area2D.new()
		area.name = "Area2D"
		hitbox.add_child(area)
		attack = AttackComponent.new()
		attack.config = AttackConfig.new()
		components.add_child(hitbox)
		components.add_child(attack)
	actor._collect_components()
	return {
		"actor": actor,
		"attributes": attributes,
		"inventory": inventory,
		"equipment": equipment,
		"hitbox": hitbox,
		"attack": attack,
	}


func _create_stat_item(
	id: StringName,
	slot: ItemData.EquipSlot,
	damage: float,
	defense: float
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.equip_slot = slot
	item.stats = ItemStats.new()
	item.stats.damage = damage
	item.stats.defense = defense
	return item
