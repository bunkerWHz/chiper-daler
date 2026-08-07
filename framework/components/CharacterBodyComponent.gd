extends Component
class_name CharacterBodyComponent

const BODY_NODE = "CharacterBody2D"

func get_body() -> CharacterBody2D: 
	return actor.get_component(CharacterBodyComponent).find_child(BODY_NODE)
