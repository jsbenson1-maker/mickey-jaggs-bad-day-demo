extends Area2D

class_name Hotspot

signal interacted(hotspot: Hotspot)

@export var item_id: String = ""
@export var display_name: String = ""
@export var interact_distance: float = 250.0

@onready var sprite: Sprite2D = $Sprite2D

var is_hovered: bool = false

func _ready() -> void:
	# Enable input pickable
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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
	var is_click = event.is_action_pressed("click") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_click:
		var garage = _get_garage_scene()
		if garage and garage.has_method("walk_to_hotspot"):
			garage.walk_to_hotspot(self)
			viewport.set_input_as_handled()

func _on_mouse_entered() -> void:
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
	emit_signal("interacted", self)
