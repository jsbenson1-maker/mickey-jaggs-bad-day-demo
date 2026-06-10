extends Control

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("item_id"):
		var item_id = data.item_id
		if item_id == "wheelbarrow_body" or item_id == "keys":
			return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item_id = data.item_id
	var source_slot_index = data.slot_index
	
	# Get the mouse position in global 2D world coordinates
	var mouse_pos = get_global_mouse_position()
	
	# Resolve GarageScene dynamically
	var node = self
	var garage = null
	while node:
		if node is GarageScene:
			garage = node
			break
		node = node.get_parent()
		
	if not garage:
		return
		
	# Check if the drop is over the getaway car hotspot
	var car_hotspot = garage.item_car
	if car_hotspot:
		# Query 2D physics point intersection
		var space_state = garage.get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = 1 # Hotspot car is on layer 1
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var results = space_state.intersect_point(query)
		
		var dropped_on_car = false
		for result in results:
			if result.collider == car_hotspot:
				dropped_on_car = true
				break
				
		if dropped_on_car:
			garage.handle_inventory_drop_on_car(item_id, source_slot_index)
		else:
			print("[DragDropOverlay] Item dropped but not over the car hotspot.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		visible = false
