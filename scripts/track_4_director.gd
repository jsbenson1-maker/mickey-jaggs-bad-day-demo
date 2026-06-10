extends Node2D

class_name Track4Director

enum GameplayPhase { GARAGE, HOTWIRE, GETAWAY }

# State flags for the point-and-click puzzle
var has_wheelbarrow: bool = false:
	set(val):
		has_wheelbarrow = val
		emit_signal("state_changed", "has_wheelbarrow", val)

var has_lever: bool = false:
	set(val):
		has_lever = val
		emit_signal("state_changed", "has_lever", val)

var body_loaded: bool = false:
	set(val):
		body_loaded = val
		emit_signal("state_changed", "body_loaded", val)

var car_running: bool = false:
	set(val):
		car_running = val
		emit_signal("state_changed", "car_running", val)

# Current active phase
var current_phase: GameplayPhase = GameplayPhase.GARAGE

signal phase_changed(new_phase: GameplayPhase)
signal state_changed(flag_name: String, value: bool)

@onready var garage_scene: Node2D = $GarageScene
@onready var city_scene: Node2D = $CityScene
@onready var transition_rect: ColorRect = $CanvasLayer/TransitionRect
@onready var retry_ui: Control = $CanvasLayer/RetryUI

func _ready() -> void:
	# Hide retry UI initially
	retry_ui.visible = false
	transition_rect.color = Color(0, 0, 0, 0)
	
	# Start in GARAGE phase
	change_phase(GameplayPhase.GARAGE)

# Transition between phases with a smooth fade-to-black effect
func change_phase(new_phase: GameplayPhase) -> void:
	current_phase = new_phase
	
	# Handle fade-to-black transition
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 0.3)
	tween.tween_callback(func(): _activate_phase_scenes(new_phase))
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), 0.3)
	
	emit_signal("phase_changed", new_phase)

func _activate_phase_scenes(phase: GameplayPhase) -> void:
	match phase:
		GameplayPhase.GARAGE:
			garage_scene.visible = true
			garage_scene.process_mode = PROCESS_MODE_INHERIT
			city_scene.visible = false
			city_scene.process_mode = PROCESS_MODE_DISABLED
			garage_scene.initialize_garage()
			
		GameplayPhase.HOTWIRE:
			garage_scene.visible = true
			garage_scene.process_mode = PROCESS_MODE_INHERIT
			city_scene.visible = false
			city_scene.process_mode = PROCESS_MODE_DISABLED
			garage_scene.open_hotwire_minigame()
			
		GameplayPhase.GETAWAY:
			garage_scene.visible = false
			garage_scene.process_mode = PROCESS_MODE_DISABLED
			city_scene.visible = true
			city_scene.process_mode = PROCESS_MODE_INHERIT
			city_scene.start_getaway()

# Triggers when player successfully hotwires the getaway car
func on_hotwire_success() -> void:
	car_running = true
	change_phase(GameplayPhase.GETAWAY)

# Triggers when police capture the player car
func trigger_game_over() -> void:
	# Pause the getaway gameplay but keep it visible
	city_scene.process_mode = PROCESS_MODE_DISABLED
	retry_ui.visible = true
	# Put focus on the retry button
	retry_ui.get_node("Panel/VBoxContainer/HBoxContainer/RetryButton").grab_focus()

func _on_retry_confirmed() -> void:
	retry_ui.visible = false
	# Reset getaway scene to starting parameters (outside the garage lot)
	city_scene.process_mode = PROCESS_MODE_INHERIT
	city_scene.reset_getaway()

func _on_quit_pressed() -> void:
	get_tree().quit()

# Fast fade transition for retro point-and-click style events (e.g. opening the trunk)
func play_fast_fade(callback: Callable) -> void:
	var tween = create_tween()
	# Fast fade out (0.15s)
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 0.15)
	# Trigger the event
	tween.tween_callback(callback)
	# Fast fade in (0.15s)
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), 0.15)
