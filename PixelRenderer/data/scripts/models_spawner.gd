extends Node3D

# UI References
@onready var load_scene_button: Button = %LoadSceneButton
@onready var load_scene_path: Label = %LoadScenePath

@onready var animation_selector: OptionButton = %AnimationSelector
@onready var anim_play_button: Button = %AnimPlayButton
@onready var anim_pause_button: Button = %AnimPauseButton
@onready var anim_stop_button: Button = %AnimStopButton
@onready var anim_loop_toggle_button: Button = %AnimLoopToggleButton
@onready var anim_slider: HSlider = %AnimSlider

@onready var temp_model: Node3D = %TempModel

@onready var start_spin: SpinBox = %StartSpin
@onready var end_spin: SpinBox = %EndSpin

# Console reference for logging
@onready var console: TextEdit = %Console


# File dialog for loading models
var file_dialog: FileDialog

# Currently loaded model
var loaded_model: Node3D = null
var current_model_path: String = ""

# Animation management
var current_animation_player: AnimationPlayer = null
var is_loop_enabled: bool = false
var is_slider_being_dragged: bool = false

# Frame-based animation control
var animation_fps: float = 30.0  # Default FPS, will be updated from animation
var start_frame: int = 0
var end_frame: int = 0
var total_frames: int = 0

# Visual feedback colors
var play_active_color: Color = Color(0.6, 0.8, 0.6)  # Muted green
var loop_active_color: Color = Color(0.6, 0.7, 0.9)  # Muted blue
var button_normal_color: Color = Color(1.0, 1.0, 1.0)  # Normal color

# Auto-refresh management
var auto_refresh_timer: Timer
var last_animation_count: int = 0
var last_model_node_count: int = 0

# Reference to pixel_material for color sampling
var pixel_material_script: Node

func _ready():
	# Initialize file dialog
	_setup_file_dialog()
	
	# Connect the load button
	load_scene_button.pressed.connect(_on_load_button_pressed)
	
	# Connect animation controls
	_setup_animation_controls()
	
	# Set temp model as the initial loaded model
	loaded_model = temp_model
	
	# Update the path label and find animation player
	_update_path_label()
	_setup_animation_player()
	
	# Setup auto-refresh timer
	_setup_auto_refresh()
	
	# Get reference to pixel_material script for color sampling
	_find_pixel_material_reference()

func _update_console(message: String):
	# Update the console TextEdit with the message
	if console:
		console.text += message + "\n"
		# Scroll to the bottom to show the latest message
		console.scroll_vertical = console.get_line_count()
	else:
		# Fallback to print if console is not available
		print(message)

func _setup_auto_refresh():
	# Create auto-refresh timer to periodically check for animation changes
	auto_refresh_timer = Timer.new()
	auto_refresh_timer.wait_time = 1.0  # Check every second
	auto_refresh_timer.timeout.connect(_on_auto_refresh_timer_timeout)
	add_child(auto_refresh_timer)
	auto_refresh_timer.start()
	
	_update_console("Auto-refresh timer initialized - checking for animation changes every second")

func _on_auto_refresh_timer_timeout():
	# Check if the model structure or animations have changed
	if loaded_model == null:
		return
	
	# Count current nodes in the model (to detect model changes)
	var current_node_count = _count_nodes_recursive(loaded_model)
	
	# Count current animations
	var current_anim_count = 0
	if current_animation_player != null:
		var library = current_animation_player.get_animation_library("")
		if library != null:
			current_anim_count = library.get_animation_list().size()
	
	# Check if we need to refresh
	var needs_refresh = false
	
	# Check if model structure changed
	if current_node_count != last_model_node_count:
		_update_console("Model structure changed - triggering refresh")
		needs_refresh = true
		last_model_node_count = current_node_count
	
	# Check if animation count changed
	if current_anim_count != last_animation_count:
		_update_console("Animation count changed from " + str(last_animation_count) + " to " + str(current_anim_count) + " - triggering refresh")
		needs_refresh = true
		last_animation_count = current_anim_count
	
	# Check if AnimationPlayer was lost/found
	var found_player = _find_animation_player(loaded_model)
	if (found_player == null) != (current_animation_player == null):
		_update_console("AnimationPlayer availability changed - triggering refresh")
		needs_refresh = true
	
	if needs_refresh:
		_refresh_animation_controls()

func _count_nodes_recursive(node: Node) -> int:
	var count = 1  # Count the current node
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

func _refresh_animation_controls():
	_update_console("Refreshing animation controls...")
	_setup_animation_player()

