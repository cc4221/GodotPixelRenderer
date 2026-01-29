extends Node3D


@onready var export_dir_path: Label = %ExportDirPath
@onready var select_folder_button: Button = %SelectFolderButton
@onready var export_button: Button = %ExportButton

@onready var file_dialog: FileDialog = %FileDialog
@onready var texture_rect: TextureRect = %PixelCanvas
@onready var close_button: TextureRect = %Close
var original_close_texture: Texture2D

@onready var fps_spin_box: SpinBox = %FpsSpin

@onready var renderer: PanelContainer = %Renderer
@onready var models_spawner: Node3D = %ModelsSpawner

@onready var prefix_text: LineEdit = %PrefixText

@onready var sub_viewport: SubViewport = $SubViewport

@onready var bg_color_rect: ColorRect = %BgColorRect
@onready var bg_color_check_box: CheckButton = %BgColorCheckBox
@onready var bg_color_picker: ColorPickerButton = %BgColorPicker
@onready var progress_bar: ProgressBar = %ProgressBar

@export var start_frame: int = 0
@export var end_frame: int = 30
@export var fps: int = 12


@onready var resolution: SpinBox = %Resolution
@onready var preview_image_check_box: CheckButton = %PreviewImageCheckBox
@onready var view_mode_dropdown : OptionButton = %ViewModeDropDown
@onready var canvas_size_label: Label = %CanvasSizeLabel
@onready var pixel_material_script: Node = $PixelMaterial

# Toon Material Parameter Controls
@onready var cuts_size_spin: SpinBox = %CutsSizeSpin
@onready var albedo_toon_color: ColorPickerButton = %AlbedoToonColor
@onready var wrap_slider: HSlider = %WrapSlider
@onready var steepness_slider: HSlider = %SteepnessSlider
@onready var rim_check_box: CheckButton = %RimCheckBox
@onready var rim_width_slider: HSlider = %RimWidthSlider
@onready var albedo_rim_color: ColorPickerButton = %AlbedoRimColor
@onready var borders_size_spin: SpinBox = %BordersSizeSpin
@onready var albedo_borders_color: ColorPickerButton = %AlbedoBordersColor
@onready var specular_check_box: CheckButton = %SpecularCheckBox
@onready var spec_shininess_slider: HSlider = %SpecShininessSlider
@onready var strength_slider: HSlider = %StrengthSlider
@onready var ramp_check_box: CheckButton = %RampCheckBox

@onready var console: TextEdit = %Console


var export_directory: String = ""
var is_exporting: bool = false
var current_export_frame: int = 0
var total_frames: int = 0

# Timer for canvas updates
var canvas_update_timer: Timer

# Cached texture for FPS-controlled display
var cached_texture: ImageTexture

# Base canvas size - always 800x800
const BASE_CANVAS_SIZE: int = 800

# Animation export variables
var animation_player: AnimationPlayer = null
var was_playing_before_export: bool = false
var original_animation_position: float = 0.0
var export_frame_list: Array = []
var export_frame_index: int = 0

