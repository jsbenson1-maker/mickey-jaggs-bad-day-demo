extends Panel

class_name InventoryPanel

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	# Listen to state changes from the Director
	var director = get_tree().current_scene
	if director is Track4Director:
		director.state_changed.connect(_on_director_state_changed)

func add_item(item_id: String) -> bool:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.item_id == "":
			slot.set_item(item_id)
			return true
	return false

func has_item(item_id: String) -> bool:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.item_id == item_id:
			return true
	return false

func clear_slot(slot_index: int) -> void:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.slot_index == slot_index:
			slot.set_item("")
			return

func set_slot_item(slot_index: int, item_id: String) -> void:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.slot_index == slot_index:
			slot.set_item(item_id)
			return

func remove_item(item_id: String) -> void:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.item_id == item_id:
			slot.set_item("")
			return

func replace_item(old_id: String, new_id: String) -> void:
	for slot in grid_container.get_children():
		if slot is InventorySlot and slot.item_id == old_id:
			slot.set_item(new_id)
			return

func _on_director_state_changed(flag_name: String, value: bool) -> void:
	if flag_name == "body_loaded" and value:
		# Replace wheelbarrow with wheelbarrow_body
		if has_item("wheelbarrow"):
			replace_item("wheelbarrow", "wheelbarrow_body")
		else:
			add_item("wheelbarrow_body")
		
		# Add keys to the inventory
		add_item("keys")
		
		# Remove lever from inventory since it was used
		remove_item("lever")
