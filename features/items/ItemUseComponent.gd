extends Component
class_name ItemUseComponent

const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal item_use_started
signal item_used(restored_health: float, remaining_charges: int)
signal item_use_cancelled
signal inventory_item_used(item: ItemData, applied_value: float, remaining: int)

@export var config: ItemUseConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _health_component: HealthComponent
var _inventory_component: InventoryComponent
var _quick_access_component: QuickAccessComponent
var _magic_component: MagicComponent
var _progression_component: ProgressionComponent
var _use_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _remaining_charges: int = 0
var _active_inventory_item_id: StringName


func on_initialize() -> void:
	if config == null:
		push_error("ItemUseComponent requires ItemUseConfig")
		disable()
		return

	if (
		config.use_duration <= 0.0
		or config.cooldown < 0.0
		or config.heal_amount <= 0.0
		or config.max_charges < 0
	):
		push_error("ItemUseComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_equipment_component = (
		actor.get_component(EquipmentComponent) as EquipmentComponent
	)
	_health_component = actor.get_component(HealthComponent) as HealthComponent
	_inventory_component = (
		actor.get_component(InventoryComponent) as InventoryComponent
	)
	_quick_access_component = (
		actor.get_component(QuickAccessComponent) as QuickAccessComponent
	)
	_magic_component = actor.get_component(MagicComponent) as MagicComponent
	_progression_component = (
		actor.get_component(ProgressionComponent) as ProgressionComponent
	)

	if _input_component == null or not _input_component.is_enabled:
		push_error("ItemUseComponent requires an enabled InputComponent")
		disable()
		return

	if _equipment_component == null or not _equipment_component.is_enabled:
		push_error("ItemUseComponent requires an enabled EquipmentComponent")
		disable()
		return

	if _health_component == null or not _health_component.is_enabled:
		push_error("ItemUseComponent requires an enabled HealthComponent")
		disable()
		return

	_remaining_charges = config.max_charges
	if not _equipment_component.equipment_changed.is_connected(
		_on_equipment_changed
	):
		_equipment_component.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if _use_timer > 0.0:
		_use_timer = maxf(_use_timer - delta, 0.0)

		if _use_timer == 0.0:
			_finish_item_use()

	if not _equipment_component.is_slot_active(EquipmentComponent.Slot.ITEM):
		return

	if _input_component.consume_interact_pressed():
		use_item()


func use_item() -> bool:
	if not can_use_item():
		return false

	_active_inventory_item_id = _get_selected_inventory_item_id()
	_use_timer = config.use_duration
	item_use_started.emit()
	return true


func use_inventory_item_now(item_id: StringName) -> bool:
	if not can_use_inventory_item_now(item_id):
		return false
	var item := _inventory_component.get_item_data(item_id)
	var applied_value := _apply_inventory_item(item)
	if item == null or applied_value <= 0.0:
		return false
	_inventory_component.remove_item(item.id, 1)
	_cooldown_timer = config.cooldown
	var remaining := _inventory_component.get_quantity(item.id)
	item_used.emit(
		applied_value if item.use_effect == ItemData.UseEffect.HEAL else 0.0,
		remaining
	)
	inventory_item_used.emit(item, applied_value, remaining)
	return true


func can_use_inventory_item_now(item_id: StringName) -> bool:
	if (
		not is_enabled
		or is_using_item()
		or _inventory_component == null
		or not _inventory_component.has_item(item_id)
	):
		return false
	return _can_apply_inventory_item(_inventory_component.get_item_data(item_id))


func can_use_item() -> bool:
	var base_conditions := (
		is_enabled
		and _equipment_component.is_slot_active(EquipmentComponent.Slot.ITEM)
		and not is_using_item()
		and _cooldown_timer <= 0.0
		and _health_component.is_alive()
		and not BEHAVIOR_GATE.is_blocked(actor, self)
	)
	if not base_conditions:
		return false

	var item_id := _get_selected_inventory_item_id()
	if not item_id.is_empty():
		var item := _inventory_component.get_item_data(item_id)
		return (
			item != null
			and _inventory_component.has_item(item_id)
			and _can_apply_inventory_item(item)
		)

	return (
		_remaining_charges > 0
		and _health_component.get_current_health()
			< _health_component.get_max_health()
	)


