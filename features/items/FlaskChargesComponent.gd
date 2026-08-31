extends Component
class_name FlaskChargesComponent

signal charges_changed(item_id: StringName, current: int, maximum: int)
signal flasks_refilled

var _inventory: InventoryComponent
var _charges: Dictionary = {}


func on_initialize() -> void:
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	if _inventory == null or not _inventory.is_enabled:
		push_error("FlaskChargesComponent requires an enabled InventoryComponent")
		disable()
		return

	_register_owned_flasks()
	if not _inventory.item_added.is_connected(_on_item_added):
		_inventory.item_added.connect(_on_item_added)


func has_flask(item_id: StringName) -> bool:
	return _charges.has(item_id) and _inventory.has_item(item_id)


func get_charges(item_id: StringName) -> int:
	return int(_charges.get(item_id, 0))


func get_max_charges(item_id: StringName) -> int:
	var item := _inventory.get_item_data(item_id)
	return item.get_flask_max_charges() if item != null else 0


func can_spend_charge(item_id: StringName) -> bool:
	return is_enabled and has_flask(item_id) and get_charges(item_id) > 0


func spend_charge(item_id: StringName) -> bool:
	if not can_spend_charge(item_id):
		return false
	_charges[item_id] = get_charges(item_id) - 1
	charges_changed.emit(
		item_id, get_charges(item_id), get_max_charges(item_id)
	)
	return true


func refill_all() -> int:
	if not is_enabled:
		return 0
	var restored := 0
	for item_id: StringName in _charges.keys():
		var previous := get_charges(item_id)
		var maximum := get_max_charges(item_id)
		if previous >= maximum:
			continue
		_charges[item_id] = maximum
		restored += maximum - previous
		charges_changed.emit(item_id, maximum, maximum)
	if restored > 0:
		flasks_refilled.emit()
	return restored


func capture_runtime_state() -> Variant:
	return _charges.duplicate()


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	_register_owned_flasks()
	for item_id: StringName in _charges.keys():
		var state_key: Variant = (
			item_id if state.has(item_id) else String(item_id)
		)
		if not state.has(state_key):
			continue
		_charges[item_id] = clampi(
			int(state[state_key]), 0, get_max_charges(item_id)
		)
		charges_changed.emit(
			item_id, get_charges(item_id), get_max_charges(item_id)
		)


func get_runtime_state_restore_priority() -> int:
	return -90


func _register_owned_flasks() -> void:
	for stack: InventoryStack in _inventory.get_stacks():
		_register_flask(stack.item)


func _register_flask(item: ItemData) -> void:
	if item == null or not item.is_flask() or _charges.has(item.id):
		return
	_charges[item.id] = item.get_flask_max_charges()
	charges_changed.emit(
		item.id, get_charges(item.id), get_max_charges(item.id)
	)


func _on_item_added(item: ItemData, _quantity: int) -> void:
	_register_flask(item)