func _ready():
	# Initialize console
	_update_progress("EffectBlocks PixelRenderer")
	_update_progress("Visit https://bukkbeek.itch.io/effectblocks")
	_update_progress("PixelRenderer initialized successfully")
	_update_progress("Canvas update timer set to " + str(fps) + " FPS")
	_update_progress("Base canvas size: " + str(BASE_CANVAS_SIZE) + "x" + str(BASE_CANVAS_SIZE))
	_update_progress("Default minion skeleton by KayKit: kaylousberg.itch.io/kaykit-skeletons")

	# Keep SubViewport updating continuously so models run at normal speed
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Initialize cached texture
	cached_texture = ImageTexture.new()
	
	# Create and configure the canvas update timer for visual feed updates
	canvas_update_timer = Timer.new()
	canvas_update_timer.wait_time = 1.0 / fps
	canvas_update_timer.timeout.connect(_update_canvas)
	add_child(canvas_update_timer)
	canvas_update_timer.start()
	
	# Connect signals
	export_button.pressed.connect(_on_export_button_pressed)
	select_folder_button.pressed.connect(_on_select_folder_button_pressed)
	fps_spin_box.value_changed.connect(_on_fps_changed)
	resolution.value_changed.connect(_on_resolution_changed)
	file_dialog.dir_selected.connect(_on_directory_selected)
	bg_color_check_box.toggled.connect(_on_bg_color_toggled)
	bg_color_picker.color_changed.connect(_on_bg_color_changed)
	close_button.gui_input.connect(_on_close_button_input)
	
	# Setup View Modes
	_setup_view_mode_dropdown()
	view_mode_dropdown.item_selected.connect(_view_mode_item_selected)
	
	# Connect to ViewMaterials signal for automatic color remap toggle
	get_node("ViewMaterials").technical_mode_selected.connect(_on_technical_mode_selected)
	
	# Store original close button texture and connect mouse enter/exit events
	original_close_texture = close_button.texture
	close_button.mouse_entered.connect(_on_close_button_mouse_entered)
	close_button.mouse_exited.connect(_on_close_button_mouse_exited)
	
	# Set up file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Initialize FPS spin box
	fps_spin_box.value = fps
	fps_spin_box.min_value = 1
	fps_spin_box.max_value = 120
	fps_spin_box.step = 1
	
	# Initialize resolution spin box
	resolution.value = 512
	resolution.min_value = 1
	resolution.step = 1
	
	# Initialize background color controls
	_update_bg_color_visibility()
	
	# Initialize export directory label
	_update_export_path_label()
	
	# Initialize canvas size label
	_update_canvas_size_label()
	
	# Initialize progress bar
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	
	# Initialize and connect Toon material parameter controls
	_initialize_toon_controls()
	
	

func _on_fps_changed(value: float):
	fps = int(value)
	# Update the canvas update timer instead of engine FPS
	canvas_update_timer.wait_time = 1.0 / fps
	canvas_update_timer.start()  # Restart the timer with new interval
	_update_progress("FPS changed to " + str(fps))

func _on_resolution_changed(value: float):
	_update_canvas_size_label()
	_update_progress("Export resolution changed to " + str(int(value)) + "x" + str(int(value)))

func _on_export_button_pressed():
	if is_exporting:
		return
	
	if export_directory == "":
		_update_progress("No export directory selected, opening folder dialog...")
		_on_select_folder_button_pressed()
		return
		
	# Start the export process
	_start_export()

func _on_select_folder_button_pressed():
	# Open file dialog to select export directory
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_directory_selected(dir: String):
	export_directory = dir
	_update_progress("Export directory set to: " + export_directory)
	
	# Update the label to show the selected path
	_update_export_path_label()

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

