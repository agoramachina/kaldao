# ControlDebug.gd - Minimal debug scene controller
extends Control

@onready var label = $RichTextLabel
@onready var canvas = $ColorRect

# Core managers (minimal set)
var parameter_manager: ParameterManager
var shader_debug: ShaderDebug
var input_handler: InputHandler

# Simple state
var show_debug = true
var debug_mode = "uniforms"  # "uniforms", "computed", "simulation"

func _ready():
	print("DEBUG: ControlDebug starting...")
	
	# Set window size for debug
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initialize minimal managers
	parameter_manager = ParameterManager.new()
	shader_debug = ShaderDebug.new()
	input_handler = InputHandler.new()
	
	# Setup canvas with shader
	setup_debug_canvas()
	
	# Connect input signals (minimal set)
	connect_debug_input()
	
	# Initial debug output
	refresh_debug_display()
	
	print("DEBUG: ControlDebug ready!")

func setup_debug_canvas():
	"""Setup the debug canvas with shader"""
	# Make canvas fill most of screen, leave space for debug text
	canvas.anchor_left = 0.0
	canvas.anchor_top = 0.0
	canvas.anchor_right = 0.7  # Leave 30% for debug text
	canvas.anchor_bottom = 1.0
	
	# Load and apply shader (you'll need to load your kaldao shader here)
	var shader_material = ShaderMaterial.new()
	var shader = load("res://shaders/kaldao.gdshader")  # Adjust path as needed
	shader_material.shader = shader
	canvas.material = shader_material
	
	# Setup debug text area
	label.anchor_left = 0.7
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.bbcode_enabled = false
	label.add_theme_color_override("default_color", Color.WHITE)

func connect_debug_input():
	"""Connect minimal input for debugging"""
	input_handler.parameter_increase_requested.connect(on_parameter_increase)
	input_handler.parameter_decrease_requested.connect(on_parameter_decrease)
	input_handler.parameter_next_requested.connect(on_parameter_next)
	input_handler.parameter_previous_requested.connect(on_parameter_previous)

func _input(event):
	"""Handle debug-specific input"""
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
				# Let input handler process other keys
				input_handler.handle_input(event)

func cycle_debug_mode():
	"""Cycle through debug display modes"""
	match debug_mode:
		"uniforms":
			debug_mode = "computed"
		"computed":
			debug_mode = "simulation"
		"simulation":
			debug_mode = "uniforms"
	
	refresh_debug_display()
	print("DEBUG: Switched to mode: ", debug_mode)

func run_simulation():
	"""Run shader simulation at current camera position"""
	sync_and_refresh()
	
	# Simulate plane at camera position + 1 unit forward
	var camera_pos = Vector3(0, 0, shader_debug.camera_position)
	var plane_pos = camera_pos + Vector3(0, 0, 1)
	
	print("\n" + "==============================")
	print("RUNNING SHADER SIMULATION")
	print("==============================")
	
	shader_debug.simulate_plane_calculation(plane_pos, camera_pos, 1.0)
	refresh_debug_display()

func sync_and_refresh():
	"""Sync all values and refresh display"""
	shader_debug.sync_from_parameter_manager(parameter_manager)
	shader_debug.update_camera_values()
	update_shader_uniforms()
	refresh_debug_display()

func update_shader_uniforms():
	"""Push all parameter values to the shader"""
	var material = canvas.material as ShaderMaterial
	if not material:
		return
	
	# Update all shader uniforms from parameter manager
	var params = parameter_manager.get_all_parameters()
	for param_name in params:
		var value = params[param_name]["current"]
		
		# Skip meta parameters
		if param_name == "color_palette":
			continue
			
		material.set_shader_parameter(param_name, value)
	
	# Update time-based uniforms (you'd normally get these from CanvasManager)
	# For debug, we'll just increment them
	material.set_shader_parameter("camera_position", shader_debug.camera_position)
	material.set_shader_parameter("rotation_time", shader_debug.rotation_time)
	material.set_shader_parameter("plane_rotation_time", shader_debug.plane_rotation_time)
	material.set_shader_parameter("color_time", shader_debug.color_time)

func refresh_debug_display():
	"""Update the debug text display"""
	if not show_debug:
		label.text = "Debug Hidden\n[H] to show"
		return
	
	var debug_text = "=== SHADER DEBUG ===\n"
	debug_text += "Mode: %s\n" % debug_mode
	debug_text += "[D] Cycle mode [F] Simulate [G] Sync [H] Hide\n"
	debug_text += "[Space] Refresh\n\n"
	
	# Current parameter info
	var current_param = parameter_manager.get_current_parameter_name()
	var current_value = parameter_manager.get_parameter_value(current_param)
	debug_text += "Current: %s = %.3f\n" % [current_param, current_value]
	debug_text += "[↑/↓] Adjust [←/→] Switch\n\n"
	
	match debug_mode:
		"uniforms":
			debug_text += get_uniforms_debug_text()
		"computed":
			debug_text += get_computed_debug_text()
		"simulation":
			debug_text += get_simulation_debug_text()
	
	label.text = debug_text

