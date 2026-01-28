@tool
extends EditorPlugin

const DitherGeneratorScript = preload("scripts/Dither3DTextureGenerator.gd")
const SceneConverterDialog = preload("scripts/Dither3DSceneConverterDialog.gd")
const BottomPanelScript = preload("ui/dither3d_bottom_panel.gd")

var _main_popup_menu: PopupMenu
var _textures_popup_menu: PopupMenu
var _scenes_popup_menu: PopupMenu
var _scene_converter_dialog: ConfirmationDialog
var _bottom_panel_control: Control

func _enter_tree():
	add_custom_type("Dither3DGlobalProperties", "Node", preload("scripts/Dither3DGlobalProperties.gd"), preload("icon.svg"))
	
	# Register as Autoload so it runs globally
	add_autoload_singleton("Dither3DGlobals", "res://addons/dither3d/scripts/Dither3DGlobalProperties.gd")
	
	_scene_converter_dialog = SceneConverterDialog.new()
	add_child(_scene_converter_dialog)
	_scene_converter_dialog.generate_requested.connect(_on_scene_convert_requested)
	_scene_converter_dialog.generate_global_requested.connect(_on_scene_convert_global_requested)
	
	_setup_tool_menu()
	_register_global_uniforms()
	
	# Setup Bottom Panel
	_bottom_panel_control = BottomPanelScript.new()
	# We need to wrap it in a ScrollContainer because the panel might be small
	var scroll = ScrollContainer.new()
	scroll.name = "Dither3D Settings"
	scroll.add_child(_bottom_panel_control)
	_bottom_panel_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_panel_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Add to editor bottom panel
	add_control_to_bottom_panel(scroll, "Dither3D")

func _exit_tree():
	remove_custom_type("Dither3DGlobalProperties")
	remove_autoload_singleton("Dither3DGlobals")
	
	if _scene_converter_dialog:
		_scene_converter_dialog.queue_free()
		
	if _bottom_panel_control:
		# The scroll container is the parent, we need to remove that
		var scroll = _bottom_panel_control.get_parent()
		remove_control_from_bottom_panel(scroll)
		scroll.queue_free()
	
	_remove_tool_menu()
	_unregister_global_uniforms()

func _setup_tool_menu():
	# Create the Textures submenu
	_textures_popup_menu = PopupMenu.new()
	_textures_popup_menu.name = "Textures"
	_textures_popup_menu.add_item("Generate 1x1 (Bayer)", 0)
	_textures_popup_menu.add_item("Generate 2x2 (Bayer)", 1)
	_textures_popup_menu.add_item("Generate 4x4 (Bayer)", 2)
	_textures_popup_menu.add_item("Generate 8x8 (Bayer)", 3)
	_textures_popup_menu.add_separator()
	_textures_popup_menu.add_item("Generate All Standard", 100)
	
	_textures_popup_menu.id_pressed.connect(_on_textures_menu_item_pressed)
	
	# Create the Scenes submenu
	_scenes_popup_menu = PopupMenu.new()
	_scenes_popup_menu.name = "Scenes"
	_scenes_popup_menu.add_item("Create Dither3D Copy from Scene...", 0)
	
	_scenes_popup_menu.id_pressed.connect(_on_scenes_menu_item_pressed)
	
	# Create the main Dither3D menu
	_main_popup_menu = PopupMenu.new()
	_main_popup_menu.name = "Dither3D"
	
	# Add Textures submenu to main menu
	_main_popup_menu.add_child(_textures_popup_menu)
	_main_popup_menu.add_submenu_item("Textures", "Textures")
	
	# Add Scenes submenu to main menu
	_main_popup_menu.add_child(_scenes_popup_menu)
	_main_popup_menu.add_submenu_item("Scenes", "Scenes")
	
	# Add the main menu to Project > Tools
	add_tool_submenu_item("Dither3D", _main_popup_menu)

func _remove_tool_menu():
	remove_tool_menu_item("Dither3D")
	
	if _main_popup_menu:
		_main_popup_menu.queue_free()
		_main_popup_menu = null
		# _textures_popup_menu is a child of _main_popup_menu, so it will be freed automatically

