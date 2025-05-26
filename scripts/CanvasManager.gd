extends ColorRect
# This script gets attached to your ColorRect node

# Signal to communicate with main
signal update_text(text: String)

# Component managers
var parameter_manager: ParameterManager
var color_palette_manager: ColorPaletteManager
var shader_controller: ShaderController
var screenshot_manager: ScreenshotManager

# References
var shader_material: ShaderMaterial
var audio_manager: AudioManager

var camera_position = 0.0  # Current camera position along the path
var accumulated_rotation = 0.0  # Accumulated rotation angle
var accumulated_plane_rotation = 0.0  # Accumulated plane rotation angle
var accumulated_color_time = 0.0  # Accumulated color cycling time

func _ready():
	# Initialize shader material
	setup_shader_material()
	
	# Initialize component managers
	parameter_manager = ParameterManager.new()
	color_palette_manager = ColorPaletteManager.new()
	shader_controller = ShaderController.new(shader_material)
	screenshot_manager = ScreenshotManager.new()
	
	# Make ColorRect fill the entire window and auto-resize
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Force it to fill parent and auto-resize
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Connect components
	connect_components()
	
	# Setup audio
	setup_audio_manager()
	
	# Initial setup
	shader_controller.update_all_parameters(parameter_manager.get_all_parameters())
	color_palette_manager.emit_current_palette()
	update_parameter_display()

func setup_shader_material():
	if material == null:
		print("ERROR: ColorRect has no material assigned!")
		var new_material = ShaderMaterial.new()
		var shader = load("res://kaldao.gdshader")  # Updated path
		new_material.shader = shader
		material = new_material
	shader_material = material

func connect_components():
	# Connect parameter manager to shader controller
	parameter_manager.parameter_changed.connect(shader_controller.update_parameter)
	
	# Connect color palette manager
	color_palette_manager.palette_changed.connect(shader_controller.update_color_palette)
	
	# Connect screenshot manager
	screenshot_manager.screenshot_taken.connect(on_screenshot_taken)
	screenshot_manager.screenshot_failed.connect(on_screenshot_failed)

func setup_audio_manager():
	# Find the AudioManager node
	var root_node = get_tree().current_scene
	audio_manager = root_node.get_node("AudioStreamPlayer") as AudioManager
	
	if audio_manager == null:
		print("ERROR: AudioManager node not found! Make sure AudioStreamPlayer node exists with AudioManager.gd script")
		return
	
	# Connect audio reactivity to parameter manager
	if audio_manager.audio_reactivity:
		audio_manager.audio_reactivity.connect_to_parameter_manager(parameter_manager)
		print("AudioReactivityManager connected to ParameterManager")
	
	# Connect to audio device change signals
	audio_manager.device_changed.connect(on_audio_device_changed)
	
	# Connect audio detection signals for visual feedback
	audio_manager.bass_detected.connect(on_bass_detected)
	audio_manager.mid_detected.connect(on_mid_detected)
	audio_manager.treble_detected.connect(on_treble_detected)
	audio_manager.beat_detected.connect(on_beat_detected)
	
	print("Audio manager connected successfully")

func on_audio_device_changed(device_name: String, is_input: bool):
	var device_type = "Input" if is_input else "Output"
	update_text.emit("Audio device: %s" % device_name)

func on_bass_detected(intensity: float):
	# Visual feedback for bass detection (optional)
	if intensity > 0.01:  # Show even small bass
		print("DEBUG: Bass detected: %.3f" % intensity)

func on_mid_detected(intensity: float):
	# Visual feedback for mid frequency detection (optional)
	if intensity > 0.01:
		print("DEBUG: Mid detected: %.3f" % intensity)

func on_treble_detected(intensity: float):
	# Visual feedback for treble detection (optional)
	if intensity > 0.01:
		print("DEBUG: Treble detected: %.3f" % intensity)

func on_beat_detected():
	# Visual feedback for beat detection (optional)
	print("DEBUG: Beat detected!")