func _setup_animation_controls():
	# Connect animation control buttons
	anim_play_button.pressed.connect(_on_play_pressed)
	anim_pause_button.pressed.connect(_on_pause_pressed)
	anim_stop_button.pressed.connect(_on_stop_pressed)
	anim_loop_toggle_button.pressed.connect(_on_loop_toggle_pressed)
	
	# Connect animation selector
	animation_selector.item_selected.connect(_on_animation_selected)
	
	# Connect animation slider
	anim_slider.drag_started.connect(_on_slider_drag_started)
	anim_slider.drag_ended.connect(_on_slider_drag_ended)
	anim_slider.value_changed.connect(_on_slider_value_changed)
	
	# Connect frame spinboxes
	start_spin.value_changed.connect(_on_start_frame_changed)
	end_spin.value_changed.connect(_on_end_frame_changed)
	
	# Set initial loop button state
	_update_loop_button_visual()
	_update_play_button_visual()

func _process(_delta):
	# Update slider position during playback (if not being dragged)
	if current_animation_player != null and not is_slider_being_dragged:
		if current_animation_player.is_playing() and current_animation_player.current_animation != "":
			# Check if animation exists before getting position
			var library = current_animation_player.get_animation_library("")
			if library != null and library.has_animation(current_animation_player.current_animation):
				var current_position = current_animation_player.current_animation_position
				var trimmed_duration = _get_trimmed_duration()
				var trimmed_start_time = start_frame / animation_fps
				var trimmed_end_time = end_frame / animation_fps
				
				# Check if we've reached the end frame and should stop/loop
				if current_position >= trimmed_end_time:
					if is_loop_enabled:
						# Loop back to start frame
						current_animation_player.seek(trimmed_start_time)
					else:
						# Stop at end frame
						current_animation_player.stop()
						anim_slider.value = 100.0
						_update_play_button_visual()
						return
				
				# Calculate relative position within trimmed range
				var relative_position = current_position - trimmed_start_time
				if trimmed_duration > 0 and relative_position >= 0:
					anim_slider.value = (relative_position / trimmed_duration) * 100.0
	
	# Update button visuals
	_update_play_button_visual()

func _setup_file_dialog():
	# Create file dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Set file filters for GLB and GLTF files
	file_dialog.add_filter("*.glb", "GLB Files")
	file_dialog.add_filter("*.gltf", "GLTF Files")
	
	# Connect the file selected signal
	file_dialog.file_selected.connect(_on_file_selected)
	
	# Add to scene tree
	add_child(file_dialog)

func _on_load_button_pressed():
	# Open the file dialog
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String):
	# Load the selected GLB/GLTF file
	_load_model(path)

func _load_model(path: String):
	# Load the GLB/GLTF file
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	
	# Load the file
	var error = gltf.append_from_file(path, state)
	
	if error != OK:
		_update_console("Failed to load model: " + path)
		load_scene_path.text = "Failed to load: " + path.get_file()
		return
	
	# Generate the scene
	var scene = gltf.generate_scene(state)
	
	
	if scene == null:
		_update_console("Failed to generate scene from: " + path)
		load_scene_path.text = "Failed to generate scene: " + path.get_file()
		return
	
	# Remove previously loaded model (including temp model) if exists
	if loaded_model != null:
		loaded_model.queue_free()
	
	# Add the loaded model as a child
	add_child(scene)
	loaded_model = scene
	current_model_path = path
	
	# Update the path label and setup animation player
	_update_path_label()
	_setup_animation_player()
	
	# Apply Normal Shader
	
	
	# Trigger color sampling when a model is loaded
	if pixel_material_script != null:
		# Wait a frame to ensure the model is fully rendered before sampling
		await get_tree().process_frame
		await get_tree().process_frame
		pixel_material_script.sample_colors_from_render()
	
	# Reapply the current view mode to the newly loaded model
	_reapply_current_view_mode()
	
	_update_console("Successfully loaded model: " + path)

func _reapply_current_view_mode():
	# Get the main PixelRenderer node to access the current view mode
	var pixel_renderer = get_parent()  # Assuming this node is a direct child of PixelRenderer
	
	if pixel_renderer and pixel_renderer.has_node("ViewMaterials") and pixel_renderer.has_node("ViewModeDropDown"):
		var view_materials = pixel_renderer.get_node("ViewMaterials")
		var view_mode_dropdown = pixel_renderer.get_node("ViewModeDropDown")
		
		if view_materials and view_mode_dropdown:
			# Get the currently selected view mode index
			var current_index = view_mode_dropdown.selected
			if current_index >= 0:
				var current_mode = view_mode_dropdown.get_item_text(current_index)
				
				# For Toon mode, we need to wait a frame to ensure the new model is fully loaded
				# before attempting to reapply the material with proper texture extraction
				if current_mode == "Toon":
					# Wait a frame to allow the new model to be fully initialized
					await get_tree().process_frame
					await get_tree().process_frame  # Wait an additional frame for safety
					
					# Reapply the current view mode to the new model
					view_materials.item_selected(current_index)
					_update_console("Reapplied Toon view mode after model load (with delay for proper initialization)")
				else:
					# For other modes, apply immediately
					view_materials.item_selected(current_index)
					_update_console("Reapplied current view mode (" + view_mode_dropdown.get_item_text(current_index) + ") after model load")
		else:
			_update_console("WARNING: Could not find ViewMaterials or ViewModeDropDown nodes to reapply view mode")
	else:
		_update_console("WARNING: Could not access PixelRenderer components to reapply view mode")

