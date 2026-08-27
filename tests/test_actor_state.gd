@tool
extends McpTestSuite


func suite_name() -> String:
	return "actor_state"


func test_actor_state_taxonomy_contains_planned_layers() -> void:
	assert_eq(
		ActorState.get_locomotion_name(ActorState.Locomotion.DOUBLE_JUMPING),
		"DoubleJumping"
	)
	assert_eq(
		ActorState.get_action_name(ActorState.Action.MAGIC_CHANNELING),
		"MagicChanneling"
	)


func test_actor_state_conditions_can_overlap() -> void:
	var conditions := (
		ActorState.Condition.STUNNED
		| ActorState.Condition.DEBUFFED
	)

	assert_true(
		ActorState.has_condition(conditions, ActorState.Condition.STUNNED)
	)
	assert_true(
		ActorState.has_condition(conditions, ActorState.Condition.DEBUFFED)
	)
	assert_false(
		ActorState.has_condition(conditions, ActorState.Condition.BUFFED)
	)
	assert_eq(ActorState.get_condition_names(conditions).size(), 2)
