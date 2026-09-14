extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1000, 40)
	shape.shape = rectangle
	floor_body.add_child(shape)
	floor_body.position.y = 100
	world.add_child(floor_body)
	var floor_art := Polygon2D.new()
	floor_art.polygon = PackedVector2Array([Vector2(-500, 80), Vector2(500, 80), Vector2(500, 120), Vector2(-500, 120)])
	floor_art.color = Color(0.18, 0.23, 0.28)
	world.add_child(floor_art)
	var player := (load("res://game/player/Player.tscn") as PackedScene).instantiate() as Actor
	world.add_child(player)
	var camera_component := player.get_component(CameraComponent)
	if camera_component != null:
		camera_component.disable()
	var camera := Camera2D.new()
	camera.position = Vector2(0, 10)
	camera.zoom = Vector2(3, 3)
	world.add_child(camera)
	camera.make_current()
	for frame in 90:
		await physics_frame
	var swap := player.get_component(EquipmentSwapComponent) as EquipmentSwapComponent
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var state := player.get_component(ActorStateComponent) as ActorStateComponent
	var body := player.get_component(CharacterBodyComponent) as CharacterBodyComponent
	var view := player.get_node("EquipmentSwapView") as EquipmentSwapView
	var animation := player.get_node("_Visual/AnimationPlayer") as AnimationPlayer
	_check(body.is_on_floor(), "Player must settle on the floor")
	_check(swap.request_cycle(), "Standing player must begin changing equipment")
	var start_x := player.position.x
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for frame in 30:
		await physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_check(absf(player.position.x - start_x) < 0.1, "Movement must be blocked during swap")
	_check(body.is_on_floor(), "Jump must be blocked during swap")
	_check(state.get_state() == ActorState.Behavior.EQUIPMENT_SWAP, "FSM must report EquipmentSwap")
	_check(animation.current_animation == &"equipment_swap", "Swap animation must be selected")
	_check(view.visible, "World progress bar must be visible")
	_check(equipment.get_active_weapon_set() == 0, "Equipment must not change early")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/equipment_swap_preview.png")
	var hurtbox := player.get_component(HurtboxComponent) as HurtboxComponent
	hurtbox.receive_hit(HitData.new(1.0, null))
	_check(not swap.is_swapping(), "Enemy hit must cancel swapping")
	_check(not view.visible, "Cancellation must hide the world bar immediately")
	_check(equipment.get_active_weapon_set() == 0, "Interrupted swap must keep old equipment")
	for frame in 60:
		await physics_frame
	var menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent
	(player.get_component(CharacterAttributesComponent) as CharacterAttributesComponent).attack_speed_multiplier = 2.0
	menu.open_inventory()
	_check(paused, "Inventory pauses the game")
	menu._activate_weapon_set(1)
	_check(not paused and not menu.is_open(), "Menu request must return to gameplay")
	_check(swap.is_swapping() and equipment.get_active_weapon_set() == 0, "Menu must also use delayed swapping")
	_check(is_equal_approx(swap.get_duration(), 1.0), "Double attack speed must halve swap duration")
	menu.open_inventory()
	_check(not paused, "Inventory cannot interrupt the action with a pause")
	await process_frame
	await process_frame
	_check(is_equal_approx(animation.get_playing_speed(), 2.0), "Placeholder clip must follow swap speed")
	for frame in 160:
		await physics_frame
	_check(equipment.get_active_weapon_set() == 1, "Completed swap must change equipment")
	_check(not swap.is_swapping() and not view.visible, "Completed swap must release action and hide bar")
	print("Equipment swap runtime check: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
