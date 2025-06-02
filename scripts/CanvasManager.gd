extends ColorRect
# This script gets attached to your ColorRect node

# Signal to communicate with main
signal update_text(text: String)

# Component managers
var parameter_manager: ParameterManager
var color_palette_manager: ColorPaletteManager
var shader_controller: ShaderController
var screenshot_manager: ScreenshotManager
var timeline_component: TimelineComponent

# References
var shader_material: ShaderMaterial
var audio_manager: AudioManager

var camera_position = 0.0  # Current camera position along the path
var accumulated_rotation = 0.0  # Accumulated rotation angle
var accumulated_plane_rotation = 0.0  # Accumulated plane rotation angle
var accumulated_color_time = 0.0  # Accumulated color cycling time

# Store original palette data to avoid re-fetching
var current_original_palette: Dictionary = {}

var song_settings: SongSettings
var current_popup_label: RichTextLabel = null
var current_popup_background: ColorRect = null

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
	
	# Load custom song settings
	song_settings = SongSettings.new()
	print("DEBUG: Created song_settings with ID: %s" % str(song_settings.get_instance_id()))

	song_settings.connect_managers(parameter_manager, color_palette_manager, audio_manager)
	
	import_labels()
	print("DEBUG: After import - song_settings ID: %s, checkpoints: %d" % [str(song_settings.get_instance_id()), song_settings.checkpoints.size()])
	
	song_settings.checkpoint_reached.connect(on_checkpoint_reached)
	print("DEBUG: CanvasManager._ready() finished - final song_settings ID: %s" % str(song_settings.get_instance_id()))

	# Initial setup
	shader_controller.update_all_parameters(parameter_manager.get_all_parameters())
	color_palette_manager.emit_current_palette()

func import_labels():
	print("DEBUG: import_labels() called")
	var success = song_settings.import_audacity_labels("res://assets/Lyrics.txt")
	if success:
		print("DEBUG: import_labels - checkpoints after import: %d" % song_settings.checkpoints.size())
		update_text.emit("Imported %d checkpoints from labels" % song_settings.checkpoints.size())
	else:
		update_text.emit("Failed to import labels")
		
func on_checkpoint_reached(timestamp: float, checkpoint_name: String):
	"""Called when we reach a checkpoint during playback"""
	print("DEBUG: on_checkpoint_reached - Time: %.2fs, Name: '%s'" % [timestamp, checkpoint_name])
	show_checkpoint_popup(checkpoint_name)
		
func jump_to_previous_checkpoint():
	if not song_settings or not audio_manager:
		update_text.emit("Song settings or audio not available")
		return
	
	var current_time = audio_manager.get_playback_position()
	var target_checkpoint = null
	
	# Find the previous checkpoint (before current time)
	for i in range(song_settings.checkpoints.size() - 1, -1, -1):
		var checkpoint = song_settings.checkpoints[i]
		if checkpoint.timestamp < current_time - 0.5:  # 0.5s buffer
			target_checkpoint = checkpoint
			break
	
	if target_checkpoint:
		audio_manager.seek(target_checkpoint.timestamp)
		show_checkpoint_popup(target_checkpoint.name)
		update_text.emit("◀ %.1fs - %s" % [target_checkpoint.timestamp, target_checkpoint.name])
	else:
		# Jump to beginning if no previous checkpoint
		audio_manager.seek(0.0)
		update_text.emit("◀ Jumped to beginning")

