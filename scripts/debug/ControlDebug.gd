# ControlDebug.gd - Interactive debug scene controller
extends Control

@onready var shader_rect = $ColorRect		# Shader display (has ShaderDebug.gd)
@onready var popup_menu = $Popup			# Notification popup (RichTextLabel)

# Core managers
var parameter_manager: ParameterManager
var input_handler: InputHandler

# UI Elements
var debug_menu_background: ColorRect
var debug_container: ScrollContainer
var debug_grid: VBoxContainer
var interactive_controls: Dictionary = {}

# Simple state
var show_debug = true
var debug_mode = "uniforms"

func _ready():
	print("=== INTERACTIVE DEBUG STARTING ===")
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initialize managers
	parameter_manager = ParameterManager.new()
	input_handler = InputHandler.new()
	
	# Setup the UI layout
	setup_interactive_debug_layout()
	
	# Connect input
	connect_debug_input()
	
	# Initial display
	refresh_debug_display()
	
	print("DEBUG: Interactive ControlDebug ready!")

func setup_interactive_debug_layout():
	"""Create interactive debug layout with editable controls"""
	
	# === SHADER DISPLAY AREA (FULLSIZE) ===
	shader_rect.anchor_left = 0.0
	shader_rect.anchor_top = 0.0
	shader_rect.anchor_right = 1.0
	shader_rect.anchor_bottom = 1.0
	
	# Load and apply shader
	var shader_material = ShaderMaterial.new()
	var shader = load("res://shaders/kaldao.gdshader")
	if shader:
		shader_material.shader = shader
		shader_rect.material = shader_material
		print("DEBUG: Shader loaded successfully")
	else:
		print("DEBUG: WARNING - Could not load shader!")
		shader_rect.color = Color(0.2, 0.3, 0.4, 1.0)
	
	# === CREATE DEBUG MENU BACKGROUND ===
	debug_menu_background = ColorRect.new()
	debug_menu_background.name = "DebugMenuBackground"
	debug_menu_background.color = Color(0.1, 0.1, 0.1, 0.85)
	debug_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_menu_background.anchor_left = 0.0
	debug_menu_background.anchor_top = 0.0
	debug_menu_background.anchor_right = 1.0
	debug_menu_background.anchor_bottom = 1.0
	debug_menu_background.offset_top = 20
	debug_menu_background.offset_bottom = -20
	
	add_child(debug_menu_background)
	
	# === CREATE SCROLLABLE CONTAINER ===
	debug_container = ScrollContainer.new()
	debug_container.name = "DebugScrollContainer"
	
	debug_container.anchor_left = 0.0
	debug_container.anchor_top = 0.0
	debug_container.anchor_right = 1.0
	debug_container.anchor_bottom = 1.0
	debug_container.offset_left = 30
	debug_container.offset_right = -30
	debug_container.offset_top = 30
	debug_container.offset_bottom = -30
	
	add_child(debug_container)
	
	# === CREATE VBOX CONTAINER ===
	debug_grid = VBoxContainer.new()
	debug_grid.name = "DebugVBox"
	debug_grid.add_theme_constant_override("separation", 3)
	
	debug_container.add_child(debug_grid)
	
	# Setup popup
	setup_popup_menu()

func setup_popup_menu():
	"""Setup the popup menu styling"""
	popup_menu.anchor_left = 0.0
	popup_menu.anchor_top = 0.0
	popup_menu.anchor_right = 0.3
	popup_menu.anchor_bottom = 0.15
	
	popup_menu.add_theme_color_override("default_color", Color.WHITE)
	popup_menu.add_theme_color_override("background_color", Color(0.2, 0.0, 0.2, 0.8))
	popup_menu.bbcode_enabled = false
	popup_menu.visible = false

