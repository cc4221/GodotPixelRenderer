extends Node

# Signal emitted when a technical rendering mode (Normal/Specular) is selected
signal technical_mode_selected(mode_name: String)

const NORMAL_MATERIAL = preload("res://PixelRenderer/data/NormalMaterial.tres")
const SPECULAR_MATERIAL = preload("res://PixelRenderer/data/SpecularMaterial.tres")
const TOON_MATERIAL = preload("res://PixelRenderer/data/ToonMaterial.tres")

@onready var models_spawner: Node3D = %ModelsSpawner
@onready var view_mode_dropdown : OptionButton = %ViewModeDropDown

func item_selected(index : int):
	var meshes = get_all_mesh_instances(get_all_children(models_spawner))
	var selected_mode = view_mode_dropdown.get_item_text(index)
	
	match selected_mode:
		"Albedo":
			for mesh in meshes:
				mesh.set_surface_override_material(0, null)
		"Normal":
			for mesh in meshes:
				mesh.set_surface_override_material(0, NORMAL_MATERIAL)
			# Emit signal for technical mode selection
			technical_mode_selected.emit("Normal")
		"Specular":
			for mesh in meshes:
				mesh.set_surface_override_material(0, SPECULAR_MATERIAL)
			# Emit signal for technical mode selection
			technical_mode_selected.emit("Specular")
		"Toon":
			for mesh in meshes:
				# Get the original material to extract the albedo texture BEFORE applying Toon material
				var original_material = mesh.get_surface_override_material(0)
				if original_material == null:
					# If no override material, try to get the original surface material
					if mesh.mesh:
						original_material = mesh.mesh.surface_get_material(0)
				
				# Apply the Toon material first
				mesh.set_surface_override_material(0, TOON_MATERIAL)
				
				# Copy albedo texture from original material to the Toon material
				if original_material:
					var albedo_tex = null
					
					# Try to get albedo texture from various possible property names in the original material
					if original_material and (original_material.get_class() == "StandardMaterial3D" or original_material.get_class() == "SpatialMaterial"):
						albedo_tex = original_material.albedo_texture
					elif original_material and original_material.get_class() == "ShaderMaterial":
						# For ShaderMaterial, attempt to get the albedo texture parameter
						# Since we can't safely check if the parameter exists, we'll try common names
						# The FlexibleToon shader has an albedo_texture parameter, so try to get it
						if original_material.get_shader_parameter("albedo_texture"):
							albedo_tex = original_material.get_shader_parameter("albedo_texture")
						elif original_material.get_shader_parameter("diffuse_texture"):
							albedo_tex = original_material.get_shader_parameter("diffuse_texture")
					elif original_material and original_material.has_meta("albedo_texture"):
						albedo_tex = original_material.get_meta("albedo_texture")
					elif original_material and original_material.has_meta("texture_albedo"):
						albedo_tex = original_material.get_meta("texture_albedo")
					
					# Set the albedo texture in the Toon material
					if albedo_tex and TOON_MATERIAL:
						TOON_MATERIAL.set_shader_parameter("albedo_texture", albedo_tex)
			
			
			
func get_all_children(node) -> Array:
	var nodes : Array = []
	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(get_all_children(N))
		else:
			nodes.append(N)
	return nodes

func get_all_mesh_instances(array : Array) -> Array[MeshInstance3D]:
	var mesh_instances : Array[MeshInstance3D] = []
	
	for N in array:
		if N is MeshInstance3D:
			mesh_instances.append(N)
	return mesh_instances
