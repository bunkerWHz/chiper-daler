extends Component
class_name ItemUseComponent

signal item_use_started
signal item_used(restored_health: float, remaining_charges: int)
signal item_use_cancelled

@export var config: ItemUseConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _health_component: HealthComponent
var _use_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _remaining_charges: int = 0


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
	_equipment_component.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if _use_timer > 0.0:
		_use_timer = maxf(_use_timer - delta, 0.0)

		if _use_timer == 0.0:
			_finish_item_use()

	if not _equipment_component.is_slot_active(EquipmentComponent.Slot.ITEM):
		return

	if _input_component.consume_attack_pressed():
		use_item()


func use_item() -> bool:
	if not can_use_item():
		return false

	_use_timer = config.use_duration
	item_use_started.emit()
	return true


func can_use_item() -> bool:
	return (
		is_enabled
		and _equipment_component.is_slot_active(EquipmentComponent.Slot.ITEM)
		and not is_using_item()
		and _cooldown_timer <= 0.0
		and _remaining_charges > 0
		and _health_component.is_alive()
		and _health_component.get_current_health()
			< _health_component.get_max_health()
	)


func is_using_item() -> bool:
	return _use_timer > 0.0


func get_remaining_charges() -> int:
	return _remaining_charges


func cancel_item_use() -> void:
	if not is_using_item():
		return

	_use_timer = 0.0
	item_use_cancelled.emit()


func disable() -> void:
	cancel_item_use()
	super.disable()


func _finish_item_use() -> void:
	_remaining_charges -= 1
	_cooldown_timer = config.cooldown
	var restored_health := _health_component.heal(config.heal_amount)
	item_used.emit(restored_health, _remaining_charges)


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	current_slot: EquipmentComponent.Slot
) -> void:
	if current_slot != EquipmentComponent.Slot.ITEM:
		cancel_item_use()
