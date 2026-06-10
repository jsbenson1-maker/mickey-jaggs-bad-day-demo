extends Control

class_name HotwireMinigame

signal minigame_success

enum Stage { CONNECTING, SPARKING }
var current_stage: Stage = Stage.CONNECTING

# Wire Drag State
var wires_left = {
	"red": Vector2(80, 100),
	"blue": Vector2(80, 200),
	"yellow": Vector2(80, 300)
}
var wires_right = {
	"red": Vector2(420, 200),     # Jumbled order
	"blue": Vector2(420, 300),
	"yellow": Vector2(420, 100)
}

var connections = {
	"red": false,
	"blue": false,
	"yellow": false
}

var active_drag: String = ""
var current_mouse_pos: Vector2 = Vector2.ZERO

# Spark State
var slider_pos: float = 0.0
var slider_dir: float = 1.0
@export var slider_speed: float = 4.0
var target_min: float = 0.45
var target_max: float = 0.55
var successful_sparks: int = 0
const REQUIRED_SPARKS: int = 3

# UI Node References
@onready var panel: Panel = $CenterContainer/Panel
@onready var wire_stage_ui: Control = $CenterContainer/Panel/WireStageUI
@onready var spark_stage_ui: Control = $CenterContainer/Panel/SparkStageUI
@onready var slider_bar: ColorRect = $CenterContainer/Panel/SparkStageUI/SliderBg/SliderBar
@onready var spark_count_label: Label = $CenterContainer/Panel/SparkStageUI/SparkCountLabel
@onready var feedback_label: Label = $CenterContainer/Panel/FeedbackLabel
@onready var spark_button: Button = $CenterContainer/Panel/SparkStageUI/SparkButton

func _ready() -> void:
	reset_minigame()
	# Connect spark button press
	spark_button.pressed.connect(_on_spark_button_pressed)

func reset_minigame() -> void:
	current_stage = Stage.CONNECTING
	connections = { "red": false, "blue": false, "yellow": false }
	active_drag = ""
	successful_sparks = 0
	slider_pos = 0.0
	
	wire_stage_ui.visible = true
	spark_stage_ui.visible = false
	feedback_label.text = "CONNECT IGNITION WIRES (DRAG MATCHING COLORS)"
	feedback_label.add_theme_color_override("font_color", Color(0.1, 0.8, 0.9))
	queue_redraw()

func _draw() -> void:
	if current_stage != Stage.CONNECTING:
		return
		
	# Draw already connected wires
	for color_key in connections:
		if connections[color_key]:
			var c = _get_wire_color(color_key)
			# Draw thick wire
			draw_line(wires_left[color_key], wires_right[color_key], c, 6.0, true)
			
	# Draw currently dragging wire
	if active_drag != "":
		var c = _get_wire_color(active_drag)
		draw_line(wires_left[active_drag], current_mouse_pos, c, 6.0, true)

func _get_wire_color(wire_type: String) -> Color:
	match wire_type:
		"red": return Color(0.9, 0.15, 0.15)
		"blue": return Color(0.15, 0.3, 0.9)
		"yellow": return Color(0.9, 0.8, 0.1)
	return Color.WHITE

func _process(delta: float) -> void:
	if current_stage == Stage.SPARKING:
		# Move the slider back and forth
		slider_pos += slider_dir * slider_speed * delta
		if slider_pos >= 1.0:
			slider_pos = 1.0
			slider_dir = -1.0
		elif slider_pos <= 0.0:
			slider_pos = 0.0
			slider_dir = 1.0
			
		# Position visual slider bar (Width of Bg is 300)
		var bg_width = 300.0
		var bar_width = 15.0
		slider_bar.position.x = slider_pos * (bg_width - bar_width)

func _gui_input(event: InputEvent) -> void:
	if current_stage != Stage.CONNECTING:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicked near a left terminal
				var local_click = event.position - panel.position - wire_stage_ui.position
				for color_key in wires_left:
					if not connections[color_key]:
						if local_click.distance_to(wires_left[color_key]) < 25.0:
							active_drag = color_key
							current_mouse_pos = local_click
							queue_redraw()
							break
			else:
				# Released mouse. Check if close to correct right terminal
				if active_drag != "":
					var local_release = event.position - panel.position - wire_stage_ui.position
					var target_pos = wires_right[active_drag]
					if local_release.distance_to(target_pos) < 30.0:
						connections[active_drag] = true
						_flash_feedback("Wire Connected!", Color(0.1, 0.9, 0.4))
						_check_wires_completed()
					else:
						_flash_feedback("Mismatch! Connect to matching color", Color(0.9, 0.1, 0.2))
					active_drag = ""
					queue_redraw()
					
	elif event is InputEventMouseMotion:
		if active_drag != "":
			current_mouse_pos = event.position - panel.position - wire_stage_ui.position
			queue_redraw()

func _flash_feedback(msg: String, col: Color) -> void:
	feedback_label.text = msg
	feedback_label.add_theme_color_override("font_color", col)

func _check_wires_completed() -> void:
	for color_key in connections:
		if not connections[color_key]:
			return # Still missing some
			
	# All connected! Transition to stage 2
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(func():
		current_stage = Stage.SPARKING
		wire_stage_ui.visible = false
		spark_stage_ui.visible = true
		spark_count_label.text = "Ignition Sparks: 0 / %d" % REQUIRED_SPARKS
		_flash_feedback("TAP 'SPARK' WHEN BAR IS IN GREEN ZONE", Color(0.9, 0.8, 0.1))
	)

func _on_spark_button_pressed() -> void:
	if current_stage != Stage.SPARKING:
		return
		
	# Check if inside sweet spot (0.45 to 0.55)
	if slider_pos >= target_min and slider_pos <= target_max:
		successful_sparks += 1
		spark_count_label.text = "Ignition Sparks: %d / %d" % [successful_sparks, REQUIRED_SPARKS]
		
		# Screen shake effect
		_screen_shake()
		
		if successful_sparks >= REQUIRED_SPARKS:
			_flash_feedback("ENGINE STARTED!", Color(0.1, 0.9, 0.4))
			spark_button.disabled = true
			
			# Delay success signal to let feedback play
			var timer = get_tree().create_timer(1.0)
			timer.timeout.connect(func():
				emit_signal("minigame_success")
			)
		else:
			_flash_feedback("SPARK! (+1)", Color(0.1, 0.9, 0.4))
			# Increase speed slightly to increase challenge
			slider_speed += 1.0
	else:
		# Electric shock reset
		successful_sparks = 0
		slider_speed = 4.0
		spark_count_label.text = "Ignition Sparks: 0 / %d" % REQUIRED_SPARKS
		_flash_feedback("MISFIRE! Connections grounded.", Color(0.9, 0.1, 0.1))
		
		# Flash screen red briefly
		var parent = get_parent()
		if parent:
			var flash = ColorRect.new()
			flash.color = Color(1.0, 0.1, 0.1, 0.35)
			flash.anchors_preset = PRESET_FULL_RECT
			parent.add_child(flash)
			var timer = get_tree().create_timer(0.15)
			timer.timeout.connect(func(): flash.queue_free())

func _screen_shake() -> void:
	# Access player camera if available and shake it
	var garage = get_tree().current_scene.get_node_or_null("GarageScene")
	if garage:
		var cam = garage.get_node_or_null("YSort/JaggsPlayer/Camera2D")
		if cam:
			var orig_offset = cam.offset
			var tween = create_tween()
			for i in range(6):
				var shake_offset = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
				tween.tween_property(cam, "offset", shake_offset, 0.04)
			tween.tween_property(cam, "offset", orig_offset, 0.04)