func jump_to_next_checkpoint():
	print("DEBUG: jump_to_next_checkpoint called")
	if not song_settings or not audio_manager:
		update_text.emit("Song settings or audio not available")
		return
	
	var current_time = audio_manager.get_playback_position()
	print("DEBUG: Current time: %.2fs, Total checkpoints: %d" % [current_time, song_settings.checkpoints.size()])
	
	var target_checkpoint = null
	
	# Find the next checkpoint (after current time)
	for i in range(song_settings.checkpoints.size()):
		var checkpoint = song_settings.checkpoints[i]
		print("DEBUG: Checking checkpoint %d: %.2fs - '%s'" % [i, checkpoint.timestamp, checkpoint.name])
		if checkpoint.timestamp > current_time + 0.5:  # 0.5s buffer
			target_checkpoint = checkpoint
			print("DEBUG: Found next checkpoint: %.2fs - '%s'" % [checkpoint.timestamp, checkpoint.name])
			break
	
	if target_checkpoint:
		audio_manager.seek(target_checkpoint.timestamp)
		show_checkpoint_popup(target_checkpoint.name)
		update_text.emit("▶ %.1fs - %s" % [target_checkpoint.timestamp, target_checkpoint.name])
	else:
		print("DEBUG: No checkpoint found after time %.2fs" % (current_time + 0.5))
		update_text.emit("▶ No more checkpoints ahead")
		
func show_checkpoint_popup(checkpoint_text: String):
	# """Show a popup with the checkpoint text"""
	# print("DEBUG: Checkpoint '%s'" % checkpoint_text)
	
	# Remove any existing popup first
	if current_popup_label:
		current_popup_label.queue_free()
		current_popup_label = null
	if current_popup_background:
		current_popup_background.queue_free()
		current_popup_background = null
	
	# Create a temporary label for the popup
	var popup_label = RichTextLabel.new()
	popup_label.text = checkpoint_text
	popup_label.bbcode_enabled = false
	popup_label.add_theme_color_override("default_color", Color.WHITE)
	popup_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Add to scene first so we can measure it
	add_child(popup_label)
	
	# Wait one frame for the label to calculate its content size
	await get_tree().process_frame
	
	# Get the actual content size
	var content_size = popup_label.get_content_height()
	var text_width = popup_label.get_theme_font("normal_font").get_string_size(
		checkpoint_text, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		popup_label.get_theme_font_size("normal_font_size")
	).x
	
	# Set label size to fit content with some padding
	var padding = Vector2(20, 10)
	popup_label.size = Vector2(text_width + padding.x, content_size + padding.y)
	
	# Position at bottom center of screen
	var viewport_size = get_viewport().get_visible_rect().size
	popup_label.position = Vector2(
		viewport_size.x / 2 - popup_label.size.x / 2,
		viewport_size.y - 50 - popup_label.size.y
	)
	
	# Create background sized to match label
	var background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.8)
	background.position = popup_label.position
	background.size = popup_label.size
	
	# Add background behind the label
	add_child(background)
	move_child(background, popup_label.get_index())
	
	# Store references to current popup
	current_popup_label = popup_label
	current_popup_background = background
	
	# Auto-remove after 2 seconds (but only if it's still the current popup)
	await get_tree().create_timer(2.0).timeout
	if current_popup_label == popup_label:  # Only remove if this is still the current popup
		current_popup_label.queue_free()
		current_popup_background.queue_free()
		current_popup_label = null
		current_popup_background = null
func on_timeline_seek(timestamp: float):
	if audio_manager:
		audio_manager.seek(timestamp)
		update_text.emit("Seeked to: %s" % format_timeline_time(timestamp))

func format_timeline_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
	

func setup_shader_material():
	if material == null:
		print("ERROR: ColorRect has no material assigned!")
		var new_material = ShaderMaterial.new()
		var shader = load("res://shaders/kaldao.gdshader")
		new_material.shader = shader
		material = new_material
	shader_material = material

func connect_components():
	# Connect parameter manager to shader controller
	parameter_manager.parameter_changed.connect(shader_controller.update_parameter)
	
	# Connect color palette manager
	color_palette_manager.palette_changed.connect(_on_palette_changed)
	color_palette_manager.invert_changed.connect(_on_invert_changed)
	
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
	
	# Connect audio to parameter manager
	audio_manager.connect_to_parameter_manager(parameter_manager)
	
	# Connect to audio signals for debugging
	audio_manager.bass_detected.connect(on_bass_detected)
	audio_manager.mid_detected.connect(on_mid_detected)
	audio_manager.treble_detected.connect(on_treble_detected)
	audio_manager.beat_detected.connect(on_beat_detected)
	
	# Connect finished signal for looping
	audio_manager.finished.connect(audio_manager._on_finished)
	
	print("Audio manager connected successfully")

