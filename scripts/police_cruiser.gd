extends CharacterBody2D

class_name PoliceCruiser

enum AIState { PATROL, ALERTED, CHASE }
var current_state: AIState = AIState.PATROL

@export var patrol_speed: float = 350.0
@export var chase_speed: float = 580.0
@export var detection_range: float = 1200.0

# Patrol waypoints - coordinates for city block loops
@export var patrol_waypoints: Array[Vector2] = []
var current_waypoint_idx: int = 0

var target_player: CharacterBody2D = null
var alerted_position: Vector2 = Vector2.ZERO
var lose_player_timer: float = 0.0
const LOSE_PLAYER_TIME: float = 4.0 # Seconds before giving up chase

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var red_blue_light: PointLight2D = $Siren/SirenLight

var siren_timer: float = 0.0

func _ready() -> void:
	# Add to police group for traffic light signaling
	add_to_group("police")
	
	# Try to find the player in the scene
	var players = get_tree().get_nodes_in_group("player_car")
	if not players.is_empty():
		target_player = players[0]
		
	# Setup navigation parameters
	nav_agent.path_desired_distance = 60.0
	nav_agent.target_desired_distance = 60.0
	
	# If no waypoints were set in editor, create standard default loop around current spawn
	if patrol_waypoints.is_empty():
		patrol_waypoints = [
			global_position,
			global_position + Vector2(800, 0),
			global_position + Vector2(800, 800),
			global_position + Vector2(0, 800)
		]
	
	_set_patrol_target()

func _physics_process(delta: float) -> void:
	# Siren flashing effect
	siren_timer += delta * 15.0
	if red_blue_light:
		red_blue_light.color = Color(1, 0, 0) if sin(siren_timer) > 0 else Color(0, 0, 1)
		red_blue_light.energy = 1.5 + sin(siren_timer) * 0.5
		
	_update_state(delta)
	_move_towards_target(delta)

func _update_state(delta: float) -> void:
	if not target_player:
		return
		
	var dist_to_player = global_position.distance_to(target_player.global_position)
	var has_los = _check_line_of_sight()
	
	# Safehouse checks: if player is in safehouse, police can't chase unless they have direct LOS
	var player_in_safehouse = target_player.has_method("is_in_safehouse") and target_player.is_in_safehouse()
	
	match current_state:
		AIState.PATROL:
			# If player is within range and we have line of sight (and player is not hidden in safehouse)
			if dist_to_player <= detection_range and has_los and not player_in_safehouse:
				_switch_state(AIState.CHASE)
			elif nav_agent.is_navigation_finished():
				current_waypoint_idx = (current_waypoint_idx + 1) % patrol_waypoints.size()
				_set_patrol_target()
				
		AIState.ALERTED:
			# Check if player is detected during alert response
			if dist_to_player <= detection_range and has_los and not player_in_safehouse:
				_switch_state(AIState.CHASE)
			elif nav_agent.is_navigation_finished():
				# We reached the alert spot but found nothing. Go back to patrol.
				_flash_siren_colors(Color(0.2, 0.2, 0.2)) # Dim siren
				_switch_state(AIState.PATROL)
				
		AIState.CHASE:
			# Update navigation target to player position continuously
			nav_agent.target_position = target_player.global_position
			
			# If we lose line of sight, or if player hides in safehouse out of sight
			if not has_los or player_in_safehouse:
				lose_player_timer += delta
				if lose_player_timer >= LOSE_PLAYER_TIME:
					_switch_state(AIState.PATROL)
			else:
				lose_player_timer = 0.0

func _switch_state(new_state: AIState) -> void:
	current_state = new_state
	match new_state:
		AIState.PATROL:
			_set_patrol_target()
		AIState.ALERTED:
			nav_agent.target_position = alerted_position
		AIState.CHASE:
			lose_player_timer = 0.0
			nav_agent.target_position = target_player.global_position

func _set_patrol_target() -> void:
	nav_agent.target_position = patrol_waypoints[current_waypoint_idx]

# Check Line of Sight to player using physics raycast
func _check_line_of_sight() -> bool:
	if not target_player:
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_player.global_position)
	# Collision Layer 2 is Environment (buildings, obstacles)
	query.collision_mask = 2
	var result = space_state.intersect_ray(query)
	
	# If ray reaches player without hitting walls, we have LOS
	return result.is_empty()

func _move_towards_target(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_pos)
	
	var current_speed = chase_speed if current_state == AIState.CHASE else patrol_speed
	velocity = dir * current_speed
	
	move_and_slide()
	
	# Smoothly rotate sprite to match velocity heading
	if velocity.length() > 20.0:
		var target_rot = velocity.angle()
		rotation = rotate_toward(rotation, target_rot, 5.0 * delta)

# Signal callback for Traffic Light alert overrides
func alert_to_position(pos: Vector2) -> void:
	# Only override if not already in active chase
	if current_state != AIState.CHASE:
		alerted_position = pos
		_switch_state(AIState.ALERTED)

func _flash_siren_colors(col: Color) -> void:
	if red_blue_light:
		red_blue_light.color = col