func _start_export():
	if export_directory == "":
		_update_progress("No export directory selected")
		return
		
	# Get frame range from models_spawner UI instead of hardcoded values
	var actual_start_frame = start_frame
	var actual_end_frame = end_frame
	
	if models_spawner:
		# Try to get the frame values from models_spawner directly (it has start_spin and end_spin as @onready vars)
		if models_spawner.has_method("get") and models_spawner.get("start_spin") != null and models_spawner.get("end_spin") != null:
			actual_start_frame = int(models_spawner.start_spin.value)
			actual_end_frame = int(models_spawner.end_spin.value)
			_update_progress("Using frame range from UI: " + str(actual_start_frame) + " to " + str(actual_end_frame))
		else:
			_update_progress("Could not access frame range UI controls, using default values")
	
	if actual_start_frame >= actual_end_frame:
		_update_progress("Invalid frame range: start_frame must be less than end_frame")
		return
	
	# Calculate frame skip based on FPS (baseline 30 FPS)
	var frame_skip = int(30.0 / float(fps))
	if frame_skip < 1:
		frame_skip = 1
	
	_update_progress("Export FPS: " + str(fps) + " (will render every " + str(frame_skip) + " frame(s) from 30 FPS baseline)")
	
	# Find the animation player in the loaded model
	if models_spawner:
		var loaded_model = models_spawner.get_loaded_model()
		if loaded_model:
			animation_player = _find_animation_player(loaded_model)
			if animation_player:
				_update_progress("Found AnimationPlayer - animation will play during export")
				# Store current state
				was_playing_before_export = animation_player.is_playing()
				original_animation_position = animation_player.current_animation_position
				
				# Ensure animation is playing
				if not animation_player.is_playing():
					animation_player.play()
					_update_progress("Started animation playback for export")
			else:
				_update_progress("No AnimationPlayer found - exporting static frames")
		else:
			_update_progress("No model loaded - exporting static frames")
	
	is_exporting = true
	current_export_frame = actual_start_frame
	start_frame = actual_start_frame  # Update the instance variables
	end_frame = actual_end_frame
	
	# Calculate total frames that will actually be exported (considering frame skipping)
	var frames_to_export = []
	for frame_num in range(start_frame, end_frame + 1):
		if (frame_num - start_frame) % frame_skip == 0:
			frames_to_export.append(frame_num)
	
	total_frames = frames_to_export.size()
	
	export_button.text = "Exporting..."
	export_button.disabled = true
	
	# Initialize progress bar
	progress_bar.value = 0
	
	_update_progress("Starting export from frame " + str(start_frame) + " to " + str(end_frame))
	_update_progress("Total frames to export: " + str(total_frames) + " at " + str(fps) + " FPS (skipping " + str(frame_skip - 1) + " frames between renders)")
	_update_progress("Frames to render: " + str(frames_to_export))
	
	# Store the frames list and start with the first frame
	export_frame_list = frames_to_export
	export_frame_index = 0
	
	# Start the export process
	_export_next_frame()

func _export_next_frame():
	if export_frame_index >= export_frame_list.size():
		_finish_export()
		return
	
	# Get the actual frame number to render
	var frame_to_render = export_frame_list[export_frame_index]
	
	# Update progress bar
	var progress_percent = float(export_frame_index) / float(total_frames) * 100.0
	progress_bar.value = progress_percent
	
	_update_progress("Processing frame " + str(frame_to_render) + " (" + str(export_frame_index + 1) + "/" + str(total_frames) + ")")
	
	# If we have an animation player, seek to the correct frame position
	if animation_player and animation_player.current_animation != "":
		# Animation timing always uses 30 FPS baseline
		var target_time = float(frame_to_render) / 30.0
		
		# Make sure we don't exceed animation length
		var animation_length = animation_player.current_animation_length
		if target_time > animation_length:
			target_time = animation_length
		
		# Seek to the exact frame position
		animation_player.seek(target_time)
		_update_progress("Animation seeked to time: " + str(target_time) + "s (frame " + str(frame_to_render) + " at 30 FPS baseline)")
	
	# Wait for multiple frames to ensure proper rendering and animation update
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Capture the entire Renderer control node and its contents
	var image = await _capture_control_node()
	
	if image:
		# Apply resolution scaling if not in preview mode
		if not preview_image_check_box.button_pressed:
			image = _scale_image_nearest_neighbor(image, int(resolution.value))
		
		# Get prefix from UI, default to "frame" if empty
		var prefix = prefix_text.text.strip_edges()
		if prefix.is_empty():
			prefix = "frame"
		
		# Use actual frame numbers for exported files (Blender style)
		var filename = "%s_%04d.png" % [prefix, frame_to_render]
		var filepath = export_directory.path_join(filename)
		
		_update_progress("Saving frame to: " + filepath)
		
		# Save the image
		var error = image.save_png(filepath)
		if error != OK:
			_update_progress("ERROR: Failed to save frame " + str(frame_to_render) + " - Error code: " + str(error))
		else:
			var size_info = ""
			if preview_image_check_box.button_pressed:
				size_info = " (preview size: " + str(image.get_width()) + "x" + str(image.get_height()) + ")"
			else:
				size_info = " (scaled to: " + str(image.get_width()) + "x" + str(image.get_height()) + ")"
			_update_progress("✓ Exported frame " + str(frame_to_render) + " as " + filename + " (" + str(export_frame_index + 1) + "/" + str(total_frames) + ")" + size_info)
	else:
		_update_progress("ERROR: Failed to capture frame " + str(frame_to_render))
	
	export_frame_index += 1
	
	# Continue with next frame
	_export_next_frame()

