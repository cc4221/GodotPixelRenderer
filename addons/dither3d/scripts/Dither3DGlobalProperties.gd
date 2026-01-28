@tool
extends Node

# This script is intended to be an Autoload (Singleton) named 'Dither3DGlobals'.
# It provides a GDScript API to control Dither3D global uniforms at runtime.
# It also handles dynamic logic like "Scale with Screen".

signal settings_changed

# Configuration
var scale_with_screen: bool = true
var reference_res: int = 1080

# Internal state for base scale (before dynamic adjustment)
var _base_dot_scale: float = 5.0

func _ready():
	# Wait a frame to ensure RenderingServer has synced global uniforms from ProjectSettings
	for i in range(20):
		await get_tree().process_frame	
	# Sync all settings from ProjectSettings to RenderingServer
	# This ensures that exported games (Runtime) load the correct values from project.godot
	_sync_from_project_settings()
	
	# Initialize base scale from current global setting
	# We use a safe check to avoid errors if the uniform isn't registered yet
	var current_scale = _safe_get_global("dither_dot_scale")
	if current_scale != null:
		_base_dot_scale = current_scale
	
	# Connect to screen resize
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed() # Initial update

func _sync_from_project_settings():
	var available_globals = RenderingServer.global_shader_parameter_get_list()
	# List of all our global variables
	var vars = [
		"dither_input_exposure", "dither_input_offset", "dither_mode",
		"dither_dot_scale", "dither_size_variability", "dither_contrast", "dither_stretch_smoothness",
		"dither_inverse_dots", "dither_radial_compensation", "dither_quantize_layers", "dither_debug_fractal"
	]
	
	for v in vars:
		if v in available_globals:
			_sync_single_var(v)		
	# Textures need special handling (loading from path)
	if "dither_tex" in available_globals:
		_sync_texture_var("dither_tex")
	if "dither_ramp_tex" in available_globals:
		_sync_texture_var("dither_ramp_tex")

func _sync_single_var(name: String):
	var setting_path = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_path):
		var dict = ProjectSettings.get_setting(setting_path)
		if dict is Dictionary and "value" in dict:
			RenderingServer.global_shader_parameter_set(name, dict["value"])

func _sync_texture_var(name: String):
	var setting_path = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_path):
		var dict = ProjectSettings.get_setting(setting_path)
		if dict is Dictionary and "value" in dict:
			var path = dict["value"]
			if path is String and path != "":
				var tex = load(path)
				if tex:
					RenderingServer.global_shader_parameter_set(name, tex)

func _safe_get_global(name: String):
	# In Godot 4.x, global_shader_parameter_get prints an error if the uniform doesn't exist.
	# We can't easily check existence via RenderingServer API directly without error spam.
	# So we check ProjectSettings first, which is the source of truth for "registered" globals.
	if ProjectSettings.has_setting("shader_globals/" + name):
		return RenderingServer.global_shader_parameter_get(name)
	return null

func _on_viewport_size_changed():
	if scale_with_screen:
		_update_dot_scale_dynamic()

func _update_dot_scale_dynamic():
	var viewport_height = get_viewport().get_visible_rect().size.y
	# Avoid div by zero or invalid sizes
	if viewport_height <= 0 or reference_res <= 0:
		return
		
	var multiplier = float(viewport_height) / float(reference_res)
	var log_delta = 0.0
	if multiplier > 0.0:
		log_delta = log(multiplier) / log(2.0)
	
	var final_scale = _base_dot_scale + log_delta
	
	# Only set if registered
	if ProjectSettings.has_setting("shader_globals/dither_dot_scale"):
		RenderingServer.global_shader_parameter_set("dither_dot_scale", final_scale)

# --- Public API for Runtime Control ---

func set_dither_mode(mode: int):
	_set_global("dither_mode", mode)

func set_input_exposure(value: float):
	_set_global("dither_input_exposure", value)

func set_input_offset(value: float):
	_set_global("dither_input_offset", value)

func set_dither_tex(tex: Texture3D):
	_set_global("dither_tex", tex)

func set_dither_ramp_tex(tex: Texture2D):
	_set_global("dither_ramp_tex", tex)

func set_dot_scale(value: float):
	# This sets the BASE scale
	_base_dot_scale = value
	if scale_with_screen:
		_update_dot_scale_dynamic()
	else:
		_set_global("dither_dot_scale", value)

func set_size_variability(value: float):
	_set_global("dither_size_variability", value)

func set_contrast(value: float):
	_set_global("dither_contrast", value)

func set_stretch_smoothness(value: float):
	_set_global("dither_stretch_smoothness", value)

func set_inverse_dots(enabled: bool):
	_set_global("dither_inverse_dots", enabled)

func set_radial_compensation(enabled: bool):
	_set_global("dither_radial_compensation", enabled)

func set_quantize_layers(enabled: bool):
	_set_global("dither_quantize_layers", enabled)

func set_debug_fractal(enabled: bool):
	_set_global("dither_debug_fractal", enabled)

# --- Internal Helpers ---

func _set_global(name: String, value):
	if ProjectSettings.has_setting("shader_globals/" + name):
		RenderingServer.global_shader_parameter_set(name, value)
		settings_changed.emit()

func get_global_uniform(name: String):
	return _safe_get_global(name)