# Public API methods that other scripts can call
func increase_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_forward()
	else:
		parameter_manager.increase_current_parameter()
	update_parameter_display()

func decrease_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_backward()
	else:
		parameter_manager.decrease_current_parameter()
	update_parameter_display()

func next_setting():
	parameter_manager.next_parameter()
	update_parameter_display()

func previous_setting():
	parameter_manager.previous_parameter()
	update_parameter_display()

func reset_current_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.reset_to_bw()
		update_text.emit("Reset Color Palette to default: B&W")
	else:
		parameter_manager.reset_current_parameter()
		var param_value = parameter_manager.get_parameter_value(param_name)
		update_text.emit("Reset %s to default: %.2f" % [param_name, param_value])
	update_parameter_display()

func reset_all_settings():
	parameter_manager.reset_all_parameters()
	color_palette_manager.reset_to_bw()
	update_parameter_display()
	update_text.emit("All settings reset to defaults")

func toggle_pause():
	print("DEBUG: CanvasManager.toggle_pause() called")
	parameter_manager.toggle_pause()
	
	# Provide user feedback about pause state
	if parameter_manager.get_is_paused():
		update_text.emit("Animation: PAUSED")
	else:
		update_text.emit("Animation: RESUMED")
	
	print("DEBUG: Pause toggled - new status: ", "PAUSED" if parameter_manager.get_is_paused() else "RESUMED")

func take_screenshot():
	screenshot_manager.capture_screenshot(get_viewport())

func randomize_parameters():
	print("DEBUG: CanvasManager - Randomizing all non-color parameters")
	parameter_manager.randomize_non_color_parameters()
	
	# Show user feedback
	update_text.emit("Randomized all parameters!\n[C] for colors  [.] for parameters again")
	
func randomize_colors():
	color_palette_manager.randomize_colors()
	update_text.emit("Colors randomized! Use Shift+C to reset to B&W")

func reset_colors_to_bw():
	color_palette_manager.reset_to_bw()
	update_text.emit("Colors reset to Black & White")

func toggle_audio_reactive():
	if audio_manager and audio_manager.audio_reactivity:
		var is_active = audio_manager.audio_reactivity.toggle_audio_reactive()
		var status = "ON" if is_active else "OFF"
		update_text.emit("Audio Reactive: %s" % status)
		
		# Also show current audio levels for debugging
		if is_active and audio_manager:
			var levels = audio_manager.get_audio_levels()
			print("DEBUG: Audio levels - Bass: %.3f, Mid: %.3f, Treble: %.3f" % [levels.bass, levels.mid, levels.treble])
	else:
		update_text.emit("Audio system not available")

func cycle_audio_device():
	if audio_manager:
		audio_manager.cycle_input_device()
		# Show current device info
		update_text.emit(audio_manager.get_current_audio_device_info())
	else:
		update_text.emit("Audio not available")

func cycle_output_device():
	"""Cycle through output devices"""
	if audio_manager:
		audio_manager.cycle_output_device()
		# Show current device info
		var output_device = audio_manager.get_current_output_device()
		update_text.emit("Output device: %s" % output_device)
	else:
		update_text.emit("Audio not available")

func toggle_audio_processing():
	"""Toggle the audio processing on/off (separate from reactivity)"""
	if audio_manager:
		var is_enabled = audio_manager.toggle_audio_processing()
		var status = "ON" if is_enabled else "OFF"
		update_text.emit("Audio Processing: %s" % status)
	else:
		update_text.emit("Audio not available")