func create_parameter_row(left_label: String, left_value: String, right_label: String = "", right_value: String = "", left_param: String = "", right_param: String = "", left_readonly: bool = false, right_readonly: bool = false):
	"""Create a row with two label/input pairs"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	# Left pair
	if left_label != "":
		var left_lbl = Label.new()
		left_lbl.text = left_label + ":"
		left_lbl.custom_minimum_size = Vector2(120, 20)
		left_lbl.add_theme_font_size_override("font_size", 11)
		left_lbl.add_theme_color_override("font_color", Color.WHITE)
		left_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(left_lbl)
		
		var left_input = LineEdit.new()
		left_input.text = left_value
		left_input.custom_minimum_size = Vector2(50, 20)
		left_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left_input.add_theme_font_size_override("font_size", 11)
		left_input.add_theme_color_override("font_color", Color.WHITE)
		left_input.add_theme_color_override("font_selected_color", Color.BLACK)
		left_input.add_theme_color_override("font_uneditable_color", Color.WHITE)
		
		if left_param != "" and not left_readonly:
			left_input.connect("text_submitted", _on_parameter_changed.bind(left_param))
			left_input.connect("focus_exited", _on_parameter_focus_lost.bind(left_param, left_input))
			interactive_controls[left_param] = left_input
		elif left_readonly:
			left_input.editable = false
			
		row.add_child(left_input)
	
	# Spacer between pairs
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(50, 20)
	row.add_child(spacer)
	
	# Right pair
	if right_label != "":
		var right_lbl = Label.new()
		right_lbl.text = right_label + ":"
		right_lbl.custom_minimum_size = Vector2(120, 20)
		right_lbl.add_theme_font_size_override("font_size", 11)
		right_lbl.add_theme_color_override("font_color", Color.WHITE)
		right_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(right_lbl)
		
		var right_input = LineEdit.new()
		right_input.text = right_value
		right_input.custom_minimum_size = Vector2(50, 20)
		right_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		right_input.add_theme_font_size_override("font_size", 11)
		right_input.add_theme_color_override("font_color", Color.WHITE)
		right_input.add_theme_color_override("font_selected_color", Color.BLACK)
		right_input.add_theme_color_override("font_uneditable_color", Color.WHITE)
		
		if right_param != "" and not right_readonly:
			right_input.connect("text_submitted", _on_parameter_changed.bind(right_param))
			right_input.connect("focus_exited", _on_parameter_focus_lost.bind(right_param, right_input))
			interactive_controls[right_param] = right_input
		elif right_readonly:
			right_input.editable = false
			
		row.add_child(right_input)
	
	debug_grid.add_child(row)

func create_interactive_controls():
	"""Create all the interactive controls"""
	create_simple_header()
	
	match debug_mode:
		"uniforms":
			create_uniforms_controls()
		"computed":
			create_computed_controls()
		"simulation":
			create_simulation_controls()

func create_simple_header():
	"""Simple header"""
	var header_label = Label.new()
	header_label.text = "Mode: %s    [D] Cycle [F] Simulate [G] Sync [H] Hide" % debug_mode
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	debug_grid.add_child(header_label)

func create_section_divider(text: String):
	"""Create a simple section divider"""
	var divider = Label.new()
	divider.text = "--- %s ---" % text
	divider.add_theme_color_override("font_color", Color.WHITE)
	divider.add_theme_font_size_override("font_size", 12)
	debug_grid.add_child(divider)

func create_uniforms_controls():
	"""Create interactive controls for uniforms mode using rows"""
	
	create_section_divider("CORE UNIFORMS")
	create_parameter_row("camera_position", "%.3f" % shader_rect.camera_position, "plane_rotation_time", "%.3f" % shader_rect.plane_rotation_time, "camera_position", "plane_rotation_time")
	create_parameter_row("rotation_time", "%.3f" % shader_rect.rotation_time, "color_time", "%.3f" % shader_rect.color_time, "rotation_time", "color_time")
	create_parameter_row("fly_speed", "%.3f" % shader_rect.fly_speed, "contrast", "%.3f" % shader_rect.contrast, "fly_speed", "contrast")
	
	create_section_divider("PATTERN CONTROLS")
	create_parameter_row("kaleidoscope_segments", "%.1f" % shader_rect.kaleidoscope_segments, "layer_count", "%d" % shader_rect.layer_count, "kaleidoscope_segments", "layer_count")
	create_parameter_row("truchet_radius", "%.3f" % shader_rect.truchet_radius, "center_fill_radius", "%.3f" % shader_rect.center_fill_radius, "truchet_radius", "center_fill_radius")
	create_parameter_row("rotation_speed", "%.3f" % shader_rect.rotation_speed, "plane_rotation_speed", "%.3f" % shader_rect.plane_rotation_speed, "rotation_speed", "plane_rotation_speed")
	create_parameter_row("zoom_level", "%.3f" % shader_rect.zoom_level, "color_intensity", "%.3f" % shader_rect.color_intensity, "zoom_level", "color_intensity")
	
	create_section_divider("CAMERA MOVEMENT")
	create_parameter_row("camera_tilt_x", "%.3f" % shader_rect.camera_tilt_x, "camera_tilt_y", "%.3f" % shader_rect.camera_tilt_y, "camera_tilt_x", "camera_tilt_y")
	create_parameter_row("camera_roll", "%.3f" % shader_rect.camera_roll, "path_stability", "%.3f" % shader_rect.path_stability, "camera_roll", "path_stability")
	create_parameter_row("path_scale", "%.3f" % shader_rect.path_scale, "", "", "path_scale", "")

func create_computed_controls():
	"""Create controls for computed values - read-only displays"""
	create_section_divider("CAMERA PATH VALUES")
	
	# Display computed camera vectors using rows
	create_display_row("current_offset", format_vector3(shader_rect.current_offset), "current_doffset", format_vector3(shader_rect.current_doffset))
	create_display_row("current_ddoffset", format_vector3(shader_rect.current_ddoffset), "camera_forward", format_vector3(shader_rect.camera_forward))
	create_display_row("camera_right", format_vector3(shader_rect.camera_right), "camera_up", format_vector3(shader_rect.camera_up))
	
	create_section_divider("COORDINATE CHAIN")
	
	# Display coordinate transformation chain
	create_display_row("original_p", format_vector2(shader_rect.original_p), "post_rotation_p", format_vector2(shader_rect.post_rotation_p))
	create_display_row("post_kaleidoscope_p", format_vector2(shader_rect.post_kaleidoscope_p), "post_main_rotation_p", format_vector2(shader_rect.post_main_rotation_p))
	create_display_row("final_truchet_p", format_vector2(shader_rect.final_truchet_p), "", "")
	
	create_section_divider("TRUCHET & CENTER FILL")
	
	# Display truchet and center fill debug values
	create_display_row("truchet_distance", "%.3f" % shader_rect.truchet_distance, "truchet_circle_distance", "%.3f" % shader_rect.truchet_circle_distance)
	create_display_row("truchet_center_factor", "%.3f" % shader_rect.truchet_center_factor, "center_distance", "%.3f" % shader_rect.center_distance)
	create_display_row("center_edge", "%.3f" % shader_rect.center_edge, "center_fill_applied", str(shader_rect.center_fill_applied))

func create_simulation_controls():
	"""Create controls for simulation results"""
	create_section_divider("SIMULATION CONTROL")
	
	var sim_label = Label.new()
	sim_label.text = "Press [F] to run simulation at current camera position + 1 unit forward"
	sim_label.add_theme_color_override("font_color", Color.WHITE)
	sim_label.add_theme_font_size_override("font_size", 11)
	debug_grid.add_child(sim_label)
	
	create_section_divider("SIMULATION RESULTS")
	
	# Show simulation results using display rows
	create_display_row("Plane Position", "Camera + (0,0,1)", "Camera Position", format_vector3(Vector3(0, 0, shader_rect.camera_position)))
	
	create_section_divider("COORDINATE TRANSFORMS")
	create_display_row("original_p", format_vector2(shader_rect.original_p), "post_rotation_p", format_vector2(shader_rect.post_rotation_p))
	create_display_row("post_kaleidoscope_p", format_vector2(shader_rect.post_kaleidoscope_p), "post_main_rotation_p", format_vector2(shader_rect.post_main_rotation_p))
	create_display_row("final_truchet_p", format_vector2(shader_rect.final_truchet_p), "", "")
	
	create_section_divider("PATTERN RESULTS")
	create_display_row("truchet_distance", "%.3f" % shader_rect.truchet_distance, "circle_distance", "%.3f" % shader_rect.truchet_circle_distance)
	create_display_row("center_factor", "%.3f" % shader_rect.truchet_center_factor, "center_distance", "%.3f" % shader_rect.center_distance)
	create_display_row("edge_factor", "%.3f" % shader_rect.center_edge, "fill_applied", str(shader_rect.center_fill_applied))

func create_display_row(left_label: String, left_value: String, right_label: String = "", right_value: String = ""):
	"""Create a row with two read-only label/value pairs"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	# Left pair
	if left_label != "":
		var left_lbl = Label.new()
		left_lbl.text = left_label + ":"
		left_lbl.custom_minimum_size = Vector2(120, 20)
		left_lbl.add_theme_font_size_override("font_size", 11)
		left_lbl.add_theme_color_override("font_color", Color.WHITE)
		left_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(left_lbl)
		
		var left_value_label = Label.new()
		left_value_label.text = left_value
		left_value_label.custom_minimum_size = Vector2(100, 20)
		left_value_label.add_theme_font_size_override("font_size", 11)
		left_value_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		left_value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(left_value_label)
	
	# Spacer between pairs
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(50, 20)
	row.add_child(spacer)
	
	# Right pair
	if right_label != "":
		var right_lbl = Label.new()
		right_lbl.text = right_label + ":"
		right_lbl.custom_minimum_size = Vector2(120, 20)
		right_lbl.add_theme_font_size_override("font_size", 11)
		right_lbl.add_theme_color_override("font_color", Color.WHITE)
		right_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(right_lbl)
		
		var right_value_label = Label.new()
		right_value_label.text = right_value
		right_value_label.custom_minimum_size = Vector2(100, 20)
		right_value_label.add_theme_font_size_override("font_size", 11)
		right_value_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		right_value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(right_value_label)
	
	debug_grid.add_child(row)