func on_bass_detected(intensity: float):
	# Optional visual feedback
	if intensity > 999.01:
		print("DEBUG: Bass detected: %.3f" % intensity)

func on_mid_detected(intensity: float):
	# Optional visual feedback
	if intensity > 999.01:
		print("DEBUG: Mid detected: %.3f" % intensity)

func on_treble_detected(intensity: float):
	# Optional visual feedback
	if intensity > 999.01:
		print("DEBUG: Treble detected: %.3f" % intensity)

func on_beat_detected():
	# Optional visual feedback
	print("DEBUG: Beat detected!")

# Public API methods that other scripts can call
func increase_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_forward()
	else:
		parameter_manager.increase_current_parameter()
	emit_current_parameter_info()

func decrease_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_backward()
	else:
		parameter_manager.decrease_current_parameter()
	emit_current_parameter_info()

func next_setting():
	parameter_manager.next_parameter()
	emit_current_parameter_info()

func previous_setting():
	parameter_manager.previous_parameter()
	emit_current_parameter_info()

func reset_current_setting():
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.reset_to_bw()
		update_text.emit("Reset Color Palette to default: B&W")
	else:
		parameter_manager.reset_current_parameter()
		var param_value = parameter_manager.get_parameter_value(param_name)
		update_text.emit("Reset %s to default: %.2f" % [param_name, param_value])

func reset_all_settings():
	parameter_manager.reset_all_parameters()
	color_palette_manager.reset_to_bw()
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

func toggle_audio_playback():
	"""Toggle audio playback on/off"""
	if audio_manager:
		var is_playing = audio_manager.toggle_audio_playback()
		var status = "ON" if is_playing else "OFF"
		update_text.emit("Audio Playback: %s" % status)
	else:
		update_text.emit("Audio not available")

func toggle_audio_reactive():
	"""Toggle audio reactivity on/off"""
	if audio_manager:
		var is_reactive = audio_manager.toggle_audio_reactive()
		var status = "ON" if is_reactive else "OFF"
		update_text.emit("Audio Reactive: %s" % status)
		
		if is_reactive:
			update_text.emit("Audio Reactive: %s\nVisuals now respond to the music!" % status)
	else:
		update_text.emit("Audio not available")

func save_settings():
	var settings_data = {
		"parameters": parameter_manager.get_all_parameters(),
		"palette": color_palette_manager.save_palette_data(),
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	# Save to BOTH timestamped file (archive) AND quick-save file (for Ctrl+L)
	var time_dict = Time.get_datetime_dict_from_system()
	var timestamped_filename = "fractal_settings_%04d%02d%02d_%02d%02d%02d.json" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]
	
	var quick_save_filename = "fractal_settings_current.json"  # Fixed filename for quick load
	var archive_filename = timestamped_filename  # Timestamped for archive
	
	var json_string = JSON.stringify(settings_data, "\t")
	
	# Save the timestamped archive copy
	var archive_path = "res://data/config/" + archive_filename
	var archive_file = FileAccess.open(archive_path, FileAccess.WRITE)
	var archive_success = false
	
	if archive_file:
		archive_file.store_string(json_string)
		archive_file.close()
		archive_success = true
		print("Settings archived to: ", ProjectSettings.globalize_path(archive_path))
	
	# Save the quick-save copy (overwrites previous)
	var quick_save_path = "res://data/config/" + quick_save_filename
	var quick_save_file = FileAccess.open(quick_save_path, FileAccess.WRITE)
	var quick_save_success = false
	
	if quick_save_file:
		quick_save_file.store_string(json_string)
		quick_save_file.close()
		quick_save_success = true
		print("Settings quick-saved to: ", ProjectSettings.globalize_path(quick_save_path))
	
	# Report results to user
	if archive_success and quick_save_success:
		var absolute_archive_path = ProjectSettings.globalize_path(archive_path)
		update_text.emit("Settings saved!\nArchive: %s\nQuick-save ready for Ctrl+L" % timestamped_filename)
		print("Both saves successful. Config directory: res://data/config/")
	elif quick_save_success:
		update_text.emit("Quick-save successful!\nCtrl+L will restore these settings\n(Archive save failed)")
	elif archive_success:
		update_text.emit("Archive save successful!\n(Quick-save failed - Ctrl+L may not work)")
	else:
		print("ERROR: Both save operations failed!")
		update_text.emit("ERROR: Could not save settings!")

