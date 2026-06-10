extends Node2D

class_name GarageScene

@onready var player: JaggsPlayer = $YSort/JaggsPlayer
@onready var inventory_panel: InventoryPanel = $CanvasLayer/InventoryPanel
@onready var dialogue_panel: Panel = $CanvasLayer/DialoguePanel
@onready var dialogue_label: Label = $CanvasLayer/DialoguePanel/DialogueLabel
@onready var hotwire_minigame: Control = $CanvasLayer/HotwireMinigame
@onready var background: Sprite2D = $Background

# YSort nodes for items
@onready var item_body: Hotspot = $YSort/Hotspot_Body
@onready var item_wheelbarrow: Hotspot = $YSort/Hotspot_Wheelbarrow
@onready var item_tire: Hotspot = $YSort/Hotspot_Tire
@onready var item_plank: Hotspot = $YSort/Hotspot_Plank
@onready var item_car: Hotspot = $YSort/Hotspot_Car

@onready var item_engine: Hotspot = $YSort/Hotspot_Engine

var current_target_hotspot: Hotspot = null
var dialogue_queue: Array[String] = []
var trunk_open: bool = false

func _ready() -> void:
	dialogue_panel.visible = false
	hotwire_minigame.visible = false
	
	# Connect to Dialogue continue click
	dialogue_panel.gui_input.connect(_on_dialogue_panel_input)
	
	# Connect hotspots
	item_body.interacted.connect(_on_hotspot_interact)
	item_wheelbarrow.interacted.connect(_on_hotspot_interact)
	item_tire.interacted.connect(_on_hotspot_interact)
	item_plank.interacted.connect(_on_hotspot_interact)
	item_car.interacted.connect(_on_hotspot_interact)
	item_engine.interacted.connect(_on_hotspot_interact)

func initialize_garage() -> void:
	var director = get_tree().current_scene
	if director is Track4Director:
		# Update background based on whether body is loaded
		if director.body_loaded:
			background.texture = load("res://Assets/Images/MJBD__0004_GARAGE_BGD_Trunk-Open.png")
			item_body.visible = false
			if has_node("Boundaries/ColBody"):
				$Boundaries/ColBody.disabled = true
		else:
			background.texture = load("res://Assets/Images/MJBD__0005_GARAGE_BGD_Trunk-closed.png")
			item_body.visible = true
			
		item_wheelbarrow.visible = not director.has_wheelbarrow
		item_tire.visible = not inventory_panel.has_item("tire") and not director.has_lever
		item_plank.visible = not inventory_panel.has_item("plank") and not director.has_lever
		
		# Hook starting narrative dialogue automatically
		if not director.has_wheelbarrow and not director.body_loaded and not director.has_lever:
			show_dialogue("Jaggs: 'Alright, we need to load this fat bastard's body into the wheelbarrow, lift him in, unlock that trunk, and get the hell out of here before the cops sniff us out.'")
			show_dialogue("Jaggs: 'First, I need to find a wheelbarrow and construct some kind of lever to lift him. My back can't take this weight anymore.'")

func _process(delta: float) -> void:
	# Camera smooth follow with window bounding to avoid showing void space
	if has_node("Camera2D") and player:
		var cam = $Camera2D
		var target_pos = player.global_position
		
		# With 0.24 zoom and 1280x720 viewport, half width is 2666.6, half height is 1500
		var min_x = 2666.6
		var max_x = 5504.0 - 2666.6
		var min_y = 1500.0
		var max_y = 3072.0 - 1500.0
		
		target_pos.x = clamp(target_pos.x, min_x, max_x)
		target_pos.y = clamp(target_pos.y, min_y, max_y)
		
		cam.global_position = cam.global_position.lerp(target_pos, 4.0 * delta)

	# Check if player has arrived at the target hotspot
	if current_target_hotspot:
		var dist = player.global_position.distance_to(current_target_hotspot.get_interaction_position())
		print("[GarageScene] Current target hotspot: ", current_target_hotspot.name, " | Dist: ", dist, " | Required: ", current_target_hotspot.interact_distance)
		if dist <= current_target_hotspot.interact_distance:
			print("[GarageScene] Target reached! Triggering interaction for: ", current_target_hotspot.name)
			# Arrived! Stop moving and interact
			player.is_moving = false
			player.velocity = Vector2.ZERO
			current_target_hotspot.trigger_interaction()
			current_target_hotspot = null

# Input handler for clicking the ground to move Jaggs
func _unhandled_input(event: InputEvent) -> void:
	var is_click = event.is_action_pressed("click") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_click:
		if dialogue_panel.visible:
			_show_next_dialogue()
			get_viewport().set_input_as_handled()
			return
		if hotwire_minigame.visible:
			return # Block input while UI is active
			
		var click_pos = get_global_mouse_position()
		print("Ground clicked at: ", click_pos)
		
		# Prevent walking outside logical boundaries
		click_pos.y = clamp(click_pos.y, 1950.0, 2850.0)
		click_pos.x = clamp(click_pos.x, 500.0, 5000.0)
		
		player.set_move_target(click_pos)
		current_target_hotspot = null # Cancel previous hotspot target
		get_viewport().set_input_as_handled()

