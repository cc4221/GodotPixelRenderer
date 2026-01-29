extends Node

# Signal emitted when a technical rendering mode (Normal/Specular) is selected
signal technical_mode_selected(mode_name: String)

const NORMAL_MATERIAL = preload("res://PixelRenderer/data/NormalMaterial.tres")
const SPECULAR_MATERIAL = preload("res://PixelRenderer/data/SpecularMaterial.tres")
var TOON_MATERIAL = preload("res://PixelRenderer/data/ToonMaterial.tres")

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
				
				# Copy albedo texture from original material to the Toon material FIRST
				if original_material:
					var albedo_tex = null
					
					# Try to get albedo texture from various possible property names in the original material
					if original_material.get_class() == "StandardMaterial3D" or original_material.get_class() == "BaseMaterial3D":
						albedo_tex = original_material.albedo_texture
					elif original_material.get_class() == "ShaderMaterial":
						# For ShaderMaterial, attempt to get common albedo texture parameter names
						# Since Godot doesn't have a safe way to check if a shader parameter exists without potential errors,
						# we'll just try the most common parameter name that the FlexibleToon shader uses
						var temp_tex = original_material.get_shader_parameter("albedo_texture")
						if temp_tex:
							albedo_tex = temp_tex
						else:
							# Try alternative names
							temp_tex = original_material.get_shader_parameter("diffuse_texture")
							if temp_tex:
								albedo_tex = temp_tex
							else:
								temp_tex = original_material.get_shader_parameter("texture_albedo")
								if temp_tex:
									albedo_tex = temp_tex
					elif original_material.has_meta("albedo_texture"):
						albedo_tex = original_material.get_meta("albedo_texture")
					elif original_material.has_meta("texture_albedo"):
						albedo_tex = original_material.get_meta("texture_albedo")
					
					# Additional attempt: if mesh has a mesh resource, try to extract texture from it
					if not albedo_tex and mesh.mesh:
						# Try to get texture from the mesh's primitive/trimesh
						if mesh.mesh is ArrayMesh:
							var array_mesh = mesh.mesh as ArrayMesh
							# Check if there are surfaces with textures
							for surface_idx in range(array_mesh.get_surface_count()):
								var surf_mat = array_mesh.surface_get_material(surface_idx)
								if surf_mat and (surf_mat.get_class() == "StandardMaterial3D" or surf_mat.get_class() == "BaseMaterial3D"):
									albedo_tex = surf_mat.albedo_texture
									if albedo_tex:
										break
					
					# Set the albedo texture in the Toon material
					if albedo_tex and TOON_MATERIAL:
						TOON_MATERIAL.set_shader_parameter("albedo_texture", albedo_tex)
						print("Applied albedo texture to Toon material for mesh: ", mesh.name)
					else:
						print("No albedo texture found for mesh: ", mesh.name, ", using default Toon material")
				else:
					print("No original material found for mesh: ", mesh.name, ", using Toon material with defaults")
				
				# Apply the Toon material LAST, after extracting the original texture
				mesh.set_surface_override_material(0, TOON_MATERIAL)
		
			
			

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

# Public method to update Toon material parameters externally
func update_toon_material_parameter(param_name: String, value):
	if TOON_MATERIAL:
		TOON_MATERIAL.set_shader_parameter(param_name, value)
		print("Updated Toon material parameter '", param_name, "' to: ", value)
	else:
		print("ERROR: TOON_MATERIAL not available")

# Public method to get the Toon material instance
func get_toon_material():
	return TOON_MATERIAL
