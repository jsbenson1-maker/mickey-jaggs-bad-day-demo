extends Area2D

class_name TrafficLightTrap

enum LightState { GREEN, YELLOW, RED }
var current_state: LightState = LightState.GREEN

@export var green_time: float = 6.0
@export var yellow_time: float = 2.0
@export var red_time: float = 5.0

var state_timer: float = 0.0

@onready var light_indicator: ColorRect = $Visuals/LightIndicator
@onready var state_label: Label = $Visuals/StateLabel

# Keep track of player inside the intersection area
var player_inside: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_light_state(LightState.GREEN)

func _process(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_cycle_state()
		
	# If the player is inside the intersection and the light turns RED (or is RED)
	if player_inside and current_state == LightState.RED:
		_trigger_police_alert()

func _cycle_state() -> void:
	match current_state:
		LightState.GREEN:
			_set_light_state(LightState.YELLOW)
		LightState.YELLOW:
			_set_light_state(LightState.RED)
		LightState.RED:
			_set_light_state(LightState.GREEN)

func _set_light_state(new_state: LightState) -> void:
	current_state = new_state
	match new_state:
		LightState.GREEN:
			state_timer = green_time
			if light_indicator:
				light_indicator.color = Color(0.1, 0.9, 0.2, 0.8) # Neon Green
			if state_label:
				state_label.text = "GO"
		LightState.YELLOW:
			state_timer = yellow_time
			if light_indicator:
				light_indicator.color = Color(0.9, 0.8, 0.1, 0.8) # Yellow
			if state_label:
				state_label.text = "SLOW"
		LightState.RED:
			state_timer = red_time
			if light_indicator:
				light_indicator.color = Color(0.9, 0.1, 0.2, 0.8) # Red
			if state_label:
				state_label.text = "STOP"

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerCar:
		player_inside = body
		if current_state == LightState.RED:
			_trigger_police_alert()

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerCar:
		# If they exit while red, trigger another alert
		if current_state == LightState.RED:
			_trigger_police_alert()
		player_inside = null

func _trigger_police_alert() -> void:
	if not player_inside:
		return
		
	# Find all active police cruisers in the level
	var police_nodes = get_tree().get_nodes_in_group("police")
	if police_nodes.is_empty():
		return
		
	var player_pos = player_inside.global_position
	
	# Alert the nearest police cruiser to the player's coordinates
	var nearest_police: PoliceCruiser = null
	var min_dist = INF
	
	for node in police_nodes:
		if node is PoliceCruiser:
			var dist = global_position.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_police = node
				
	if nearest_police:
		nearest_police.alert_to_position(player_pos)
		
	# Visual flash to show trap alert triggered
	_flash_alert_effect()

func _flash_alert_effect() -> void:
	# Small visual indicator scaling/pulsing on trap alert
	var orig_scale = scale
	var tween = create_tween()
	tween.tween_property(self, "scale", orig_scale * 1.25, 0.1)
	tween.tween_property(self, "scale", orig_scale, 0.1)
