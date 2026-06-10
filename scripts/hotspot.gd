extends Area2D

class_name Hotspot

signal interacted(hotspot: Hotspot)

@export var item_id: String = ""
@export var display_name: String = ""
@export var interact_distance: float = 250.0

@onready var sprite: Sprite2D = $Sprite2D

var is_hovered: bool = false

func _ready() -> void:
	print("[Hotspot ", name, "] _ready() called. input_pickable before: ", input_pickable)
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	print("[Hotspot ", name, "] input_pickable after: ", input_pickable, " | layer: ", collision_layer)

func _get_garage_scene() -> GarageScene:
	var node = self
	while node:
		if node is GarageScene:
			return node
		node = node.get_parent()
	return null

func get_interaction_position() -> Vector2:
	if has_node("CollisionShape2D"):
		return get_node("CollisionShape2D").global_position
	elif sprite:
		return sprite.global_position
	return global_position

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Hotspot ", name, "] _input_event: ", event.as_text(), " | pressed: ", event.pressed)
	var is_click = event.is_action_pressed("click") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_click:
		print("[Hotspot ", name, "] Click registered. Sending player to: ", get_interaction_position())
		var garage = _get_garage_scene()
		if garage and garage.has_method("walk_to_hotspot"):
			garage.walk_to_hotspot(self)
			viewport.set_input_as_handled()

func _on_mouse_entered() -> void:
	print("[Hotspot ", name, "] Mouse entered.")
	is_hovered = true
	# Premium highlight outline glow effect
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.5, 1.0), 0.15)
	
	# Show hover tooltip on the garage UI
	var garage = _get_garage_scene()
	if garage and garage.has_node("CanvasLayer/HoverLabel"):
		garage.get_node("CanvasLayer/HoverLabel").text = display_name
		garage.get_node("CanvasLayer/HoverLabel").visible = true

func _on_mouse_exited() -> void:
	print("[Hotspot ", name, "] Mouse exited.")
	is_hovered = false
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
		
	var garage = _get_garage_scene()
	if garage and garage.has_node("CanvasLayer/HoverLabel"):
		if garage.get_node("CanvasLayer/HoverLabel").text == display_name:
			garage.get_node("CanvasLayer/HoverLabel").visible = false

# Triggered when player arrives at the hotspot
func trigger_interaction() -> void:
	print("[Hotspot ", name, "] trigger_interaction() called!")
	emit_signal("interacted", self)
