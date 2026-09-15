extends Area2D

var amount := 0


func _ready() -> void:
	$Label.text = "Вернуть янтарь: %d" % amount
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var candidate: Node = body
	while candidate != null and not candidate is Actor:
		candidate = candidate.get_parent()
	try_collect(candidate as Actor)


func try_collect(collector: Actor) -> bool:
	return get_node("/root/GameFlow").saves.recover_lost_amber(self, collector)