func get_uniforms_debug_text() -> String:
	"""Get formatted uniform values"""
	var text = "--- CORE UNIFORMS ---\n"
	text += "camera_position: %.3f\n" % shader_debug.camera_position
	text += "rotation_time: %.3f\n" % shader_debug.rotation_time
	text += "fly_speed: %.3f\n" % shader_debug.fly_speed
	text += "contrast: %.3f\n\n" % shader_debug.contrast
	
	text += "--- PATTERN CONTROLS ---\n"
	text += "kaleidoscope_segments: %.1f\n" % shader_debug.kaleidoscope_segments
	text += "truchet_radius: %.3f\n" % shader_debug.truchet_radius
	text += "center_fill_radius: %.3f\n" % shader_debug.center_fill_radius
	text += "zoom_level: %.3f\n\n" % shader_debug.zoom_level
	
	text += "--- CAMERA ---\n"
	text += "tilt_x: %.3f tilt_y: %.3f\n" % [shader_debug.camera_tilt_x, shader_debug.camera_tilt_y]
	text += "roll: %.3f\n" % shader_debug.camera_roll
	text += "path_stability: %.3f\n" % shader_debug.path_stability
	
	return text

func get_computed_debug_text() -> String:
	"""Get formatted computed values"""
	var text = "--- CAMERA VECTORS ---\n"
	text += "offset: %s\n" % str(shader_debug.current_offset)
	text += "forward: %s\n" % str(shader_debug.camera_forward)
	text += "right: %s\n" % str(shader_debug.camera_right)
	text += "up: %s\n\n" % str(shader_debug.camera_up)
	
	text += "--- COORDINATE CHAIN ---\n"
	text += "original_p: %s\n" % str(shader_debug.original_p)
	text += "post_rotation: %s\n" % str(shader_debug.post_rotation_p)
	text += "post_kaleidoscope: %s\n" % str(shader_debug.post_kaleidoscope_p)
	text += "post_main_rot: %s\n" % str(shader_debug.post_main_rotation_p)
	text += "final_truchet: %s\n\n" % str(shader_debug.final_truchet_p)
	
	text += "--- CENTER FILL DEBUG ---\n"
	text += "center_distance: %.3f\n" % shader_debug.center_distance
	text += "center_edge: %.3f\n" % shader_debug.center_edge
	text += "fill_applied: %s\n" % str(shader_debug.center_fill_applied)
	
	return text

func get_simulation_debug_text() -> String:
	"""Get simulation results"""
	var text = "--- TRUCHET RESULTS ---\n"
	text += "distance: %.3f\n" % shader_debug.truchet_distance
	text += "circle_dist: %.3f\n" % shader_debug.truchet_circle_distance
	text += "center_factor: %.3f\n\n" % shader_debug.truchet_center_factor
	
	text += "--- CENTER FILL ---\n"
	text += "original_distance: %.3f\n" % shader_debug.center_distance
	text += "fill_radius: %.3f\n" % shader_debug.center_fill_radius
	text += "edge_factor: %.3f\n" % shader_debug.center_edge
	text += "applied: %s\n\n" % str(shader_debug.center_fill_applied)
	
	text += "Press [F] to run simulation\n"
	text += "at current camera position"
	
	return text

func toggle_debug_display():
	"""Toggle debug text visibility"""
	show_debug = !show_debug
	refresh_debug_display()

# Parameter adjustment functions
func on_parameter_increase():
	parameter_manager.increase_current_parameter()
	sync_and_refresh()

func on_parameter_decrease():
	parameter_manager.decrease_current_parameter()
	sync_and_refresh()

func on_parameter_next():
	parameter_manager.next_parameter()
	refresh_debug_display()

func on_parameter_previous():
	parameter_manager.previous_parameter()
	refresh_debug_display()

func _process(delta):
	"""Update time-based values"""
	# Simple time progression for debugging
	shader_debug.camera_position += shader_debug.fly_speed * delta
	shader_debug.rotation_time += shader_debug.rotation_speed * delta
	shader_debug.plane_rotation_time += shader_debug.plane_rotation_speed * delta
	shader_debug.color_time += shader_debug.color_speed * delta
	
	# Update shader uniforms
	update_shader_uniforms()
