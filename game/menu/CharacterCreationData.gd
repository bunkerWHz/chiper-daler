extends RefCounted

const TOTAL_POINTS := 10
const ATTRIBUTES := {
	"strength": "Сила", "dexterity": "Ловкость", "intelligence": "Интеллект",
	"endurance": "Выносливость", "wisdom": "Мудрость",
}
# Choices are independent of attributes; extend these catalogs to add starting gear.
const WEAPONS := {
	"Меч": "TrainingSword", "Кинжал": "TrainingDagger",
	"Секира": "TrainingBattleAxe", "Рапира": "TrainingRapier",
	"Лук (+20 стрел)": "TrainingBow", "Арбалет (+12 болтов)": "TrainingCrossbow",
	"Жезл": "TrainingWand", "Посох": "TrainingStaff",
}
const ARMOR := {
	"Кожа разведчика": ["ScoutLeatherArmor", "ScoutLeatherHood", "ScoutLeatherMantle", "ScoutLeatherGloves", "ScoutUtilityBelt", "ScoutLeatherPants", "ScoutLeatherBoots"],
	"Латы рыцаря": ["KnightPlateArmor", "KnightPlateHelm", "KnightPlatePauldrons", "KnightPlateGauntlets", "KnightWarBelt", "KnightPlateLeggings", "KnightPlateGreaves"],
	"Одежда учёного": ["ScholarRobe", "ScholarHood", "ScholarMantle", "ScholarHandwraps", "ScholarSash", "ScholarTrousers", "ScholarShoes"],
}
var character_name := ""
var attributes: Dictionary = {}
var weapon_index := 0
var armor_index := 0

func _init() -> void:
	reset_attributes()

func reset_attributes() -> void:
	for key: String in ATTRIBUTES:
		attributes[key] = 1

func remaining_points() -> int:
	var total := 0
	for key: String in ATTRIBUTES:
		total += int(attributes.get(key, 0))
	return TOTAL_POINTS - total

func change_attribute(key: String, delta: int) -> bool:
	if not ATTRIBUTES.has(key) or delta not in [-1, 1]:
		return false
	if int(attributes[key]) + delta < 1 or (delta > 0 and remaining_points() <= 0):
		return false
	attributes[key] += delta
	return true

func validation_error() -> String:
	if character_name.strip_edges().is_empty():
		return "Введите имя персонажа."
	if character_name.strip_edges().length() > 24 or "\n" in character_name or "\r" in character_name:
		return "Имя должно занимать одну строку, не более 24 символов."
	for key: String in ATTRIBUTES:
		if not attributes.get(key) is int or attributes[key] < 1:
			return "Каждая характеристика должна быть не меньше 1."
	if remaining_points() != 0:
		return "Распределите все 10 очков характеристик."
	if weapon_index < 0 or weapon_index >= WEAPONS.size() or armor_index < 0 or armor_index >= ARMOR.size():
		return "Выберите стартовое снаряжение."
	return ""

func selected_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.append(load("res://game/items/weapons/%s.tres" % WEAPONS.values()[weapon_index]))
	for filename: String in ARMOR.values()[armor_index]:
		result.append(load("res://game/items/armor/%s.tres" % filename))
	return result

func equipment_weight() -> float:
	var total := 0.0
	for item: ItemData in selected_items():
		total += item.weight
	var weapon: ItemData = selected_items()[0]
	if weapon.get_combat_mode() == ItemData.CombatMode.BOW:
		total += preload("res://game/items/ammunition/TrainingArrows.tres").weight * 20
	elif weapon.get_combat_mode() == ItemData.CombatMode.CROSSBOW:
		total += preload("res://game/items/ammunition/TrainingBolts.tres").weight * 12
	return total

func player_state() -> Dictionary:
	if not validation_error().is_empty():
		return {}
	var stats := attributes.duplicate()
	stats["attack_speed_multiplier"] = 1.0
	var stacks: Array[Dictionary] = []
	var equipped := {}
	for item: ItemData in selected_items():
		stacks.append({"item_id": String(item.id), "quantity": 1})
		var slot := item.equipment_profile.get_primary_slot()
		equipped["%d:0:%d" % [slot, 0 if slot == ItemData.EquipSlot.MAIN_HAND else -1]] = item.id
	var weapon: ItemData = selected_items()[0]
	var mode := EquipmentComponent.Slot.MELEE
	match weapon.get_combat_mode():
		ItemData.CombatMode.BOW:
			mode = EquipmentComponent.Slot.BOW
			stacks.append({"item_id": "training_arrows", "quantity": 20})
			equipped["%d:0:0" % ItemData.EquipSlot.OFF_HAND] = &"training_arrows"
		ItemData.CombatMode.CROSSBOW:
			mode = EquipmentComponent.Slot.CROSSBOW
			stacks.append({"item_id": "training_bolts", "quantity": 12})
			equipped["%d:0:0" % ItemData.EquipSlot.OFF_HAND] = &"training_bolts"
		ItemData.CombatMode.MAGIC:
			mode = EquipmentComponent.Slot.MAGIC
	for path: String in ["HealthPotion", "ManaPotion"]:
		var flask := load("res://game/items/consumables/%s.tres" % path) as ItemData
		stacks.append({"item_id": String(flask.id), "quantity": 1})
	return {
		"identity": {"name": character_name.strip_edges()},
		"attributes": stats,
		"inventory": {"stacks": stacks, "amber": 0, "weapon_upgrades": {}},
		"equipment": {"action_slot": mode, "active_weapon_set": 0, "equipped_items": equipped},
		"quick_access": {"active_slot": 0, "assignments": []},
		"progression": {"level": 1, "experience": 0},
	}
