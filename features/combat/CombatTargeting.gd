extends RefCounted


static func is_valid_hostile(
	source_actor: Actor,
	hurtbox: HurtboxComponent
) -> bool:
	if (
		hurtbox == null
		or not is_instance_valid(hurtbox)
		or not hurtbox.is_enabled
		or hurtbox.actor == source_actor
		or not is_instance_valid(hurtbox.actor)
	):
		return false

	var health := hurtbox.actor.get_component(HealthComponent) as HealthComponent

	if health == null or not health.is_enabled or not health.is_alive():
		return false

	var source_faction := (
		source_actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)
	var target_faction := (
		hurtbox.actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)

	if source_faction == null or target_faction == null:
		return true

	return source_faction.is_hostile_to(target_faction.faction)


static func get_closest_hostile(
	source_actor: Actor,
	targets: Array[HurtboxComponent]
) -> HurtboxComponent:
	var closest_target: HurtboxComponent
	var closest_distance_squared := INF

	for target: HurtboxComponent in targets:
		if not is_valid_hostile(source_actor, target):
			continue

		var distance_squared := source_actor.global_position.distance_squared_to(
			target.actor.global_position
		)

		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = target

	return closest_target
