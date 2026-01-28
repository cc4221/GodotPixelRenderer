@tool
extends Control

# UI Components
var _vbox: VBoxContainer
var _grid: GridContainer

# Fields
var _mode_option: OptionButton
var _exposure_spin: SpinBox
var _offset_spin: SpinBox
var _scale_spin: SpinBox
var _variability_spin: SpinBox
var _contrast_spin: SpinBox
var _smoothness_spin: SpinBox
var _inverse_check: CheckBox
var _radial_check: CheckBox
var _quantize_check: CheckBox
var _fractal_check: CheckBox

# Texture fields (simplified for now)
var _tex_picker: EditorResourcePicker
var _ramp_picker: EditorResourcePicker

var _updating: bool = false

func _ready():
	_setup_ui()
	_refresh_values()

func _setup_ui():
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 8)
	add_child(_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Dither3D Global Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)
	
	_grid = GridContainer.new()
	_grid.columns = 2
	_vbox.add_child(_grid)
	
	# Helper to add rows
	_add_row("Dither Mode", _create_mode_option())
	
	_add_row("Dither Texture (3D)", _create_resource_picker("Texture3D", "dither_tex"))
	_add_row("Dither Ramp (2D)", _create_resource_picker("Texture2D", "dither_ramp_tex"))
	
	_add_row("Input Exposure", _create_spin_box(0.0, 5.0, 0.01, "dither_input_exposure"))
	_add_row("Input Offset", _create_spin_box(-1.0, 1.0, 0.01, "dither_input_offset"))
	_add_row("Dot Scale", _create_spin_box(1.0, 20.0, 0.1, "dither_dot_scale"))
	_add_row("Size Variability", _create_spin_box(0.0, 1.0, 0.01, "dither_size_variability"))
	_add_row("Contrast", _create_spin_box(0.0, 2.0, 0.01, "dither_contrast"))
	_add_row("Stretch Smoothness", _create_spin_box(0.0, 2.0, 0.01, "dither_stretch_smoothness"))
	
	_add_row("Inverse Dots", _create_checkbox("dither_inverse_dots"))
	_add_row("Radial Compensation", _create_checkbox("dither_radial_compensation"))
	_add_row("Quantize Layers", _create_checkbox("dither_quantize_layers"))
	_add_row("Debug Fractal", _create_checkbox("dither_debug_fractal"))
	
	# Refresh Button
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh from Project Settings"
	refresh_btn.pressed.connect(_refresh_values)
	_vbox.add_child(refresh_btn)

func _add_row(label_text: String, control: Control):
	var label = Label.new()
	label.text = label_text
	_grid.add_child(label)
	_grid.add_child(control)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _create_resource_picker(base_type: String, setting_name: String) -> EditorResourcePicker:
	var picker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.resource_changed.connect(func(res): _update_texture_setting(setting_name, res))
	
	match setting_name:
		"dither_tex": _tex_picker = picker
		"dither_ramp_tex": _ramp_picker = picker
		
	return picker

func _create_mode_option() -> OptionButton:
	_mode_option = OptionButton.new()
	_mode_option.add_item("Grayscale", 0)
	_mode_option.add_item("RGB", 1)
	_mode_option.add_item("CMYK", 2)
	_mode_option.item_selected.connect(func(idx): _update_setting("dither_mode", idx))
	return _mode_option

func _create_spin_box(min_val, max_val, step, setting_name) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value_changed.connect(func(val): _update_setting(setting_name, val))
	
	# Assign to specific variables for refresh
	match setting_name:
		"dither_input_exposure": _exposure_spin = spin
		"dither_input_offset": _offset_spin = spin
		"dither_dot_scale": _scale_spin = spin
		"dither_size_variability": _variability_spin = spin
		"dither_contrast": _contrast_spin = spin
		"dither_stretch_smoothness": _smoothness_spin = spin
		
	return spin