func format_vector3(vec: Vector3) -> String:
	"""Format a Vector3 for display"""
	return "(%.2f, %.2f, %.2f)" % [vec.x, vec.y, vec.z]

func format_vector2(vec: Vector2) -> String:
	"""Format a Vector2 for display"""
	return "(%.2f, %.2f)" % [vec.x, vec.y]

# === INPUT CALLBACKS ===

func _on_parameter_changed(param_name: String, new_text: String):
	"""Handle parameter value changes"""
	var new_value = float(new_text)
	parameter_manager.set_parameter_value(param_name, new_value)
	shader_rect.sync_from_parameter_manager(parameter_manager)
	update_shader_uniforms()
	show_parameter_popup("%s: %.3f" % [param_name, new_value])

func _on_parameter_focus_lost(param_name: String, input: LineEdit):
	"""Handle when user clicks away from input field"""
	_on_parameter_changed(param_name, input.text)

func show_parameter_popup(text: String, duration: float = 1.5):
	"""Show a parameter change popup"""
	popup_menu.text = text
	popup_menu.visible = true
	print("DEBUG: Showing popup: %s" % text)
	
	await get_tree().create_timer(duration).timeout
	popup_menu.visible = false

func connect_debug_input():
	"""Connect input signals"""
	input_handler.parameter_increase_requested.connect(on_parameter_increase)
	input_handler.parameter_decrease_requested.connect(on_parameter_decrease)
	input_handler.parameter_next_requested.connect(on_parameter_next)
	input_handler.parameter_previous_requested.connect(on_parameter_previous)

