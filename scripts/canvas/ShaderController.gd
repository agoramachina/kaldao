extends RefCounted
class_name ShaderController

var shader_material: ShaderMaterial

# Debug spam filter - don't print debug for these frequently-updated parameters
var filtered_debug_params = ["camera_position", "rotation_time", "plane_rotation_time", "color_time"]

func _init(material: ShaderMaterial = null):
	if material:
		shader_material = material

func set_material(material: ShaderMaterial):
	shader_material = material

func update_parameter(param_name: String, value: float):
	
	if not shader_material:
		print("DEBUG: ERROR - No shader_material available!")
		return
	
	# Special debug for speed parameters (but filter out accumulated time params)
	if param_name in ["fly_speed", "rotation_speed", "color_speed", "plane_rotation_speed"]:
		var old_shader_value = shader_material.get_shader_parameter(param_name)
	
	# Handle normal parameters
	shader_material.set_shader_parameter(param_name, value)
	
	# Verify it was set correctly
	var verified_value = shader_material.get_shader_parameter(param_name)
	
	# FILTERED DEBUG OUTPUT - only print for control changes, not time accumulation
	# if not param_name in filtered_debug_params:
	#	print("DEBUG: ShaderController.update_parameter: ", param_name, " = ", value)

func update_all_parameters(parameters: Dictionary):
	if not shader_material:
		print("DEBUG: ERROR - No shader_material available for update_all_parameters!")
		return
		
	print("DEBUG: Updating all parameters")
	for param_name in parameters:
		if param_name != "color_palette":  # Color palette handled separately
			var param_value = parameters[param_name]["current"]
			print("DEBUG: Setting ", param_name, " = ", param_value)
			shader_material.set_shader_parameter(param_name, param_value)

func update_color_palette(palette_data: Dictionary, use_palette: bool):
	if not shader_material:
		return
		
	shader_material.set_shader_parameter("use_color_palette", use_palette)
	shader_material.set_shader_parameter("palette_a", palette_data["a"])
	shader_material.set_shader_parameter("palette_b", palette_data["b"])
	shader_material.set_shader_parameter("palette_c", palette_data["c"])
	shader_material.set_shader_parameter("palette_d", palette_data["d"])
	
	# Set the invert flag
	var should_invert = palette_data.get("invert", false)
	shader_material.set_shader_parameter("invert_colors", should_invert)
	
	print("DEBUG: Updated color palette: ", palette_data["name"] if "name" in palette_data else "Custom")
	print("DEBUG: Invert colors: ", should_invert)
