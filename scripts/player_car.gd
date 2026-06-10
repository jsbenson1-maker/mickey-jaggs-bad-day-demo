extends CharacterBody2D

class_name PlayerCar

@export var engine_power: float = 800.0
@export var braking: float = -450.0
@export var max_speed: float = 750.0
@export var max_speed_reverse: float = -250.0
@export var friction: float = 0.985
@export var drag: float = 0.001
@export var steering_angle: float = 4.0 # Steering sensitivity

# Drift physics settings
@export var slip_speed: float = 350.0 # Speed at which tires start to lose grip
@export var traction_fast: float = 0.08 # Side grip when drifting (low value = slidey)
@export var traction_slow: float = 0.8 # Side grip when driving normal (high value = grippy)

var steer_direction: float = 0.0
var acceleration_input: float = 0.0
var current_speed: float = 0.0
var is_drifting: bool = false
var hidden_in_safehouse: bool = false

func set_hidden_in_safehouse(val: bool) -> void:
	hidden_in_safehouse = val

func is_in_safehouse() -> bool:
	return hidden_in_safehouse

@onready var sprite: Sprite2D = $Sprite2D
@onready var headlight_left: PointLight2D = $Headlights/LeftLight
@onready var headlight_right: PointLight2D = $Headlights/RightLight

func _ready() -> void:
	# Sprite faces RIGHT (Vector2.RIGHT is the local forward vector)
	sprite.rotation = 0.0

func _physics_process(delta: float) -> void:
	_get_inputs()
	_apply_physics(delta)

func _get_inputs() -> void:
	steer_direction = Input.get_axis("steer_left", "steer_right")
	acceleration_input = Input.get_axis("brake", "accelerate")

func _apply_physics(delta: float) -> void:
	# 1. Update Steering
	# Adjust steering responsiveness based on velocity: harder to turn at high speed, unable to turn if stopped
	var steer_factor = clamp(velocity.length() / 250.0, 0.15, 1.0)
	# Turn in reverse is inverted
	if current_speed < 0:
		steer_factor *= -1
	rotation += steer_direction * steering_angle * steer_factor * delta
	
	# 2. Update Acceleration & Braking
	var target_accel = acceleration_input * engine_power
	if acceleration_input < 0 and current_speed > 0:
		# Apply stronger deceleration force when braking while moving forward
		target_accel = acceleration_input * abs(braking)
		
	current_speed += target_accel * delta
	
	# Apply overall friction & drag
	current_speed *= friction
	current_speed -= (current_speed * drag * abs(current_speed))
	
	# Clamp speed
	current_speed = clamp(current_speed, max_speed_reverse, max_speed)
	
	# 3. Calculate lateral drift velocity
	var current_heading = Vector2.RIGHT.rotated(rotation)
	
	# Split current velocity into forward-facing and sideways-facing vectors
	var forward_velocity = current_heading * velocity.dot(current_heading)
	var lateral_velocity = velocity - forward_velocity
	
	# Determine if we are drifting
	var lateral_speed = lateral_velocity.length()
	is_drifting = (lateral_speed > slip_speed) or (Input.is_action_pressed("brake") and velocity.length() > 200.0)
	
	# Choose traction coeff based on drift state
	var traction = traction_fast if is_drifting else traction_slow
	
	# Adjust target velocity by applying side-traction dampening
	velocity = forward_velocity + lateral_velocity * (1.0 - traction)
	
	# Add engine forward drive velocity
	velocity += current_heading * current_speed * delta * 60.0 # Scale to feel normal in physics loop
	
	# 4. Slide/Move the body
	move_and_slide()
	
	# Check for collisions (e.g. crashing into walls slows you down)
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		var collider = collision.get_collider()
		
		# If colliding with a police car, trigger game over
		if collider is PoliceCruiser:
			var director = get_tree().current_scene
			if director is Track4Director:
				director.trigger_game_over()
		else:
			# Normal wall crash - bounce and lose speed
			current_speed *= 0.35
			velocity = velocity.bounce(collision.get_normal()) * 0.4