func _setup_animation_player():
	# Find AnimationPlayer in the loaded model
	current_animation_player = _find_animation_player(loaded_model)
	
	if current_animation_player != null:
		var library = current_animation_player.get_animation_library("")
		var anim_count = library.get_animation_list().size() if library != null else 0
		_update_console("Found AnimationPlayer with " + str(anim_count) + " animations")
		
		_populate_animation_selector()
		_enable_animation_controls(true)
		
		# Connect to animation finished signal for loop handling
		if not current_animation_player.animation_finished.is_connected(_on_animation_finished):
			current_animation_player.animation_finished.connect(_on_animation_finished)
		
		# Update tracking variables
		last_animation_count = anim_count
	else:
		_update_console("No AnimationPlayer found in loaded model")
		_enable_animation_controls(false)
		_clear_animation_selector()
		last_animation_count = 0
	
	# Update model node count for change detection
	if loaded_model != null:
		last_model_node_count = _count_nodes_recursive(loaded_model)

func _find_animation_player(node: Node) -> AnimationPlayer:
	# Check if current node is an AnimationPlayer
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	# Recursively search children
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result != null:
			return result
	
	return null

func _populate_animation_selector():
	# Clear existing items
	animation_selector.clear()
	
	if current_animation_player == null:
		return
	
	# Get animation library (assuming default library "")
	var library = current_animation_player.get_animation_library("")
	if library == null:
		return
	
	# Add animations to selector
	var animation_names = library.get_animation_list()
	for anim_name in animation_names:
		animation_selector.add_item(anim_name)
	
	# Select first animation if available
	if animation_names.size() > 0:
		animation_selector.selected = 0
		var first_anim = animation_names[0]
		current_animation_player.current_animation = first_anim
		_setup_frame_controls()
		_update_slider_range()

func _clear_animation_selector():
	animation_selector.clear()
	animation_selector.add_item("No animations")

func _enable_animation_controls(enabled: bool):
	animation_selector.disabled = not enabled
	anim_play_button.disabled = not enabled
	anim_pause_button.disabled = not enabled
	anim_stop_button.disabled = not enabled
	anim_loop_toggle_button.disabled = not enabled
	anim_slider.editable = enabled

func _update_slider_range():
	if current_animation_player == null:
		anim_slider.value = 0
		return
	
	# Slider represents percentage (0-100)
	anim_slider.min_value = 0.0
	anim_slider.max_value = 100.0
	anim_slider.step = 0.1
	anim_slider.value = 0.0

func _update_loop_button_visual():
	# Update button appearance based on loop state
	if is_loop_enabled:
		anim_loop_toggle_button.button_pressed = true
		anim_loop_toggle_button.modulate = loop_active_color  # Muted blue when active
	else:
		anim_loop_toggle_button.button_pressed = false
		anim_loop_toggle_button.modulate = button_normal_color  # Normal color

# Animation Control Callbacks (removed - using new implementations below)

func _on_loop_toggle_pressed():
	is_loop_enabled = not is_loop_enabled
	_update_loop_button_visual()
	_update_console("Loop toggled: " + str(is_loop_enabled))

func _on_animation_selected(index: int):
	if current_animation_player == null:
		return
	
	var library = current_animation_player.get_animation_library("")
	var animation_names = library.get_animation_list()
	
	if index >= 0 and index < animation_names.size():
		var anim_name = animation_names[index]
		current_animation_player.current_animation = anim_name
		_setup_frame_controls()
		_update_slider_range()
		_update_console("Selected animation: " + anim_name)

func _on_slider_drag_started():
	is_slider_being_dragged = true

func _on_slider_drag_ended(_value_changed: bool):
	is_slider_being_dragged = false

func _on_slider_value_changed(value: float):
	if current_animation_player == null:
		return
	
	# Always respond to slider changes, whether dragging or not
	# Convert percentage to frame position within trimmed range
	var trimmed_duration = _get_trimmed_duration()
	var target_relative_time = (value / 100.0) * trimmed_duration
	var trimmed_start_time = start_frame / animation_fps
	var target_position = trimmed_start_time + target_relative_time
	
	# Seek to the position
	current_animation_player.seek(target_position)
	
	if is_slider_being_dragged:
		_update_console("Seeked to frame: " + str(int((target_position * animation_fps))) + " (position: " + str(target_position) + " seconds)")