func _capture_control_node() -> Image:
	if not renderer:
		_update_progress("ERROR: Renderer control node is null")
		return null
	
	# Get the size of the control node
	var size = renderer.size
	if size.x <= 0 or size.y <= 0:
		_update_progress("ERROR: Renderer control node has invalid size: " + str(size))
		return null
	
	_update_progress("Capturing frame at size: " + str(size))
	
	# Create a SubViewport to render the control
	var capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(size)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Enable transparency in the SubViewport
	capture_viewport.transparent_bg = true
	
	# Temporarily add the SubViewport to the scene
	add_child(capture_viewport)
	
	# Clone the renderer node and its children
	var renderer_clone = renderer.duplicate(DUPLICATE_USE_INSTANTIATION)
	capture_viewport.add_child(renderer_clone)
	
	# Force the viewport to render
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame  # Wait an extra frame for safety
	
	# Get the rendered image with proper alpha channel
	var viewport_texture = capture_viewport.get_texture()
	if not viewport_texture:
		_update_progress("ERROR: Could not get texture from SubViewport")
		# Clean up before returning
		capture_viewport.remove_child(renderer_clone)
		renderer_clone.queue_free()
		remove_child(capture_viewport)
		capture_viewport.queue_free()
		return null
	
	var image = viewport_texture.get_image()
	
	# Clean up
	capture_viewport.remove_child(renderer_clone)
	renderer_clone.queue_free()
	remove_child(capture_viewport)
	capture_viewport.queue_free()
	
	if not image:
		_update_progress("ERROR: Could not capture image from SubViewport")
		return null
	
	# Ensure the image has an alpha channel for transparency
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
		_update_progress("Image converted to RGBA8 format")
	
	_update_progress("Frame captured successfully")
	# The image should now preserve the alpha channel from the SubViewport
	return image

func _scale_image_nearest_neighbor(source_image: Image, target_size: int) -> Image:
	"""
	Scale an image to target_size x target_size using nearest neighbor filtering
	to preserve pixel art aesthetics
	"""
	if not source_image:
		_update_progress("ERROR: Source image is null for scaling")
		return null
	
	var source_width = source_image.get_width()
	var source_height = source_image.get_height()
	
	# If already the target size, return as-is
	if source_width == target_size and source_height == target_size:
		_update_progress("Image already at target size (" + str(target_size) + "x" + str(target_size) + ")")
		return source_image
	
	_update_progress("Scaling image from " + str(source_width) + "x" + str(source_height) + " to " + str(target_size) + "x" + str(target_size))
	
	# Create a new image with the target size
	var scaled_image = Image.create(target_size, target_size, false, Image.FORMAT_RGBA8)
	
	# Calculate scaling factors
	var scale_x = float(source_width) / float(target_size)
	var scale_y = float(source_height) / float(target_size)
	
	# Apply nearest neighbor scaling
	for y in range(target_size):
		for x in range(target_size):
			# Find the nearest source pixel
			var source_x = int(x * scale_x)
			var source_y = int(y * scale_y)
			
			# Clamp to source image bounds
			source_x = clamp(source_x, 0, source_width - 1)
			source_y = clamp(source_y, 0, source_height - 1)
			
			# Get the pixel from source and set it in the scaled image
			var pixel_color = source_image.get_pixel(source_x, source_y)
			scaled_image.set_pixel(x, y, pixel_color)
	
	_update_progress("Image scaling completed")
	return scaled_image

