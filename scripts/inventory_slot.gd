extends Panel

class_name InventorySlot

@export var slot_index: int = 0

var item_id: String = ""
var item_texture_path: String = ""

@onready var texture_rect: TextureRect = $TextureRect

# Map of item IDs to their sprite assets
const ITEM_ASSETS = {
	"tire": "res://Assets/Images/MJBD_Tire for inventory.png",
	"plank": "res://Assets/Images/MJBD__0003_plank-for-lever-puzzle.png",
	"wheelbarrow": "res://Assets/Images/MJBD_Wheelbarrow for inventory.png",
	"lever": "res://Assets/Images/MJBD_lever for putting dead body in wheelbarrow for inventory.png",
	"wheelbarrow_body": "res://Assets/Images/MJBD_wheelbarrow with body for inventory.png",
	"keys": "res://Assets/Images/MJBD_Keys for car for inventory.png"
}

func _ready() -> void:
	# Keep TextureRect centered and fitting slot boundaries
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	update_slot()

func set_item(new_id: String) -> void:
	item_id = new_id
	update_slot()

func update_slot() -> void:
	if item_id == "" or not ITEM_ASSETS.has(item_id):
		texture_rect.texture = null
		tooltip_text = "Empty Slot"
	else:
		texture_rect.texture = load(ITEM_ASSETS[item_id])
		tooltip_text = item_id.capitalize()

# Drag and Drop Implementation
func _get_drag_data(at_position: Vector2) -> Variant:
	if item_id == "":
		return null
		
	var drag_data = {
		"slot_index": slot_index,
		"item_id": item_id,
		"texture": texture_rect.texture
	}
	
	# Create drag preview
	var preview = TextureRect.new()
	preview.texture = texture_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(80, 80)
	preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(preview)
	
	return drag_data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("item_id") and data.has("slot_index")):
		return false
	
	var dragged_item = data.item_id
	
	# Prevent dropping onto itself
	if data.slot_index == slot_index:
		return false
		
	# Allow merging tire + plank (or vice versa) to make the lever
	if (dragged_item == "tire" and item_id == "plank") or (dragged_item == "plank" and item_id == "tire"):
		return true
		
	# Allow swapping items or placing in empty slot
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dragged_item = data.item_id
	var source_slot_index = data.slot_index
	
	var inventory_panel = get_parent().get_parent() # GridContainer -> InventoryPanel
	if not inventory_panel:
		return
		
	# Trigger Merging
	if (dragged_item == "tire" and item_id == "plank") or (dragged_item == "plank" and item_id == "tire"):
		# Merge into lever
		set_item("lever")
		inventory_panel.clear_slot(source_slot_index)
		
		# Update Director state
		var director = get_tree().current_scene
		if director is Track4Director:
			director.has_lever = true
			
		# Show narrative text
		var node = self
		var garage = null
		while node:
			if node is GarageScene:
				garage = node
				break
			node = node.get_parent()
		if garage:
			garage.show_dialogue("Jaggs: 'Perfect. Wedged the wooden plank inside the tire. That gives me a solid pivot. makeshift body lifting lever ready.'")
			
	else:
		# Swapping items
		var target_item = item_id
		set_item(dragged_item)
		inventory_panel.set_slot_item(source_slot_index, target_item)
