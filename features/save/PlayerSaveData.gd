extends RefCounted

# Stable file keys: independent of component node names and scene hierarchy.
var component_types := {
	"inventory": InventoryComponent,
	"attributes": CharacterAttributesComponent,
	"progression": ProgressionComponent,
	"equipment": EquipmentComponent,
	"quick_access": QuickAccessComponent,
}

var items: Dictionary = {}
var catalog_valid := true


func _init() -> void:
	_scan_items("res://game/items")


func _scan_items(directory: String) -> void:
	# ResourceLoader also lists source resource names in exported PCK builds.
	for entry: String in ResourceLoader.list_directory(directory):
		var path := directory.path_join(entry)
		if entry == "templates/":
			continue
		if entry.ends_with("/"):
			_scan_items(path.trim_suffix("/"))
		elif entry.ends_with(".tres"):
			var item := load(path) as ItemData
			if item == null:
				continue
			if item.id.is_empty() or items.has(String(item.id)):
				catalog_valid = false
				push_error("Missing or duplicate save item ID: " + path)
			items[String(item.id)] = item


func capture(actor: Actor) -> Dictionary:
	var result := {}
	for key: String in component_types:
		var component := actor.get_component(component_types[key])
		if component == null:
			continue
		var state: Variant = component.capture_runtime_state()
		if key == "inventory":
			for stack: Dictionary in state.stacks:
				stack["item_id"] = String(stack.item.id)
				stack.erase("item")
		result[key] = state
	return result


func restore(actor: Actor, data: Dictionary) -> void:
	var components := actor.get_components()
	components.sort_custom(func(a: Component, b: Component) -> bool:
		return a.get_runtime_state_restore_priority() < b.get_runtime_state_restore_priority())
	for component: Component in components:
		for key: String in component_types:
			if not is_instance_of(component, component_types[key]) or not data.has(key):
				continue
			var state: Variant = data[key]
			if key == "inventory":
				state = state.duplicate(true)
				for stack: Dictionary in state.stacks:
					stack["item"] = items[String(stack.item_id)]
			component.restore_runtime_state(state)
	# Derived maxima have now been recalculated from attributes and equipment.
	var health := actor.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.heal(health.get_max_health())
	var magic := actor.get_component(MagicComponent) as MagicComponent
	if magic != null:
		magic.restore_mana(magic.get_max_mana())
	var flasks := actor.get_component(FlaskChargesComponent) as FlaskChargesComponent
	if flasks != null:
		flasks.refill_all()


func validate(data: Variant) -> bool:
	if not catalog_valid or not data is Dictionary or not _plain_data(data):
		return false
	for key: String in data:
		# Legacy separate ammo counters are validated but no longer restored.
		if not component_types.has(key) and key not in ["ranged", "throwing"]:
			return false
		if key == "throwing":
			if not _count(data[key]):
				return false
		elif not data[key] is Dictionary:
			return false
	if data.has("inventory"):
		var inv: Dictionary = data.inventory
		if not inv.get("stacks") is Array or not _count(inv.get("amber")) or not inv.get("weapon_upgrades") is Dictionary:
			return false
		for stack: Variant in inv.stacks:
			if not stack is Dictionary or not _text(stack.get("item_id")) or not items.has(String(stack.item_id)):
				return false
			if not _count(stack.get("quantity")) or stack.quantity == 0:
				return false
		for id: Variant in inv.weapon_upgrades:
			if not _text(id) or not items.has(String(id)) or not _count(inv.weapon_upgrades[id]):
				return false
	for key: String in ["attributes", "progression", "ranged"]:
		if data.has(key):
			var required := {
				"attributes": ["strength", "dexterity", "intelligence", "endurance", "wisdom", "attack_speed_multiplier"],
				"progression": ["level", "experience"],
				"ranged": ["arrows", "bolts"],
			}
			if not data[key].has_all(required[key]):
				return false
			for field: Variant in data[key]:
				if field == "attack_speed_multiplier":
					if not data[key][field] is float and not data[key][field] is int:
						return false
				elif not _count(data[key][field]):
					return false
	if data.has("equipment"):
		var eq: Dictionary = data.equipment
		if not _count(eq.get("action_slot")) or not _count(eq.get("active_weapon_set")) or not eq.get("equipped_items") is Dictionary:
			return false
		for key: Variant in eq.equipped_items:
			if not _text(key) or not _text(eq.equipped_items[key]):
				return false
	if data.has("quick_access"):
		var quick: Dictionary = data.quick_access
		if not _count(quick.get("active_slot")) or not quick.get("assignments") is Array:
			return false
		for id: Variant in quick.assignments:
			if not _text(id):
				return false
	return true


func _plain_data(value: Variant, depth: int = 0) -> bool:
	if depth > 12:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not _text(key) or not _plain_data(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for entry: Variant in value:
			if not _plain_data(entry, depth + 1):
				return false
		return true
	return _text(value) or value is bool or value is int or (value is float and is_finite(value))


func _text(value: Variant) -> bool:
	return value is String or value is StringName


func _count(value: Variant) -> bool:
	return value is int and value >= 0 and value <= 2147483647