func _finish_export():
	is_exporting = false
	export_button.text = "Export"
	export_button.disabled = false
	
	# Restore animation player state
	if animation_player:
		if was_playing_before_export:
			# Restore to original position and continue playing
			animation_player.seek(original_animation_position)
			if not animation_player.is_playing():
				animation_player.play()
			_update_progress("Animation restored to original state")
		else:
			# Stop animation if it wasn't playing before
			animation_player.stop()
			animation_player.seek(original_animation_position)
			_update_progress("Animation stopped and restored to original position")
	
	# Complete the progress bar
	progress_bar.value = 100
	
	_update_progress("------------------------------")
	_update_progress("EXPORT COMPLETED!")
	_update_progress("Total frames exported: " + str(total_frames))
	_update_progress("Export location: " + export_directory)
	_update_progress("Frame rate: " + str(fps) + " FPS")
	if animation_player:
		_update_progress("Animation was synchronized during export")
	_update_progress("------------------------------")
	
	# Optional: Show a completion message
	_show_completion_message(total_frames)

func _show_completion_message(frame_count: int):
	# You can implement a popup or notification here
	_update_progress("Animation export finished: " + str(frame_count) + " frames at " + str(fps) + " FPS")
	_update_progress("You can now create animations or GIFs from the exported frames")
	# Example: OS.shell_open(export_directory) # Opens the export folder

func _update_progress(message: String):
	# Update the console TextEdit with the message
	console.text += message + "\n"
	# Scroll to the bottom to show the latest message
	console.scroll_vertical = console.get_line_count()


# Optional: Method to set frame range programmatically
func set_frame_range(start: int, end: int):
	start_frame = start
	end_frame = end
	_update_progress("Frame range set to: " + str(start) + " - " + str(end) + " (total: " + str(end - start + 1) + " frames)")

func _update_canvas():
	# Capture the current frame from the SubViewport
	var viewport_texture = sub_viewport.get_texture()
	if viewport_texture:
		var image = viewport_texture.get_image()
		if image:
			# Update the cached texture with the current frame
			cached_texture.set_image(image)
			# Apply the cached texture to the display
			texture_rect.texture = cached_texture
		else:
			_update_progress("WARNING: Could not get image from SubViewport for canvas update")
	else:
		_update_progress("WARNING: Could not get texture from SubViewport for canvas update")

func _update_export_path_label():
	if export_directory == "":
		export_dir_path.text = "No directory selected"
	else:
		export_dir_path.text = export_directory

func _update_canvas_size_label():
	var export_resolution = int(resolution.value)
	var scale_factor = float(export_resolution) / float(BASE_CANVAS_SIZE)
	
	var scale_text = ""
	if scale_factor > 1.0:
		scale_text = " | *" + str(scale_factor) + " upscaled"
	elif scale_factor < 1.0:
		scale_text = " | *" + str(scale_factor) + " downscaled"
	else:
		scale_text = " | 1:1 scale"
	
	canvas_size_label.text = "Canvas base " + str(BASE_CANVAS_SIZE) + "px | Export resolution " + str(export_resolution) + "px" + scale_text

func _on_bg_color_toggled(button_pressed: bool):
	_update_bg_color_visibility()
	if button_pressed:
		_update_progress("Background color enabled")
	else:
		_update_progress("Background color disabled")

func _on_bg_color_changed(color: Color):
	bg_color_rect.color = color
	_update_progress("Background color changed to: " + str(color))

func _update_bg_color_visibility():
	var should_be_visible = bg_color_check_box.button_pressed
	bg_color_rect.visible = should_be_visible


func _view_mode_item_selected(index : int):
	get_node("ViewMaterials").item_selected(index)
	var selection : String = view_mode_dropdown.get_item_text(index)
	_update_progress("Switching View Mode To " + selection)

func _on_technical_mode_selected(mode_name: String):
	# Automatically turn off color remap when technical modes are selected
	_turn_off_color_remap_if_enabled()
	_update_progress("Technical mode '" + mode_name + "' selected - color remap automatically disabled")

func _turn_off_color_remap_if_enabled():
	# Check if color remap is currently enabled and turn it off
	if pixel_material_script and pixel_material_script.use_palette_check_box.button_pressed:
		pixel_material_script.use_palette_check_box.button_pressed = false
		# Trigger the toggled signal to update the shader parameter
		pixel_material_script._on_use_palette_toggled(false)
		_update_progress("Color remap automatically turned off for technical view mode")