func _input(event):
	"""Handle debug input"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D:
				cycle_debug_mode()
			KEY_F:
				run_simulation()
			KEY_G:
				sync_and_refresh()
			KEY_H:
				toggle_debug_display()
			KEY_SPACE:
				refresh_debug_display()
			_:
				input_handler.handle_input(event)

func cycle_debug_mode():
	"""Cycle through debug modes and rebuild UI"""
	match debug_mode:
		"uniforms":
			debug_mode = "computed"
		"computed":
			debug_mode = "simulation"
		"simulation":
			debug_mode = "uniforms"
	
	refresh_debug_display()
	show_parameter_popup("Debug Mode: %s" % debug_mode)

func refresh_debug_display():
	"""Rebuild the entire debug interface"""
	if not show_debug:
		debug_container.visible = false
		debug_menu_background.visible = false
		return
	
	debug_container.visible = true
	debug_menu_background.visible = true
	
	# Clear existing controls
	for child in debug_grid.get_children():
		child.queue_free()
	
	interactive_controls.clear()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Recreate controls
	create_interactive_controls()

func run_simulation():
	"""Run shader simulation"""
	sync_and_refresh()
	
	var camera_pos = Vector3(0, 0, shader_rect.camera_position)  
	var plane_pos = camera_pos + Vector3(0, 0, 1)
	
	print("\n==============================")
	print("RUNNING SHADER SIMULATION")
	print("==============================")
	
	shader_rect.simulate_plane_calculation(plane_pos, camera_pos, 1.0)
	refresh_debug_display()
	show_parameter_popup("Simulation Complete")

func sync_and_refresh():
	"""Sync all values and refresh"""
	shader_rect.sync_from_parameter_manager(parameter_manager)
	shader_rect.update_camera_values()
	update_shader_uniforms()
	refresh_debug_display()

func update_shader_uniforms():
	"""Update shader with current parameter values"""
	var material = shader_rect.material as ShaderMaterial
	if not material:
		return
	
	var params = parameter_manager.get_all_parameters()
	for param_name in params:
		var value = params[param_name]["current"]
		if param_name != "color_palette":
			material.set_shader_parameter(param_name, value)
	
	# Update time-based uniforms
	material.set_shader_parameter("camera_position", shader_rect.camera_position)
	material.set_shader_parameter("rotation_time", shader_rect.rotation_time)
	material.set_shader_parameter("plane_rotation_time", shader_rect.plane_rotation_time)
	material.set_shader_parameter("color_time", shader_rect.color_time)

func toggle_debug_display():
	"""Toggle debug interface visibility"""
	show_debug = !show_debug
	refresh_debug_display()
	show_parameter_popup("Debug: %s" % ("ON" if show_debug else "OFF"))

func on_parameter_increase():
	parameter_manager.increase_current_parameter()
	sync_and_refresh()
	
	var param_name = parameter_manager.get_current_parameter_name()
	var param_value = parameter_manager.get_parameter_value(param_name)
	show_parameter_popup("%s: %.3f +" % [param_name, param_value])

func on_parameter_decrease():
	parameter_manager.decrease_current_parameter()
	sync_and_refresh()
	
	var param_name = parameter_manager.get_current_parameter_name()
	var param_value = parameter_manager.get_parameter_value(param_name)
	show_parameter_popup("%s: %.3f -" % [param_name, param_value])

func on_parameter_next():
	parameter_manager.next_parameter()
	refresh_debug_display()
	
	var param_name = parameter_manager.get_current_parameter_name()
	show_parameter_popup("→ %s" % param_name)

func on_parameter_previous():
	parameter_manager.previous_parameter()
	refresh_debug_display()
	
	var param_name = parameter_manager.get_current_parameter_name()
	show_parameter_popup("← %s" % param_name)

func _process(delta):
	"""Update time-based values"""
	shader_rect.camera_position += shader_rect.fly_speed * delta
	shader_rect.rotation_time += shader_rect.rotation_speed * delta
	shader_rect.plane_rotation_time += shader_rect.plane_rotation_speed * delta
	shader_rect.color_time += shader_rect.color_speed * delta
	
	update_shader_uniforms()
	update_interactive_display()

func update_interactive_display():
	"""Update the interactive controls with current values"""
	if interactive_controls.has("camera_position"):
		interactive_controls["camera_position"].text = "%.3f" % shader_rect.camera_position
	if interactive_controls.has("rotation_time"):
		interactive_controls["rotation_time"].text = "%.3f" % shader_rect.rotation_time