func _create_checkbox(setting_name) -> CheckBox:
	var check = CheckBox.new()
	check.toggled.connect(func(val): _update_setting(setting_name, val))
	
	match setting_name:
		"dither_inverse_dots": _inverse_check = check
		"dither_radial_compensation": _radial_check = check
		"dither_quantize_layers": _quantize_check = check
		"dither_debug_fractal": _fractal_check = check
		
	return check

func _update_texture_setting(name: String, res: Resource):
	if _updating: return
	
	var path = ""
	if res:
		path = res.resource_path
		
	# 1. Update ProjectSettings (Persistence) - Store Path
	var setting_path = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_path):
		var dict = ProjectSettings.get_setting(setting_path)
		if dict is Dictionary:
			dict["value"] = path
			ProjectSettings.set_setting(setting_path, dict)
			ProjectSettings.save() # Auto-save
	
	# 2. Update RenderingServer (Immediate) - Pass Resource
	if ProjectSettings.has_setting(setting_path):
		RenderingServer.global_shader_parameter_set(name, res)

func _update_setting(name: String, value):
	if _updating:
		return

	# 1. Update ProjectSettings (Persistence)
	var setting_path = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_path):
		var dict = ProjectSettings.get_setting(setting_path)
		if dict is Dictionary:
			dict["value"] = value
			ProjectSettings.set_setting(setting_path, dict)
			ProjectSettings.save() # Auto-save
	
	# 2. Update RenderingServer (Immediate Visual Feedback)
	# Only update if the global uniform is actually registered to avoid errors
	if ProjectSettings.has_setting(setting_path):
		RenderingServer.global_shader_parameter_set(name, value)

func _refresh_values():
	_updating = true
	
	_mode_option.selected = _get_global_int("dither_mode")
	
	var tex_path = _get_global_str("dither_tex")
	if tex_path != "":
		_tex_picker.edited_resource = load(tex_path)
	else:
		_tex_picker.edited_resource = null
		
	var ramp_path = _get_global_str("dither_ramp_tex")
	if ramp_path != "":
		_ramp_picker.edited_resource = load(ramp_path)
	else:
		_ramp_picker.edited_resource = null
	
	_exposure_spin.value = _get_global_float("dither_input_exposure")
	_offset_spin.value = _get_global_float("dither_input_offset")
	_scale_spin.value = _get_global_float("dither_dot_scale")
	_variability_spin.value = _get_global_float("dither_size_variability")
	_contrast_spin.value = _get_global_float("dither_contrast")
	_smoothness_spin.value = _get_global_float("dither_stretch_smoothness")
	
	_inverse_check.button_pressed = _get_global_bool("dither_inverse_dots")
	_radial_check.button_pressed = _get_global_bool("dither_radial_compensation")
	_quantize_check.button_pressed = _get_global_bool("dither_quantize_layers")
	_fractal_check.button_pressed = _get_global_bool("dither_debug_fractal")
	
	_updating = false

func _get_global_str(name: String) -> String:
	var val = _get_global_value(name)
	return str(val) if val != null else ""

func _get_global_float(name: String) -> float:
	var val = _get_global_value(name)
	return float(val) if val != null else 0.0

func _get_global_int(name: String) -> int:
	var val = _get_global_value(name)
	return int(val) if val != null else 0

func _get_global_bool(name: String) -> bool:
	var val = _get_global_value(name)
	return bool(val) if val != null else false

func _get_global_value(name: String):
	# Prefer ProjectSettings for the UI to avoid "variable not found" errors in RenderingServer
	# during initialization or if the variable hasn't been synced yet.
	var setting_path = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_path):
		var dict = ProjectSettings.get_setting(setting_path)
		if dict is Dictionary and "value" in dict:
			return dict["value"]
			
	# Fallback to RenderingServer if not in ProjectSettings (unlikely for our use case)
	# But we wrap it to be safe-ish, though we can't catch the error.
	# Actually, if it's not in ProjectSettings, we probably shouldn't ask RS either.
	return null
