@tool
extends McpTestSuite


func suite_name() -> String:
	return "darklight_visual"


func test_active_equipment_updates_both_skeletal_hand_attachments() -> void:
	var setup := _create_player_visual()
	var equipment := setup.equipment as EquipmentComponent
	var main := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/MainHand") as Polygon2D
	var off := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/OffHand") as Polygon2D
	assert_eq(main.get_child(0).scene_file_path, equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_visual.resource_path)
	assert_true(main.visible)
	assert_true(off.visible)
	assert_eq(off.get_child(0).name, &"Buckler")
	assert_true(equipment.switch_weapon_set(1))
	assert_eq(main.get_child(0).scene_file_path, equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_visual.resource_path)
	var off_item := equipment.get_equipped_item(ItemData.EquipSlot.OFF_HAND)
	assert_eq(off.visible, off_item != null and (off_item.equipped_visual != null or off_item.icon != null))
	assert_true(equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND))
	assert_false(main.visible)
	assert_eq(main.texture, null)


func test_fsm_selects_attack_variants_and_facing_preserves_physics() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as DarklightVisualComponent
	var player := setup.player as Actor
	var state := player.get_component(ActorStateComponent) as ActorStateComponent
	var expected := {
		ActorState.Behavior.RUN: &"run",
		ActorState.Behavior.JUMP: &"jump",
		ActorState.Behavior.WALL_JUMP: &"wall_jump",
		ActorState.Behavior.FALL: &"fall",
		ActorState.Behavior.DODGE: &"dodge",
		ActorState.Behavior.GROUND_LIGHT_ATTACK: &"attack",
		ActorState.Behavior.GROUND_HEAVY_ATTACK: &"heavy_attack",
		ActorState.Behavior.AIR_LIGHT_ATTACK: &"air_attack",
		ActorState.Behavior.AIR_HEAVY_ATTACK: &"air_heavy_attack",
		ActorState.Behavior.BLOCKING: &"block",
	}
	for behavior: int in expected:
		state.state_changed.emit(ActorState.Behavior.IDLE, behavior)
		assert_eq(visual.get_animation_player().current_animation, expected[behavior])
		assert_eq(visual.get_state(), behavior)
	var body := (player.get_component(CharacterBodyComponent) as CharacterBodyComponent).get_body()
	var before := body.transform
	var facing := player.get_component(FacingComponent) as FacingComponent
	facing._set_direction(FacingComponent.Direction.LEFT)
	var rig := player.get_node("_Visual/DarklightRig") as Node2D
	assert_true(rig.transform.determinant() < 0.0)
	assert_eq(body.transform, before)
	assert_eq(player.scale, Vector2(0.04, 0.04))
	facing._set_direction(FacingComponent.Direction.RIGHT)
	assert_true(rig.transform.determinant() > 0.0)


func test_native_collision_shapes_preserve_previous_world_geometry() -> void:
	var setup := _create_player_visual()
	var player := setup.player as Actor
	for path: String in ["CharacterBodyComponent/CharacterBody2D", "HurtboxComponent/Area2D", "HitboxComponent/Area2D"]:
		var collision := player.get_node("_Components/" + path + "/CollisionShape2D") as CollisionShape2D
		assert_eq(collision.scale, Vector2.ONE)
		assert_eq((collision.shape as RectangleShape2D).size * player.scale, Vector2(20, 20))
	var hitbox := player.get_node("_Components/HitboxComponent") as Node2D
	assert_eq(hitbox.position * player.scale, Vector2(20, 0))


func test_item_and_buff_effects_render_on_separate_overlays() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as DarklightVisualComponent
	var item_use := setup.item_use as ItemUseComponent
	var status_effects := setup.status_effects as StatusEffectComponent
	var inventory := setup.inventory as InventoryComponent
	var heal := inventory.get_item_data(&"health_potion")
	var mana := inventory.get_item_data(&"mana_potion")
	var rage := inventory.get_item_data(&"rage_potion")

	item_use.item_use_started.emit(heal)
	assert_true(visual.get_item_effect_sprite().visible)
	assert_true(_effect_atlas_path(visual).ends_with("Heal_Effect.png"))
	item_use.item_use_cancelled.emit()
	assert_false(visual.get_item_effect_sprite().visible)

	item_use.item_use_started.emit(mana)
	assert_true(_effect_atlas_path(visual).ends_with("Mana_Effect.png"))
	item_use.item_use_started.emit(rage)
	assert_true(_effect_atlas_path(visual).ends_with("Rage_effect.png"))
	assert_true(status_effects.apply_effect(rage.get_status_effect()))
	assert_true(visual.get_buff_effect_sprite().visible)


func _create_player_visual() -> Dictionary:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Actor
	player._collect_components()
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var visual := (
		player.get_component(DarklightVisualComponent)
		as DarklightVisualComponent
	)
	equipment._ready()
	visual._ready()
	return {
		"player": player,
		"visual": visual,
		"equipment": equipment,
		"inventory": player.get_component(InventoryComponent),
		"item_use": player.get_component(ItemUseComponent),
		"status_effects": player.get_component(StatusEffectComponent),
	}


func _effect_atlas_path(visual: DarklightVisualComponent) -> String:
	var texture := visual.get_item_effect_sprite().sprite_frames.get_frame_texture(
		&"effect", 0
	) as AtlasTexture
	return texture.atlas.resource_path