func load_settings():
	# Try to load from the quick-save file first (most recent Ctrl+S save)
	var quick_save_path = "res://data/config/fractal_settings_current.json"
	var file = FileAccess.open(quick_save_path, FileAccess.READ)
	
	var source_description = ""
	
	if not file:
		# Fallback to the old fixed filename for backwards compatibility
		var legacy_path = "res://data/config/fractal_settings.json"
		file = FileAccess.open(legacy_path, FileAccess.READ)
		source_description = "legacy fractal_settings.json"
		
		if not file:
			# Final fallback to user:// directory for existing saves
			legacy_path = "user://fractal_settings.json"
			file = FileAccess.open(legacy_path, FileAccess.READ)
			source_description = "user:// legacy file"
			
			if not file:
				update_text.emit("No saved settings found.\nUse Ctrl+S to save current settings.")
				return
	else:
		source_description = "most recent Ctrl+S save"
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		var save_data = json.data
		
		# Validate the save data has the expected structure
		if not ("parameters" in save_data):
			update_text.emit("Error: Invalid settings file format")
			return
		
		# Load all parameter values
		var loaded_count = 0
		var parameters = parameter_manager.get_all_parameters()
		
		# Load individual parameter values from the nested structure
		for param_name in parameters:
			if param_name in save_data["parameters"]:
				var param_data = save_data["parameters"][param_name]
				if typeof(param_data) == TYPE_DICTIONARY and "current" in param_data:
					# New format: parameter data contains min/max/current/etc
					parameter_manager.set_parameter_value(param_name, param_data["current"])
					loaded_count += 1
				elif typeof(param_data) == TYPE_FLOAT or typeof(param_data) == TYPE_INT:
					# Legacy format: parameter data is just the value
					parameter_manager.set_parameter_value(param_name, param_data)
					loaded_count += 1
		
		# Load color palette data if present
		if "palette" in save_data:
			color_palette_manager.load_palette_data(save_data["palette"])
		
		# Show success message with timestamp if available
		var timestamp_info = ""
		if "timestamp" in save_data:
			timestamp_info = "\nSaved: %s" % save_data["timestamp"]
		
		update_text.emit("Settings loaded from %s\n%d parameters restored%s" % [
			source_description, 
			loaded_count,
			timestamp_info
		])
		
		print("Load successful - %d parameters loaded from %s" % [loaded_count, source_description])
	else:
		update_text.emit("Error: Could not parse settings file")
		print("JSON parse error: ", json.error_string)

func get_all_settings_text():
	var audio_info = ""
	if audio_manager:
		var status_info = audio_manager.get_status_info()
		audio_info = "Audio File: KOCH5.wav\nPlayback: %s\nReactive: %s\nPosition: %.1fs / %.1fs\nLevels - Bass: %.2f Mid: %.2f Treble: %.2f" % [
			"ON" if status_info.enabled else "OFF",
			"ON" if status_info.reactive else "OFF",
			status_info.position,
			status_info.duration,
			status_info.levels.bass, 
			status_info.levels.mid, 
			status_info.levels.treble
		]
	
	var base_text = parameter_manager.get_formatted_settings_text(audio_info)
	var palette_text = "Color Palette: %s\n" % color_palette_manager.get_current_palette_name()
	
	return base_text + palette_text

