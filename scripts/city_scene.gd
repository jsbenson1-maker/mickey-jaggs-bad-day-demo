extends Node2D

class_name CityScene

# Game Win signal
signal getaway_success

# Positions for game layout
const PLAYER_SPAWN_POS = Vector2(600, 2600)   # Lower-left lot outside the garage
const OFF_RAMP_POS = Vector2(5350, 850)       # Highway off-ramp on the right edge

# Off-ramp zone node
@onready var player: PlayerCar = $YSort/PlayerCar
@onready var camera: Camera2D = $YSort/PlayerCar/Camera2D
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

# HUD UI references
@onready var hud: Control = $CanvasLayer/HUD
@onready var speed_label: Label = $CanvasLayer/HUD/Panel/SpeedLabel
@onready var heat_bar: ProgressBar = $CanvasLayer/HUD/Panel/HeatBar
@onready var status_label: Label = $CanvasLayer/HUD/Panel/StatusLabel
@onready var arrow_indicator: Sprite2D = $CanvasLayer/HUD/ArrowIndicator
@onready var win_ui: Control = $CanvasLayer/WinUI

# Initial positions of police to reset them on retry
var police_spawns = []

func _ready() -> void:
	win_ui.visible = false
	hud.visible = false
	
	# Connect highway off-ramp
	$YSort/OffRampArea.body_entered.connect(_on_off_ramp_entered)
	
	# Programmatically generate Navigation Mesh to ensure perfect pathfinding
	_build_navigation_polygons()
	
	# Save police spawn positions
	for child in $YSort.get_children():
		if child is PoliceCruiser:
			police_spawns.append({
				"node": child,
				"spawn_pos": child.global_position,
				"waypoints": child.patrol_waypoints.duplicate()
			})

func _process(delta: float) -> void:
	if not hud.visible or not player:
		return
		
	# 1. Update speedometer (pixels/sec to MPH estimate)
	var mph = int(player.velocity.length() * 0.15)
	speed_label.text = "%d MPH" % mph
	
	# 2. Update heat bar based on active chases
	var active_chase_count = 0
	var police_nodes = get_tree().get_nodes_in_group("police")
	for node in police_nodes:
		if node is PoliceCruiser and node.current_state == PoliceCruiser.AIState.CHASE:
			active_chase_count += 1
			
	var target_heat = active_chase_count * 33.3
	heat_bar.value = move_toward(heat_bar.value, target_heat, 25.0 * delta)
	
	# Update status label
	if player.is_in_safehouse():
		status_label.text = "STATUS: HIDDEN"
		status_label.add_theme_color_override("font_color", Color(0.1, 0.9, 0.85))
	elif active_chase_count > 0:
		status_label.text = "STATUS: WANTED (%d COPS)" % active_chase_count
		status_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.2))
	else:
		status_label.text = "STATUS: SEARCHING"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.1))
		
	# 3. Update off-ramp radar helper arrow
	var player_pos = player.global_position
	var to_ramp = OFF_RAMP_POS - player_pos
	arrow_indicator.rotation = to_ramp.angle()
	# Only show arrow if far from ramp
	arrow_indicator.visible = (to_ramp.length() > 600.0)

# Build a clean city grid navigation polygon
func _build_navigation_polygons() -> void:
	var nav_poly = NavigationPolygon.new()
	
	# Outer border boundary (drivable map size)
	var outer = PackedVector2Array([
		Vector2(100, 100),
		Vector2(5404, 100),
		Vector2(5404, 2972),
		Vector2(100, 2972)
	])
	nav_poly.add_outline(outer)
	
	# Add holes representing buildings/blocks so police route around them
	# Building block 1 (Top Left)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(300, 300), Vector2(1000, 300), Vector2(1000, 1300), Vector2(300, 1300)
	]))
	
	# Building block 2 (Top Mid)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(1400, 300), Vector2(2600, 300), Vector2(2600, 1300), Vector2(1400, 1300)
	]))
	
	# Building block 3 (Top Right)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(3000, 300), Vector2(4200, 300), Vector2(4200, 1300), Vector2(3000, 1300)
	]))
	
	# Building block 4 (Bottom Left)
	# Leave slot for the garage outside starting zone (600, 2600)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(1100, 1700), Vector2(2200, 1700), Vector2(2200, 2700), Vector2(1100, 2700)
	]))
	
	# Building block 5 (Bottom Mid)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(2600, 1700), Vector2(3600, 1700), Vector2(3600, 2700), Vector2(2600, 2700)
	]))
	
	# Building block 6 (Bottom Right)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(4000, 1700), Vector2(5100, 1700), Vector2(5100, 2700), Vector2(4000, 2700)
	]))
	
	nav_poly.make_polygons_from_outlines()
	navigation_region.navigation_polygon = nav_poly

func start_getaway() -> void:
	hud.visible = true
	win_ui.visible = false
	
	# Initialize player
	player.global_position = PLAYER_SPAWN_POS
	player.rotation = -PI / 2.0 # Face upwards exiting garage lot
	player.current_speed = 0.0
	player.velocity = Vector2.ZERO
	player.set_hidden_in_safehouse(false)
	
	# Reset Camera limits
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 5504
	camera.limit_bottom = 3072
	
	# Reset all police
	for data in police_spawns:
		var p = data.node
		p.global_position = data.spawn_pos
		p.patrol_waypoints = data.waypoints.duplicate()
		p._switch_state(PoliceCruiser.AIState.PATROL)

func reset_getaway() -> void:
	start_getaway()

func show_hud_message(msg: String) -> void:
	status_label.text = msg
	# Flash red or green based on warning
	var col = Color(0.1, 0.9, 0.85) if "HIDDEN" in msg else Color(0.9, 0.8, 0.1)
	status_label.add_theme_color_override("font_color", col)

func _on_off_ramp_entered(body: Node2D) -> void:
	if body is PlayerCar:
		# Player escaped! Trigger game victory
		process_mode = PROCESS_MODE_DISABLED
		hud.visible = false
		win_ui.visible = true
		win_ui.get_node("Panel/VBoxContainer/RestartButton").grab_focus()

func _on_restart_pressed() -> void:
	# Restart the whole game from phase 0 (Garage puzzle)
	var director = get_tree().current_scene
	if director is Track4Director:
		director.has_wheelbarrow = false
		director.has_lever = false
		director.body_loaded = false
		director.car_running = false
		director.change_phase(Track4Director.GameplayPhase.GARAGE)

func _on_quit_pressed() -> void:
	get_tree().quit()
