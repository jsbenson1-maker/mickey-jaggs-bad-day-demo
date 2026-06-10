extends Area2D

class_name SafeHouseZone

@export var safehouse_name: String = "Jaguar Safehouse"

var player_car: PlayerCar = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player_car:
		# Update player's hidden status depending on whether police currently see them
		var is_spotted = _any_police_see_player()
		
		if not is_spotted:
			# Player successfully hides! Clear heat.
			if player_car.has_method("set_hidden_in_safehouse"):
				player_car.set_hidden_in_safehouse(true)
			_clear_police_chases()
		else:
			# Police are actively looking at player in the safehouse entrance
			if player_car.has_method("set_hidden_in_safehouse"):
				player_car.set_hidden_in_safehouse(false)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerCar:
		player_car = body
		# Check if we can immediately hide
		if not _any_police_see_player():
			if player_car.has_method("set_hidden_in_safehouse"):
				player_car.set_hidden_in_safehouse(true)
			_clear_police_chases()
			_show_safehouse_message("HIDDEN IN SAFEHOUSE (HEAT DECAYING)")

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerCar:
		if player_car.has_method("set_hidden_in_safehouse"):
			player_car.set_hidden_in_safehouse(false)
		player_car = null
		_show_safehouse_message("LEFT SAFEHOUSE")

func _any_police_see_player() -> bool:
	var police_nodes = get_tree().get_nodes_in_group("police")
	for node in police_nodes:
		if node is PoliceCruiser:
			# If police is chasing and has clear line of sight
			if node.current_state == PoliceCruiser.AIState.CHASE and node._check_line_of_sight():
				return true
	return false

func _clear_police_chases() -> void:
	var police_nodes = get_tree().get_nodes_in_group("police")
	for node in police_nodes:
		if node is PoliceCruiser:
			if node.current_state == PoliceCruiser.AIState.CHASE:
				node._switch_state(PoliceCruiser.AIState.PATROL)

func _show_safehouse_message(msg: String) -> void:
	var city_scene = get_parent()
	if city_scene and city_scene.has_method("show_hud_message"):
		city_scene.show_hud_message(msg)
