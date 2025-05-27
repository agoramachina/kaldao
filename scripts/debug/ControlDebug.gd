# ControlDebug.gd - Clean debug scene controller
extends Control

@onready var shader_rect = $ColorRect		# Shader display (has ShaderDebug.gd)
@onready var debug_menu = $Menu				# Debug text (RichTextLabel)
@onready var popup_menu = $Popup			# Notification popup (RichTextLabel)

# Core managers
var parameter_manager: ParameterManager
var input_handler: InputHandler
var debug_menu_background: ColorRect
var show_debug = true
var debug_mode = "uniforms"

func _ready():
	print("=== CONTROL DEBUG SCRIPT STARTING ===")
	
	# Set window size for debug
	# set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initialize managers
	parameter_manager = ParameterManager.new()
	input_handler = InputHandler.new()
	
	setup_debug_layout()
	connect_debug_input()
	refresh_debug_display()
	
	print("DEBUG: ControlDebug ready!")

func setup_debug_layout():
	"""Setup the debug layout with proper backgrounds"""
	
	# === CREATE DEBUG MENU BACKGROUND ===
	debug_menu_background = ColorRect.new()
	debug_menu_background.name = "DebugMenuBackground"
	debug_menu_background.color = Color(0.1, 0.1, 0.1, 0.75)  # Dark semi-transparent
	debug_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Position background
	debug_menu_background.anchor_top = 0.0
	debug_menu_background.anchor_bottom = 1.0
	debug_menu_background.anchor_left = 0.0
	debug_menu_background.anchor_right = 1.0

	debug_menu.offset_top = 10
	debug_menu.offset_bottom = 10

	# Add background to scene BEFORE debug_menu so it renders behind
	add_child(debug_menu_background)
	move_child(debug_menu_background, debug_menu.get_index())  # Put it behind debug_menu
	
	# === DEBUG TEXT AREA ===
	debug_menu.anchor_left = 0.0
	debug_menu.anchor_top = 0.0
	debug_menu.anchor_right = 1.0
	debug_menu.anchor_bottom = 1.0
	debug_menu.offset_top = 20
	debug_menu.offset_bottom = 20
	debug_menu.offset_left = 10
	debug_menu.offset_right = 10
	
	# Set debug menu background and text properties
	debug_menu.bbcode_enabled = false
	debug_menu.add_theme_color_override("default_color", Color.WHITE)
	debug_menu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# === POPUP AREA (top-left of shader area) ===
	popup_menu.anchor_left = 0.0
	popup_menu.anchor_top = 0.0  # Top instead of bottom
	popup_menu.anchor_right = 0.3  # Only 30% width
	popup_menu.anchor_bottom = 0.15  # Top 15% height
	
	# Set popup background and text properties
	popup_menu.add_theme_color_override("default_color", Color.WHITE)
	popup_menu.add_theme_color_override("background_color", Color(0.2, 0.0, 0.2, 0.8))
	popup_menu.bbcode_enabled = false
	popup_menu.visible = false

func show_parameter_popup(text: String, duration: float = 1.5):
	"""Show a parameter change popup"""
	popup_menu.text = text
	popup_menu.visible = true
	print("DEBUG: Showing popup: %s" % text)
	
	# Auto-hide after duration
	await get_tree().create_timer(duration).timeout
	popup_menu.visible = false

# === INPUT HANDLING ===
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

# === DEBUG FUNCTIONS ===

func cycle_debug_mode():
	"""Cycle through debug modes"""
	match debug_mode:
		"uniforms":
			debug_mode = "computed"
		"computed":
			debug_mode = "simulation"
		"simulation":
			debug_mode = "uniforms"
	
	refresh_debug_display()
	show_parameter_popup("Debug Mode: %s" % debug_mode)
	print("DEBUG: Switched to mode: ", debug_mode)

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
	
	# Update parameters
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

func refresh_debug_display():
	"""Update debug text"""
	if not show_debug:
		debug_menu.text = "Debug Hidden\n[H] to show"
		return
	
	var debug_text = "=== SHADER DEBUG ===\n"
	debug_text += "Mode: %s\n" % debug_mode
	debug_text += "[D] Cycle [F] Simulate [G] Sync [H] Hide\n"
	debug_text += "[Space] Refresh\n\n"
	
	# Current parameter
	var current_param = parameter_manager.get_current_parameter_name()
	var current_value = parameter_manager.get_parameter_value(current_param)
	debug_text += "Current: %s = %.3f\n" % [current_param, current_value]
	debug_text += "[↑/↓] Adjust [←/→] Switch\n\n"
	
	# Mode-specific info
	match debug_mode:
		"uniforms":
			debug_text += get_uniforms_debug_text()
		"computed":
			debug_text += get_computed_debug_text()
		"simulation":
			debug_text += get_simulation_debug_text()
	
	debug_menu.text = debug_text

func get_uniforms_debug_text() -> String:
	"""Core uniform values"""
	var text = "--- CORE UNIFORMS ---\n"
	text += "camera_position: %.3f\n" % shader_rect.camera_position
	text += "rotation_time: %.3f\n" % shader_rect.rotation_time
	text += "fly_speed: %.3f\n" % shader_rect.fly_speed
	text += "contrast: %.3f\n\n" % shader_rect.contrast
	
	text += "--- PATTERN ---\n"
	text += "kaleidoscope_segments: %.1f\n" % shader_rect.kaleidoscope_segments
	text += "truchet_radius: %.3f\n" % shader_rect.truchet_radius
	text += "center_fill_radius: %.3f\n" % shader_rect.center_fill_radius
	text += "zoom_level: %.3f\n" % shader_rect.zoom_level
	
	return text

func get_computed_debug_text() -> String:
	"""Computed values"""
	var text = "--- CAMERA VECTORS ---\n"
	text += "offset: %s\n" % str(shader_rect.current_offset)
	text += "forward: %s\n" % str(shader_rect.camera_forward)
	text += "right: %s\n" % str(shader_rect.camera_right)
	text += "up: %s\n\n" % str(shader_rect.camera_up)
	
	text += "--- COORDINATE CHAIN ---\n"
	text += "original_p: %s\n" % str(shader_rect.original_p)
	text += "post_kaleidoscope: %s\n" % str(shader_rect.post_kaleidoscope_p)
	text += "final_truchet: %s\n" % str(shader_rect.final_truchet_p)
	
	return text

func get_simulation_debug_text() -> String:
	"""Simulation results"""
	var text = "--- TRUCHET RESULTS ---\n"
	text += "distance: %.3f\n" % shader_rect.truchet_distance
	text += "circle_dist: %.3f\n" % shader_rect.truchet_circle_distance
	text += "center_factor: %.3f\n\n" % shader_rect.truchet_center_factor
	
	text += "--- CENTER FILL ---\n"
	text += "original_distance: %.3f\n" % shader_rect.center_distance
	text += "fill_radius: %.3f\n" % shader_rect.center_fill_radius
	text += "edge_factor: %.3f\n" % str(shader_rect.center_edge)
	
	text += "\nPress [F] to run simulation"
	
	return text

func toggle_debug_display():
	"""Toggle debug text and background"""
	show_debug = !show_debug
	refresh_debug_display()
	
	# Also toggle the background visibility
	debug_menu_background.visible = show_debug
	debug_menu.visible = show_debug
	
	show_parameter_popup("Debug: %s" % ("ON" if show_debug else "OFF"))

# === PARAMETER CONTROLS ===

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