func is_using_item() -> bool:
	return _use_timer > 0.0


func is_exclusive_behavior_active() -> bool:
	return is_using_item()


func get_remaining_charges() -> int:
	var item_id := _get_selected_inventory_item_id()
	if not item_id.is_empty():
		return _inventory_component.get_quantity(item_id)
	return _remaining_charges


func add_charges(amount: int) -> int:
	if not is_enabled or amount <= 0:
		return 0

	var previous := _remaining_charges
	_remaining_charges = mini(_remaining_charges + amount, config.max_charges)
	return _remaining_charges - previous


func capture_runtime_state() -> Variant:
	return _remaining_charges


func restore_runtime_state(state: Variant) -> void:
	_remaining_charges = clampi(int(state), 0, config.max_charges)


func cancel_item_use() -> void:
	if not is_using_item():
		return

	_use_timer = 0.0
	_active_inventory_item_id = &""
	item_use_cancelled.emit()


func disable() -> void:
	cancel_item_use()
	super.disable()


func _finish_item_use() -> void:
	if not _active_inventory_item_id.is_empty():
		_finish_inventory_item_use()
		return

	_remaining_charges -= 1
	_cooldown_timer = config.cooldown
	var restored_health := _health_component.heal(config.heal_amount)
	item_used.emit(restored_health, _remaining_charges)


func _finish_inventory_item_use() -> void:
	var item := _inventory_component.get_item_data(_active_inventory_item_id)
	var applied_value := _apply_inventory_item(item)
	if item == null or applied_value <= 0.0:
		_active_inventory_item_id = &""
		return

	_inventory_component.remove_item(item.id, 1)
	_cooldown_timer = config.cooldown
	var remaining := _inventory_component.get_quantity(item.id)
	item_used.emit(
		applied_value if item.use_effect == ItemData.UseEffect.HEAL else 0.0,
		remaining
	)
	inventory_item_used.emit(item, applied_value, remaining)
	_active_inventory_item_id = &""


func _get_selected_inventory_item_id() -> StringName:
	if (
		_inventory_component == null
		or not _inventory_component.is_enabled
		or _quick_access_component == null
		or not _quick_access_component.is_enabled
	):
		return &""
	return _quick_access_component.get_active_item_id()


func _can_apply_inventory_item(item: ItemData) -> bool:
	if item == null or item.category != ItemData.Category.CONSUMABLE:
		return false

	match item.use_effect:
		ItemData.UseEffect.HEAL:
			return (
				item.use_value > 0.0
				and _health_component.get_current_health()
					< _health_component.get_max_health()
			)
		ItemData.UseEffect.RESTORE_MANA:
			return (
				item.use_value > 0.0
				and _magic_component != null
				and _magic_component.get_mana() < _magic_component.config.max_mana
			)
		ItemData.UseEffect.GRANT_EXPERIENCE:
			return item.use_value > 0.0 and _progression_component != null

	return false


func _apply_inventory_item(item: ItemData) -> float:
	if not _can_apply_inventory_item(item):
		return 0.0

	match item.use_effect:
		ItemData.UseEffect.HEAL:
			return _health_component.heal(item.use_value)
		ItemData.UseEffect.RESTORE_MANA:
			return _magic_component.restore_mana(item.use_value)
		ItemData.UseEffect.GRANT_EXPERIENCE:
			_progression_component.gain_experience(roundi(item.use_value))
			return item.use_value

	return 0.0


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	current_slot: EquipmentComponent.Slot
) -> void:
	if current_slot != EquipmentComponent.Slot.ITEM:
		cancel_item_use()