func _on_textures_menu_item_pressed(id: int):
	match id:
		0: _run_generator(0)
		1: _run_generator(1)
		2: _run_generator(2)
		3: _run_generator(3)
		100: _generate_all()

func _generate_all():
	var generator = DitherGeneratorScript.new()
	generator.generate_all_textures()
	generator.free()
	# Rescan to show new files in FileSystem dock
	get_editor_interface().get_resource_filesystem().scan()

func _run_generator(recursion: int):
	var generator = DitherGeneratorScript.new()
	generator.create_dither_3d_texture(recursion)
	generator.free()
	# Rescan to show new files in FileSystem dock
	get_editor_interface().get_resource_filesystem().scan()

func _on_scenes_menu_item_pressed(id: int):
	match id:
		0: _scene_converter_dialog.popup_centered()

func _on_scene_convert_requested(path: String):
	_process_scene_convert(path, false)

func _on_scene_convert_global_requested(path: String):
	_process_scene_convert(path, true)

func _process_scene_convert(path: String, is_global: bool):
	print("Dither3D: Generate requested for scene: ", path, " (Global: ", is_global, ")")
	
	if path.is_empty():
		printerr("Dither3D: No scene path provided.")
		return
	
	var dir = path.get_base_dir()
	var file_name = path.get_file().get_basename()
	var extension = path.get_extension()
	var suffix = "_Dither3D_Global" if is_global else "_Dither3D"
	var new_path = dir + "/" + file_name + suffix + "." + extension
	
	# Load the original scene
	var packed_scene = load(path)
	if not packed_scene:
		printerr("Dither3D: Failed to load scene: ", path)
		return
		
	var root = packed_scene.instantiate()
	if not root:
		printerr("Dither3D: Failed to instantiate scene.")
		return
	
	# Modify the scene
	_recursive_apply_dither(root, is_global)
	
	# Pack and Save
	var new_packed_scene = PackedScene.new()
	var pack_result = new_packed_scene.pack(root)
	if pack_result != OK:
		printerr("Dither3D: Failed to pack modified scene.")
		root.free()
		return
		
	var save_result = ResourceSaver.save(new_packed_scene, new_path)
	if save_result != OK:
		printerr("Dither3D: Failed to save new scene.")
	else:
		print("Dither3D: Successfully created Dither3D scene: ", new_path)
		get_editor_interface().get_resource_filesystem().scan()
	
	root.free()

func _recursive_apply_dither(node: Node, is_global: bool):
	# Debug print
	# print("Dither3D: Visiting ", node.name, " (", node.get_class(), ")")

	# Process GeometryInstance3D (MeshInstance3D, CSGShape3D, etc.)
	if node is GeometryInstance3D:
		if node.material_override:
			print("Dither3D: Modifying material_override on ", node.name)
			node.material_override = _append_dither_pass(node.material_override, is_global)
		if node.material_overlay:
			print("Dither3D: Modifying material_overlay on ", node.name)
			node.material_overlay = _append_dither_pass(node.material_overlay, is_global)
			
	# Specific handling for MeshInstance3D surfaces
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = node.get_surface_override_material(i)
				if not mat:
					mat = mesh.surface_get_material(i)
				
				if mat:
					print("Dither3D: Modifying surface ", i, " on ", node.name)
					var new_mat = _append_dither_pass(mat, is_global)
					node.set_surface_override_material(i, new_mat)
					
	# Specific handling for CSGShape3D material slot
	# Note: CSGCombiner3D inherits from CSGShape3D but does NOT have a 'material' property exposed in the same way
	# or it might be behaving differently. We should check if it has the property first.
	elif node is CSGShape3D and not node is CSGCombiner3D:
		if node.material:
			print("Dither3D: Modifying material on CSG ", node.name)
			node.material = _append_dither_pass(node.material, is_global)
		else:
			print("Dither3D: CSG ", node.name, " has no material assigned.")
			
	# Recurse children
	for child in node.get_children():
		_recursive_apply_dither(child, is_global)