func save_settings():
	var settings_data = {
		"parameters": parameter_manager.get_all_parameters(),
		"palette": color_palette_manager.save_palette_data(),
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	# Generate filename with timestamp for uniqueness
	var time_dict = Time.get_datetime_dict_from_system()
	var filename = "fractal_settings_%04d%02d%02d_%02d%02d%02d.json" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]
	
	var file_path = "user://" + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(settings_data, "\t")
		file.store_string(json_string)
		file.close()
		
		# Convert to absolute path for user display
		var absolute_path = ProjectSettings.globalize_path(file_path)
		
		print("Settings saved to: ", absolute_path)
		update_text.emit("Settings saved to:\n" + absolute_path)
		
		# Also print the user:// location info for debugging
		print("Godot user:// directory: ", OS.get_user_data_dir())
	else:
		print("ERROR: Could not create settings file!")
		update_text.emit("ERROR: Could not save settings!")

func load_settings():
	var file = FileAccess.open("user://fractal_settings.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var save_data = json.data
			
			# Load all parameter values
			var parameters = parameter_manager.get_all_parameters()
			for param_name in parameters:
				if param_name in save_data:
					parameter_manager.set_parameter_value(param_name, save_data[param_name])
			
			# Load color palette data
			color_palette_manager.load_palette_data(save_data)
			
			# Load audio settings
			if audio_manager and "audio_reactive" in save_data:
				var should_be_reactive = save_data["audio_reactive"]
				var current_reactive = audio_manager.is_audio_reactive()
				if should_be_reactive != current_reactive:
					audio_manager.toggle_audio_reactive()
			
			update_parameter_display()
			update_text.emit("Settings loaded from user://fractal_settings.json")
		else:
			update_text.emit("Error: Could not parse settings file")
	else:
		update_text.emit("No saved settings file found")

func get_all_settings_text():
	var audio_info = ""
	if audio_manager:
		var reactive_status = "OFF"
		if audio_manager.is_audio_reactive():
			reactive_status = "ON"
		
		# Show current audio levels for debugging
		var levels = audio_manager.get_audio_levels()
		audio_info = "Audio Reactive: %s\n%s\nLevels - Bass: %.2f Mid: %.2f Treble: %.2f" % [
			reactive_status, 
			audio_manager.get_current_audio_device_info(),
			levels.bass, levels.mid, levels.treble
		]
	
	var base_text = parameter_manager.get_formatted_settings_text(audio_info)
	var palette_text = "Color Palette: %s\n" % color_palette_manager.get_current_palette_name()
	
	return base_text + palette_text

func update_parameter_display():
	var param_name = parameter_manager.get_current_parameter_name()
	var display_text = ""
	
	if param_name == "color_palette":
		display_text = color_palette_manager.get_current_palette_display()
	else:
		display_text = parameter_manager.get_current_parameter_display()
	
	if display_text != "":
		update_text.emit(display_text)

func on_screenshot_taken(file_path: String):
	update_text.emit("Screenshot saved to:\n%s" % file_path)

func on_screenshot_failed(error_message: String):
	update_text.emit(error_message)

func _process(delta):
	# Update camera position based on fly_speed
	var current_fly_speed = parameter_manager.get_parameter_value("fly_speed")
	camera_position += current_fly_speed * delta
	
	# Update accumulated rotations based on their speeds
	var current_rotation_speed = parameter_manager.get_parameter_value("rotation_speed")
	accumulated_rotation += current_rotation_speed * delta
	
	var current_plane_rotation_speed = parameter_manager.get_parameter_value("plane_rotation_speed")
	accumulated_plane_rotation += current_plane_rotation_speed * delta
	
	var current_color_speed = parameter_manager.get_parameter_value("color_speed")
	accumulated_color_time += current_color_speed * delta
	
	# Process audio reactivity manager (for beat timing)
	if audio_manager and audio_manager.audio_reactivity:
		audio_manager.audio_reactivity._process(delta)
	
	# Send all the accumulated values to the shader
	shader_controller.update_parameter("camera_position", camera_position)
	shader_controller.update_parameter("rotation_time", accumulated_rotation)
	shader_controller.update_parameter("plane_rotation_time", accumulated_plane_rotation)
	shader_controller.update_parameter("color_time", accumulated_color_time)