func walk_to_hotspot(hotspot: Hotspot) -> void:
	if dialogue_panel.visible or hotwire_minigame.visible:
		return
	print("[GarageScene] walk_to_hotspot called for: ", hotspot.name, " | Target pos: ", hotspot.get_interaction_position())
	current_target_hotspot = hotspot
	player.set_move_target(hotspot.get_interaction_position())

func show_dialogue(text: String) -> void:
	dialogue_queue.append(text)
	if not dialogue_panel.visible:
		_show_next_dialogue()

func _show_next_dialogue() -> void:
	if dialogue_queue.is_empty():
		dialogue_panel.visible = false
		return
	
	dialogue_label.text = dialogue_queue.pop_front()
	dialogue_panel.visible = true

func _on_dialogue_panel_input(event: InputEvent) -> void:
	var is_click = event.is_action_pressed("click") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_click:
		_show_next_dialogue()

func _on_hotspot_interact(hotspot: Hotspot) -> void:
	var director = get_tree().current_scene
	if not (director is Track4Director):
		return

	match hotspot.item_id:
		"tire":
			if inventory_panel.add_item("tire"):
				hotspot.visible = false
				show_dialogue("Jaggs: 'A heavy rubber tire. I can use this as a pivot... now I just need a long wooden plank to make a lever.'")
		"plank":
			if inventory_panel.add_item("plank"):
				hotspot.visible = false
				show_dialogue("Jaggs: 'A sturdy wooden plank. Perfect for leverage... if I can find a solid pivot, like an old tire, I can lift that body.'")
		"wheelbarrow":
			director.has_wheelbarrow = true
			if inventory_panel.add_item("wheelbarrow"):
				hotspot.visible = false
				show_dialogue("Jaggs: 'An empty wheelbarrow. It will carry the body... if I can get him into it.'")
		"body":
			if not director.body_loaded:
				if not director.has_wheelbarrow:
					show_dialogue("Jaggs: 'Too heavy. Even with leverage, I can't drag him out of here on foot. I need a wheelbarrow first.'")
				elif not director.has_lever:
					show_dialogue("Jaggs: 'Too heavy. The guy's like a sack of wet cement. Back is shot from years of this shit. I need some serious leverage.'")
				else:
					# Load the body!
					director.body_loaded = true
					hotspot.visible = false
					show_dialogue("Jaggs: 'Pushed the lever under his armpits, shifted the weight... hup! Loaded him right in. And what do we have here...?'")
					show_dialogue("Jaggs: 'jackpot! The car keys were deep in his jacket pocket. Let's get the trunk open and load him in.'")
		"car":
			if not inventory_panel.has_item("keys"):
				show_dialogue("Jaggs: 'The getaway sedan. It's locked. He's gotta have the keys for this motherfucker somewhere... probably on his body.'")
			else:
				if not trunk_open:
					# Fast fade transition
					director.play_fast_fade(func():
						background.texture = load("res://Assets/Images/MJBD__0004_GARAGE_BGD_Trunk-Open.png")
						trunk_open = true
					)
					show_dialogue("Jaggs: 'Trunk is open. Now let's dump this heavy bastard in.'")
				else:
					if director.body_loaded:
						# Body is in wheelbarrow, trunk is open! Show Choice UI
						$CanvasLayer/ChoicePanel.visible = true
						$CanvasLayer/ChoicePanel/VBoxContainer/HBoxContainer/YesButton.grab_focus()
					else:
						show_dialogue("Jaggs: 'Trunk is open, but I need to load his body in first.'")
		"engine":
			show_dialogue("Jaggs: 'mmm... lubed up holes... reminds me of that guy with a mashed banana stuck in a cylider... No time for jollys, gotta skip town!'")

func _on_choice_yes() -> void:
	$CanvasLayer/ChoicePanel.visible = false
	show_dialogue("Jaggs: 'those motherfuckers shoved some shit in the ignition... time to hotwire this bitch'")
	
	# Delay minigame trigger to let text display
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		var director = get_tree().current_scene
		if director is Track4Director:
			director.change_phase(Track4Director.GameplayPhase.HOTWIRE)
	)

func _on_choice_no() -> void:
	$CanvasLayer/ChoicePanel.visible = false
	show_dialogue("Jaggs: 'No time to waste. Gotta make sure I'm fully ready before getting in.'")

func open_hotwire_minigame() -> void:
	hotwire_minigame.visible = true
	hotwire_minigame.reset_minigame()

func _on_hotwire_minigame_success() -> void:
	hotwire_minigame.visible = false
	show_dialogue("Jaggs: 'There we go! She's purring like a direct-injected beast.'")
	
	# Let dialogue finish before changing phase
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		var director = get_tree().current_scene
		if director is Track4Director:
			director.on_hotwire_success()
	)
