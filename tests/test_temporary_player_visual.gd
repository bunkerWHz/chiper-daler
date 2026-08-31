@tool
extends McpTestSuite


func suite_name() -> String:
	return "temporary_player_visual"


func test_active_main_hand_selects_temporary_visual_profile() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as TemporaryPlayerVisualComponent
	var equipment := setup.equipment as EquipmentComponent
	var inventory := setup.inventory as InventoryComponent

	assert_eq(visual.get_visual_profile(), ItemData.VisualArchetype.WARRIOR)
	assert_true(equipment.switch_weapon_set(1))
	assert_eq(visual.get_visual_profile(), ItemData.VisualArchetype.ARCHER)
	var attributes := (
		setup.player.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	attributes.set_strength(6)
	assert_true(equipment.equip_inventory_item(
		&"training_halberd", ItemData.EquipSlot.MAIN_HAND, 0, 1
	))
	assert_eq(visual.get_visual_profile(), ItemData.VisualArchetype.LANCER)
	assert_eq(inventory.get_quantity(&"training_halberd"), 1)


func test_item_and_buff_effects_render_on_separate_overlays() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as TemporaryPlayerVisualComponent
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
		player.get_component(TemporaryPlayerVisualComponent)
		as TemporaryPlayerVisualComponent
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


func _effect_atlas_path(visual: TemporaryPlayerVisualComponent) -> String:
	var texture := visual.get_item_effect_sprite().sprite_frames.get_frame_texture(
		&"effect", 0
	) as AtlasTexture
	return texture.atlas.resource_path