func _append_dither_pass(material: Material, is_global: bool) -> Material:
	if not material:
		return null
		
	# Duplicate the material to make it unique for this object/scene
	var new_mat = material.duplicate()
	
	# If it's a BaseMaterial3D or ShaderMaterial, it has next_pass
	if "next_pass" in new_mat:
		if new_mat.next_pass:
			# Check if the next pass is already our dither shader to avoid infinite stacking
			if _is_dither_material(new_mat.next_pass):
				pass # Already has it
			else:
				new_mat.next_pass = _append_dither_pass(new_mat.next_pass, is_global)
		else:
			new_mat.next_pass = _get_dither_next_pass_instance(is_global)
			
	return new_mat

func _is_dither_material(mat: Material) -> bool:
	if mat is ShaderMaterial and mat.shader:
		if mat.shader.resource_path.ends_with("Dither3DNextPass.gdshader") or mat.shader.resource_path.ends_with("Dither3DNextPassGlobal.gdshader"):
			return true
	return false

func _get_dither_next_pass_instance(is_global: bool) -> Material:
	var path = "res://addons/dither3d/materials/dither3d-nextpass-default.tres"
	if is_global:
		path = "res://addons/dither3d/materials/global/dither3d-nextpass-global.tres"
		
	var base = load(path)
	if base:
		return base.duplicate()
	return null

func _register_global_uniforms():
	var added = false
	
	added = _add_global_uniform("dither_input_exposure", "float", 1.0) or added
	added = _add_global_uniform("dither_input_offset", "float", 0.0) or added
	added = _add_global_uniform("dither_mode", "int", 1) or added # 1 = RGB
	added = _add_global_uniform("dither_tex", "sampler3D", "res://addons/dither3d/textures/Dither3D_8x8.res") or added
	added = _add_global_uniform("dither_ramp_tex", "sampler2D", "res://addons/dither3d/textures/Dither3D_8x8_Ramp.png") or added
	added = _add_global_uniform("dither_dot_scale", "float", 5.0) or added
	added = _add_global_uniform("dither_size_variability", "float", 1.0) or added
	added = _add_global_uniform("dither_contrast", "float", 1.0) or added
	added = _add_global_uniform("dither_stretch_smoothness", "float", 2.0) or added
	added = _add_global_uniform("dither_inverse_dots", "bool", false) or added
	added = _add_global_uniform("dither_radial_compensation", "bool", true) or added
	added = _add_global_uniform("dither_quantize_layers", "bool", false) or added
	added = _add_global_uniform("dither_debug_fractal", "bool", false) or added
	
	if added:
		# Force save to ensure they are persisted and recognized
		ProjectSettings.save()
		print("Dither3D: Global uniforms registered and saved.")

func _unregister_global_uniforms():
	print("Dither3D: Unregistering global uniforms...")
	_remove_global_uniform("dither_input_exposure")
	_remove_global_uniform("dither_input_offset")
	_remove_global_uniform("dither_mode")
	_remove_global_uniform("dither_tex")
	_remove_global_uniform("dither_ramp_tex")
	_remove_global_uniform("dither_dot_scale")
	_remove_global_uniform("dither_size_variability")
	_remove_global_uniform("dither_contrast")
	_remove_global_uniform("dither_stretch_smoothness")
	_remove_global_uniform("dither_inverse_dots")
	_remove_global_uniform("dither_radial_compensation")
	_remove_global_uniform("dither_quantize_layers")
	_remove_global_uniform("dither_debug_fractal")
	
	ProjectSettings.save()
	print("Dither3D: Global uniforms unregistered and saved.")

func _add_global_uniform(name: String, type: String, value) -> bool:
	var setting_name = "shader_globals/" + name
	if not ProjectSettings.has_setting(setting_name):
		var dict = {
			"type": type,
			"value": value
		}
		ProjectSettings.set_setting(setting_name, dict)
		ProjectSettings.set_initial_value(setting_name, dict)
		# Also try to add it to the RenderingServer directly for immediate effect
		# RenderingServer.global_shader_parameter_add(name, type, value) # This API might differ in GDScript
		return true
	return false

func _remove_global_uniform(name: String):
	var setting_name = "shader_globals/" + name
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, null)
		# RenderingServer.global_shader_parameter_remove(name)

