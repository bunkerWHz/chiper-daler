extends Component
class_name ThrowingComponent

enum Phase { NONE, AIM, ACTION, RECOVERY }

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal throwable_released(direction: Vector2, remaining_charges: int)
signal charges_changed

const PROJECTILE_SCENE := preload("res://features/throwing/ThrownProjectile.tscn")
const BEHAVIOR_GATE := preload("res://features/state/ExclusiveBehaviorGate.gd")

@export var config: ThrowingConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _inventory: InventoryComponent
var _quick_access: QuickAccessComponent
var _aim: AimingComponent
var _phase: Phase = Phase.NONE
var _phase_timer: float = 0.0
var _item_id: StringName


func on_initialize() -> void:
	if config == null or config.action_duration <= 0.0 or config.recovery_duration <= 0.0:
		push_error("ThrowingComponent requires valid ThrowingConfig")
		disable()
		return
	_input_component = actor.get_component(InputComponent) as InputComponent
	_equipment_component = actor.get_component(EquipmentComponent) as EquipmentComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_quick_access = actor.get_component(QuickAccessComponent) as QuickAccessComponent
	_aim = actor.get_component(AimingComponent) as AimingComponent
	for dependency: Component in [_input_component, _equipment_component, _inventory, _quick_access, _aim]:
		if dependency == null or not dependency.is_enabled:
			push_error("ThrowingComponent requires enabled input, equipment, inventory, quick access and aiming")
			disable()
			return
	if not _aim.aim_cancelled.is_connected(_on_aim_cancelled):
		_aim.aim_cancelled.connect(_on_aim_cancelled)
	if not _quick_access.active_slot_changed.is_connected(_on_quick_slot_changed):
		_quick_access.active_slot_changed.connect(_on_quick_slot_changed)
	if not _quick_access.slot_assignment_changed.is_connected(_on_slot_assignment_changed):
		_quick_access.slot_assignment_changed.connect(_on_slot_assignment_changed)
	if not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)
	if not _equipment_component.weapon_set_changed.is_connected(_on_weapon_set_changed):
		_equipment_component.weapon_set_changed.connect(_on_weapon_set_changed)
	if not _equipment_component.loadout_item_changed.is_connected(_on_loadout_changed):
		_equipment_component.loadout_item_changed.connect(_on_loadout_changed)


func _process(delta: float) -> void:
	_update_phase(delta)
	if _phase == Phase.NONE:
		var item := _selected_throwable()
		if item != null and _input_component.consume_interact_pressed():
			if not BEHAVIOR_GATE.is_blocked(actor, self) and _aim.begin_aim(self):
				_item_id = item.id
				_set_phase(Phase.AIM, 0.0)
	if _phase == Phase.AIM:
		if _input_component.consume_guard_just_pressed():
			cancel_throw()
		elif _input_component.consume_interact_released():
			_release_throwable()


func _selected_throwable() -> ItemData:
	var item := _inventory.get_item_data(_quick_access.get_active_item_id())
	if item == null or item.category != ItemData.Category.THROWABLE or not item.usable_in_combat:
		return null
	var profile := item.get_projectile_profile()
	return item if profile != null and profile.is_valid() else null


func get_phase() -> Phase:
	return _phase


func is_exclusive_behavior_active() -> bool:
	return _phase != Phase.NONE


func get_remaining_charges() -> int:
	if _inventory == null or _quick_access == null:
		return 0
	var item := _selected_throwable()
	return _inventory.get_quantity(item.id) if item != null else 0


func cancel_throw() -> void:
	if _phase != Phase.NONE:
		_set_phase(Phase.NONE, 0.0)


func disable() -> void:
	cancel_throw()
	super.disable()


func _release_throwable() -> void:
	var item := _selected_throwable()
	if item == null or item.id != _item_id or actor.get_parent() == null:
		cancel_throw()
		return
	var profile := item.get_projectile_profile()
	var direction := _aim.get_direction()
	var origin := _aim.get_launch_position()
	# Commit the phase before inventory signals can switch an exhausted quick slot.
	_set_phase(Phase.ACTION, config.action_duration)
	if _inventory.remove_item(item.id, 1) != 1:
		cancel_throw()
		return
	var projectile := PROJECTILE_SCENE.instantiate() as ThrownProjectile
	projectile.fit_throwable(actor, profile.texture)
	actor.get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile.setup_direction(actor, direction, profile.speed, profile.damage,
		profile.knockback, profile.lifetime, profile.texture, profile.gravity, profile.rotation_speed,
		profile.status_effects)
	throwable_released.emit(direction, _inventory.get_quantity(item.id))


func _update_phase(delta: float) -> void:
	if _phase == Phase.AIM or _phase == Phase.NONE:
		return
	_phase_timer = maxf(_phase_timer - delta, 0.0)
	if _phase_timer > 0.0:
		return
	if _phase == Phase.ACTION:
		_set_phase(Phase.RECOVERY, config.recovery_duration)
	elif _phase == Phase.RECOVERY:
		_set_phase(Phase.NONE, 0.0)


func _set_phase(value: Phase, duration: float) -> void:
	if value == _phase:
		return
	var previous := _phase
	if value != Phase.AIM and _aim != null:
		_aim.end_aim(self)
	_phase = value
	_phase_timer = duration
	if value == Phase.NONE:
		_item_id = &""
	phase_changed.emit(previous, _phase)


func _on_aim_cancelled(aim_owner: Component) -> void:
	if aim_owner == self:
		cancel_throw()


func _on_quick_slot_changed(_previous: int, _current: int) -> void:
	if _phase == Phase.AIM:
		cancel_throw()


func _on_slot_assignment_changed(index: int, _id: StringName) -> void:
	if index == _quick_access.get_active_slot() and _phase == Phase.AIM:
		cancel_throw()


func _on_inventory_changed() -> void:
	if _phase == Phase.AIM and not _inventory.has_item(_item_id):
		cancel_throw()
	charges_changed.emit()


func _on_weapon_set_changed(_previous: int, _current: int) -> void:
	if _phase == Phase.AIM:
		cancel_throw()


func _on_loadout_changed(slot: ItemData.EquipSlot, _index: int, weapon_set: int,
	_previous: StringName, _current: StringName) -> void:
	if slot in [ItemData.EquipSlot.MAIN_HAND, ItemData.EquipSlot.OFF_HAND] and weapon_set == _equipment_component.get_active_weapon_set() and _phase == Phase.AIM:
		cancel_throw()