func _setup_view_mode_dropdown():
	view_mode_dropdown.clear()
	
	view_mode_dropdown.add_item("Albedo")
	view_mode_dropdown.add_item("Normal")
	view_mode_dropdown.add_item("Specular")
	view_mode_dropdown.add_item("Toon")
func _on_close_button_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().quit()

func _on_close_button_mouse_entered():
	# Change texture when mouse enters the button area
	if ResourceLoader.exists("res://PixelRenderer2.png"):
		var hover_texture = load("res://PixelRenderer2.png") as Texture2D
		close_button.texture = hover_texture

func _on_close_button_mouse_exited():
	# Restore original texture when mouse exits the button area
	close_button.texture = original_close_texture

func _initialize_toon_controls():
	# Connect Toon material parameter control signals
	cuts_size_spin.value_changed.connect(_on_cuts_size_changed)
	albedo_toon_color.color_changed.connect(_on_albedo_toon_color_changed)
	wrap_slider.value_changed.connect(_on_wrap_changed)
	steepness_slider.value_changed.connect(_on_steepness_changed)
	rim_check_box.toggled.connect(_on_rim_toggled)
	rim_width_slider.value_changed.connect(_on_rim_width_changed)
	albedo_rim_color.color_changed.connect(_on_albedo_rim_color_changed)
	borders_size_spin.value_changed.connect(_on_borders_size_changed)
	albedo_borders_color.color_changed.connect(_on_albedo_borders_color_changed)
	specular_check_box.toggled.connect(_on_specular_toggled)
	spec_shininess_slider.value_changed.connect(_on_spec_shininess_changed)
	strength_slider.value_changed.connect(_on_strength_changed)
	ramp_check_box.toggled.connect(_on_ramp_toggled)
	
	# Initialize default values
	cuts_size_spin.value = 3
	wrap_slider.value = 0.0
	steepness_slider.value = 1.0
	rim_width_slider.value = 8.0
	spec_shininess_slider.value = 16.0
	strength_slider.value = 1.0

func _on_cuts_size_changed(value: float):
	_update_toon_parameter("cuts", int(value))

func _on_albedo_toon_color_changed(color: Color):
	_update_toon_parameter("albedo", color)

func _on_wrap_changed(value: float):
	_update_toon_parameter("wrap", value)

func _on_steepness_changed(value: float):
	_update_toon_parameter("steepness", value)

func _on_rim_toggled(enabled: bool):
	_update_toon_parameter("use_rim", enabled)

func _on_rim_width_changed(value: float):
	_update_toon_parameter("rim_width", value)

func _on_albedo_rim_color_changed(color: Color):
	_update_toon_parameter("rim_color", color)

func _on_borders_size_changed(value: float):
	_update_toon_parameter("border_width", value)

func _on_albedo_borders_color_changed(color: Color):
	_update_toon_parameter("albedo", color)  # This might affect the main albedo too

func _on_specular_toggled(enabled: bool):
	_update_toon_parameter("use_specular", enabled)

func _on_spec_shininess_changed(value: float):
	_update_toon_parameter("specular_shininess", value)

func _on_strength_changed(value: float):
	_update_toon_parameter("specular_strength", value)

func _on_ramp_toggled(enabled: bool):
	_update_toon_parameter("use_ramp", enabled)

func _update_toon_parameter(parameter_name: String, value):
	# Get the ViewMaterials node to update the Toon material parameters
	var view_materials = get_node_or_null("ViewMaterials")
	if view_materials:
		# Call the public method in ViewMaterials to update the Toon material
		if view_materials.has_method("update_toon_material_parameter"):
			view_materials.update_toon_material_parameter(parameter_name, value)
			_update_progress("Updated Toon material parameter '" + parameter_name + "' to: " + str(value))
		else:
			_update_progress("ERROR: ViewMaterials does not have update_toon_material_parameter method")
	else:
		_update_progress("ERROR: Could not find ViewMaterials node")
