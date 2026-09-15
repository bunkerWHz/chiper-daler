extends CharacterBody2D
class_name AmberShardPickup

signal collected(collector: Actor, amount: int)
@export_range(1, 100000, 1) var amount: int = 25
@export var gravity: float = 1200.0
var _collected := false

func _ready() -> void:
	$PickupArea.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()

func _on_body_entered(body: Node2D) -> void:
	var node: Node = body
	while node != null and not node is Actor:
		node = node.get_parent()
	try_collect(node as Actor)

func try_collect(collector: Actor) -> bool:
	if _collected or amount <= 0 or collector == null:
		return false
	var health := collector.get_component(HealthComponent) as HealthComponent
	if health != null and health.is_dead():
		return false
	var inventory := collector.get_component(InventoryComponent) as InventoryComponent
	if inventory == null or not inventory.is_enabled:
		return false
	_collected = true
	inventory.add_amber(amount)
	collected.emit(collector, amount)
	queue_free()
	return true