func emit_current_parameter_info():
	"""Helper function to emit current parameter information"""
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

func import_audacity_labels():
	# You can also use a file dialog here
	var success = song_settings.import_audacity_labels("res://koch5_labels.txt")
	if success:
		update_text.emit("Imported checkpoints from Audacity labels")
	else:
		update_text.emit("Failed to import Audacity labels")

func export_audacity_labels():
	var file_path = "user://exported_labels.txt"
	var success = song_settings.export_to_audacity_labels(file_path)
	if success:
		var absolute_path = ProjectSettings.globalize_path(file_path)
		update_text.emit("Exported labels to: %s" % absolute_path)

func toggle_color_invert():
	"""Toggle color inversion for any palette"""
	print("DEBUG: toggle_color_invert called")
	color_palette_manager.toggle_invert()
	var palette_name = color_palette_manager.get_current_palette_name()
	update_text.emit("Color Invert Toggled\n%s" % palette_name)
	
# Handle invert changes (simple shader inversion for everything)
func _on_invert_changed(should_invert: bool):
	"""Handle invert toggle - simple shader inversion for all palettes"""
	print("DEBUG: _on_invert_changed called with: ", should_invert)
	
	if not shader_material:
		print("DEBUG: ERROR - No shader_material available!")
		return
	
	# Use simple shader inversion for everything (B&W and color palettes)
	shader_material.set_shader_parameter("invert_colors", should_invert)
	print("DEBUG: Shader inversion set to: ", should_invert)

# Helper function to apply palette to shader
func _apply_palette_to_shader(palette_data: Dictionary, use_palette: bool, should_invert: bool):
	"""Apply palette to shader with optional inversion"""
	if not shader_material:
		return
	
	var final_a = palette_data["a"]
	var final_b = palette_data["b"]
	var final_c = palette_data["c"] 
	var final_d = palette_data["d"]
	
	if use_palette and should_invert:
		# Invert color palette coefficients
		final_a = Vector3(1.0, 1.0, 1.0) - final_a
		final_b = -final_b
		shader_material.set_shader_parameter("invert_colors", false)
		print("DEBUG: Applied inverted color palette")
	elif not use_palette and should_invert:
		# B&W inversion via shader
		shader_material.set_shader_parameter("invert_colors", true)
		print("DEBUG: Applied B&W inversion via shader")
	else:
		# Normal palette or B&W
		shader_material.set_shader_parameter("invert_colors", false)
		print("DEBUG: Applied normal palette")
	
	# Set all shader parameters
	shader_material.set_shader_parameter("use_color_palette", use_palette)
	shader_material.set_shader_parameter("palette_a", final_a)
	shader_material.set_shader_parameter("palette_b", final_b)
	shader_material.set_shader_parameter("palette_c", final_c)
	shader_material.set_shader_parameter("palette_d", final_d)

# Handle palette changes (just apply normally)
func _on_palette_changed(palette_data: Dictionary, use_palette: bool):
	"""Handle color palette changes"""
	if not shader_material:
		return
	
	# Just apply the palette normally - inversion handled separately
	shader_material.set_shader_parameter("use_color_palette", use_palette)
	shader_material.set_shader_parameter("palette_a", palette_data["a"])
	shader_material.set_shader_parameter("palette_b", palette_data["b"])
	shader_material.set_shader_parameter("palette_c", palette_data["c"])
	shader_material.set_shader_parameter("palette_d", palette_data["d"])
	
	print("DEBUG: Applied palette: ", palette_data["name"] if "name" in palette_data else "Custom")
	
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
	
	# Send all the accumulated values to the shader
	shader_controller.update_parameter("camera_position", camera_position)
	shader_controller.update_parameter("rotation_time", accumulated_rotation)
	shader_controller.update_parameter("plane_rotation_time", accumulated_plane_rotation)
	shader_controller.update_parameter("color_time", accumulated_color_time)
	
	if song_settings:
		song_settings.process_song_sync(delta)