func _on_animation_finished(anim_name: String):
	_update_console("Animation finished: " + anim_name)
	
	# Handle looping
	if is_loop_enabled and current_animation_player != null:
		current_animation_player.play(anim_name)
		_update_console("Looping animation: " + anim_name)
	else:
		# Reset slider to beginning
		anim_slider.value = 0.0


# Frame-based animation control functions
func _setup_frame_controls():
	if current_animation_player == null:
		return
	
	var animation_length = current_animation_player.current_animation_length
	total_frames = int(animation_length * animation_fps)
	
	# Set spinbox ranges
	start_spin.min_value = 0
	start_spin.max_value = total_frames - 1
	start_spin.value = 0
	start_spin.step = 1
	
	end_spin.min_value = 1
	end_spin.max_value = total_frames
	end_spin.value = total_frames
	end_spin.step = 1
	
	# Update internal values
	start_frame = 0
	end_frame = total_frames
	
	_update_console("Setup frame controls - Total frames: " + str(total_frames) + " at " + str(animation_fps) + " FPS")

func _get_trimmed_duration() -> float:
	return (end_frame - start_frame) / animation_fps

func _on_start_frame_changed(value: float):
	start_frame = int(value)
	
	# Ensure start frame is not greater than or equal to end frame
	if start_frame >= end_frame:
		end_frame = start_frame + 1
		end_spin.value = end_frame
	
	# Update end spin minimum to be at least start + 1
	end_spin.min_value = start_frame + 1
	
	_update_console("Start frame changed to: " + str(start_frame))
	_update_slider_range()

func _on_end_frame_changed(value: float):
	end_frame = int(value)
	
	# Ensure end frame is greater than start frame
	if end_frame <= start_frame:
		start_frame = end_frame - 1
		start_spin.value = start_frame
	
	# Update start spin maximum to be at most end - 1
	start_spin.max_value = end_frame - 1
	
	_update_console("End frame changed to: " + str(end_frame))
	_update_slider_range()

func _update_play_button_visual():
	# Update play button appearance based on playing state
	if current_animation_player != null and current_animation_player.is_playing():
		anim_play_button.modulate = play_active_color  # Muted green when playing
	else:
		anim_play_button.modulate = button_normal_color  # Normal color

# Override existing play function to include visual feedback
func _on_play_pressed():
	if current_animation_player == null:
		return
	
	var selected_index = animation_selector.selected
	if selected_index >= 0:
		var library = current_animation_player.get_animation_library("")
		var animation_names = library.get_animation_list()
		if selected_index < animation_names.size():
			var anim_name = animation_names[selected_index]
			
			# Start from the trimmed start position
			var start_time = start_frame / animation_fps
			current_animation_player.play(anim_name)
			current_animation_player.seek(start_time)
			
			_update_play_button_visual()
			_update_console("Playing animation: " + anim_name + " from frame " + str(start_frame))

# Override existing pause function to include visual feedback  
func _on_pause_pressed():
	if current_animation_player == null:
		return
	
	if current_animation_player.is_playing():
		current_animation_player.pause()
		_update_console("Animation paused")
	else:
		# Resume if paused
		current_animation_player.play()
		_update_console("Animation resumed")
	
	_update_play_button_visual()

# Override existing stop function to include visual feedback
func _on_stop_pressed():
	if current_animation_player == null:
		return
	
	current_animation_player.stop()
	anim_slider.value = 0.0
	_update_play_button_visual()
	_update_console("Animation stopped")


func _update_path_label():
	if current_model_path == "":
		load_scene_path.text = "No model loaded"
	else:
		# Show just the filename for cleaner display
		load_scene_path.text = current_model_path.get_file()

# Public function to get the currently loaded model
func get_loaded_model() -> Node3D:
	return loaded_model

# Public function to get the current model path
func get_current_model_path() -> String:
	return current_model_path

# Public function to clear the loaded model
func clear_loaded_model():
	if loaded_model != null:
		loaded_model.queue_free()
		loaded_model = null
		current_model_path = ""
		_update_path_label()
		_update_console("Loaded model cleared") 

func _find_pixel_material_reference():
	# Find the PixelMaterial script node - it's a direct child of the root PixelRenderer node
	var root_node = get_node("../../")  # Go up to the PixelRenderer root
	pixel_material_script = root_node.get_node_or_null("PixelMaterial")
	if pixel_material_script != null:
		_update_console("Found PixelMaterial script reference")
	else:
		_update_console("WARNING: PixelMaterial script not found - color sampling will not work")
