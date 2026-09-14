@tool
extends McpTestSuite


class GroundBody:
	extends CharacterBodyComponent
	var grounded := true
	func is_on_floor() -> bool:
		return grounded
	func move_and_slide() -> void:
		pass


func suite_name() -> String:
	return "equipment_swap"


func _fixture() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var body := GroundBody.new()
	var physics_body := CharacterBody2D.new()
	physics_body.name = "CharacterBody2D"
	body.add_child(physics_body)
	var equipment := EquipmentComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var attributes := CharacterAttributesComponent.new()
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var stun := HitStunComponent.new()
	stun.config = HitStunConfig.new()
	var swap := EquipmentSwapComponent.new()
	var input := InputComponent.new()
	var commands := EquipmentInputComponent.new()
	var state := ActorStateComponent.new()
	var hitbox := HitboxComponent.new()
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var hurtbox := HurtboxComponent.new()
	for component: Component in [body, inventory, equipment, attributes, health, stun, swap, input, commands, state, hitbox, attack, hurtbox]:
		components.add_child(component)
	actor._collect_components()
	var sword := load("res://game/items/weapons/TrainingSword.tres") as ItemData
	inventory.add_item(sword)
	equipment.equip_inventory_item(sword.id, ItemData.EquipSlot.MAIN_HAND)
	return {"actor": actor, "body": body, "equipment": equipment, "attributes": attributes,
		"health": health, "stun": stun, "swap": swap, "input": input,
		"commands": commands, "state": state, "attack": attack, "hurtbox": hurtbox}


func test_swap_is_delayed_and_exposes_fsm_and_progress() -> void:
	var f := _fixture()
	assert_true(f.swap.request_cycle())
	f.state.refresh_state()
	assert_eq(f.state.get_state(), ActorState.Behavior.EQUIPMENT_SWAP)
	assert_eq(f.equipment.get_active_weapon_set(), 0)
	assert_eq(f.swap.get_remaining(), 2.0)
	f.swap._process(1.0)
	assert_eq(f.swap.get_progress(), 0.5)
	assert_eq(f.equipment.get_active_weapon_set(), 0)
	f.swap._process(1.0)
	assert_eq(f.equipment.get_active_weapon_set(), 1)
	assert_false(f.swap.is_swapping())
	f.state.refresh_state()
	assert_eq(f.state.get_state(), ActorState.Behavior.IDLE)


func test_speed_is_sampled_on_start_and_repeat_does_not_reset_timer() -> void:
	var f := _fixture()
	f.attributes.attack_speed_multiplier = 2.0
	assert_true(f.swap.request_cycle())
	assert_eq(f.swap.get_remaining(), 1.0)
	f.swap._process(0.5)
	f.attributes.attack_speed_multiplier = 1.0
	assert_false(f.swap.request_cycle())
	assert_eq(f.swap.get_remaining(), 0.5)
	f.swap._process(0.5)
	assert_eq(f.equipment.get_active_weapon_set(), 1)


func test_running_airborne_and_attack_prevent_start() -> void:
	var f := _fixture()
	f.body.grounded = false
	assert_false(f.swap.request_cycle())
	f.body.grounded = true
	f.body.set_velocity(Vector2(10, 0))
	assert_false(f.swap.request_cycle())
	f.body.set_velocity(Vector2.ZERO)
	f.input._move_axis = 1.0
	assert_false(f.swap.request_cycle())
	f.input._move_axis = 0.0
	assert_true(f.attack.attack())
	assert_false(f.swap.request_cycle())


func test_swap_blocks_attack_jump_dodge_and_movement() -> void:
	var f := _fixture()
	assert_true(f.swap.request_cycle())
	assert_false(f.attack.can_attack())
	var providers := LocomotionConstraint.collect_providers(f.actor)
	var blocks := LocomotionConstraint.get_active_blocks(providers)
	assert_true(LocomotionConstraint.has_block(blocks, LocomotionConstraint.Block.HORIZONTAL))
	assert_true(LocomotionConstraint.has_block(blocks, LocomotionConstraint.Block.JUMP))
	assert_true(LocomotionConstraint.has_block(blocks, LocomotionConstraint.Block.DODGE))
	f.swap.cancel_swap()
	assert_eq(f.swap.get_locomotion_blocks(), LocomotionConstraint.Block.NONE)
	assert_true(f.attack.can_attack())


func test_enemy_hit_cancels_swap_and_stun_prevents_restarting() -> void:
	var f := _fixture()
	var finished: Array[bool] = []
	f.swap.swap_finished.connect(func(_target: int, completed: bool) -> void: finished.append(completed))
	f.swap.request_cycle()
	f.swap._process(1.0)
	assert_true(f.hurtbox.receive_hit(HitData.new(1.0, null)) > 0.0)
	assert_false(f.swap.is_swapping())
	assert_eq(f.equipment.get_active_weapon_set(), 0)
	assert_eq(finished, [false])
	f.swap._process(5.0)
	assert_false(f.swap.request_cycle())
	f.stun._process(10.0)
	assert_true(f.swap.request_cycle())
	assert_eq(f.swap.get_remaining(), 2.0)


func test_loss_of_floor_death_and_disable_cancel_without_applying_set() -> void:
	var f := _fixture()
	f.swap.request_cycle()
	f.body.grounded = false
	f.swap._process(0.1)
	assert_false(f.swap.is_swapping())
	f.body.grounded = true
	f.swap.request_cycle()
	f.swap.disable()
	assert_false(f.swap.is_swapping())
	f.swap.enable()
	f.swap.request_cycle()
	f.health.take_damage(f.health.get_current_health())
	assert_false(f.swap.is_swapping())
	assert_false(f.swap.request_cycle())
	assert_eq(f.equipment.get_active_weapon_set(), 0)


func test_keyboard_routes_to_delayed_swap() -> void:
	var f := _fixture()
	f.input._weapon_set_swap_pressed = true
	f.commands._process(0.0)
	assert_true(f.swap.is_swapping())
	assert_eq(f.equipment.get_active_weapon_set(), 0)
	f.swap._process(2.0)
	assert_eq(f.equipment.get_active_weapon_set(), 1)


func test_world_bar_updates_and_disappears_on_cancel() -> void:
	var f := _fixture()
	var view := track((load("res://features/equipment/ui/EquipmentSwapView.tscn") as PackedScene).instantiate()) as EquipmentSwapView
	view.actor_path = NodePath()
	view.bind_swap(f.swap)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	assert_false(view.visible)
	f.swap.request_cycle()
	assert_true(view.visible)
	f.swap._process(1.0)
	view.refresh()
	assert_eq((view.get_node("ProgressBar") as ProgressBar).value, 0.5)
	assert_eq((view.get_node("Label") as Label).text, "Смена: 1.0 с")
	f.swap.cancel_swap()
	assert_false(view.visible)


func test_player_contains_swap_component_world_bar_and_placeholder_clip() -> void:
	var player := track((load("res://game/player/Player.tscn") as PackedScene).instantiate()) as Actor
	assert_true(player.get_node("_Components/EquipmentSwapComponent") is EquipmentSwapComponent)
	assert_true(player.get_node("EquipmentSwapView") is EquipmentSwapView)
	var animation := player.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	assert_true(animation.has_animation(&"equipment_swap"))
	assert_eq(animation.get_animation(&"equipment_swap").get_track_count(), 0)
