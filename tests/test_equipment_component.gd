@tool
extends McpTestSuite


func suite_name() -> String:
	return "equipment"


func test_number_slot_request_changes_equipment() -> void:
	var setup := _create_equipped_actor()
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent

	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.MELEE)
	input._equipment_slot_request = EquipmentComponent.Slot.BOW
	equipment._process(0.0)

	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.BOW)
	assert_eq(equipment.get_current_slot_name(), "Bow")
	assert_false(equipment.allows_melee_actions())


func test_switching_from_melee_cancels_attack_and_guard() -> void:
	var setup := _create_equipped_actor()
	var equipment := setup.equipment as EquipmentComponent
	var attack := setup.attack as AttackComponent
	var guard := setup.guard as GuardComponent
	var hitbox := setup.hitbox as HitboxComponent

	assert_true(attack.attack())
	assert_true(attack.is_attacking())
	equipment.equip(EquipmentComponent.Slot.BOW)

	assert_false(attack.is_attacking())
	assert_false(attack.can_attack())
	assert_false(hitbox._area.monitoring)
	assert_false(guard.start_guard())
	assert_false(guard.start_parry())


func _create_equipped_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [
		input,
		equipment,
		facing,
		hitbox,
		attack,
		guard,
	]:
		components.add_child(component)

	actor._collect_components()
	hitbox._ready()
	attack._ready()

	return {
		"actor": actor,
		"input": input,
		"equipment": equipment,
		"facing": facing,
		"hitbox": hitbox,
		"attack": attack,
		"guard": guard,
	}
