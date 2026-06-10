extends CharacterBody2D

class_name JaggsPlayer

@export var speed: float = 500.0

var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	target_position = global_position
	_setup_sprite_frames()

# Programmatically build SpriteFrames to keep the scene file clean and robust
func _setup_sprite_frames() -> void:
	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default") # Remove default
	
	# 1. Idle Animation
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.set_animation_speed("idle", 6.0)
	for i in range(4):
		var path = "res://Assets/Images/MJBD_000%d_Jaggs-Idle-%d.png" % [i, i + 1]
		var tex = load(path)
		if tex:
			sprite_frames.add_frame("idle", tex)
			
	# 2. Walk Animation
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_loop("walk", true)
	sprite_frames.set_animation_speed("walk", 5.0)
	for i in [1, 0]:
		var path = "res://Assets/Images/MJBD__000%d_Jaggs-walk-%d.png" % [i, 2 - i]
		var tex = load(path)
		if tex:
			sprite_frames.add_frame("walk", tex)
			
	# 3. Run Animation (Used if clicked far away)
	sprite_frames.add_animation("run")
	sprite_frames.set_animation_loop("run", true)
	sprite_frames.set_animation_speed("run", 10.0)
	for i in range(1, 7):
		var path = "res://Assets/Images/MJBD__000%d_Jaggs-run-%d.png" % [i + 1, i]
		var tex = load(path)
		if tex:
			sprite_frames.add_frame("run", tex)
			
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Keep sprite scale consistent across animations (compensates for cropped source assets)
	_adjust_sprite_scale()
	
	if not is_moving:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		return
		
	var distance_to_target = global_position.distance_to(target_position)
	if distance_to_target < 10.0:
		global_position = target_position
		is_moving = false
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		return
		
	# Select animation speed and type based on distance
	var current_speed = speed
	if distance_to_target > 600.0:
		current_speed = speed * 1.5
		animated_sprite.play("run")
	else:
		animated_sprite.play("walk")
		
	var dir = global_position.direction_to(target_position)
	velocity = dir * current_speed
	
	# Flip sprite depending on direction
	if dir.x != 0:
		animated_sprite.flip_h = (dir.x < 0)
		
	move_and_slide()

func _adjust_sprite_scale() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
		
	var anim = animated_sprite.animation
	match anim:
		"idle":
			animated_sprite.scale = Vector2(1.0, 1.0)
		"walk":
			# Walk textures are 1116px tall vs 1406px idle. Scale up to compensate.
			animated_sprite.scale = Vector2(1.26, 1.26)
		"run":
			# Run textures are around 1040px tall. Scale up to compensate.
			animated_sprite.scale = Vector2(1.32, 1.32)

func set_move_target(target: Vector2) -> void:
	target_position = target
	is_moving = true
