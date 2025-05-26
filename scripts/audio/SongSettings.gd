# SongSettings.gd - Song-synced parameter automation for music videos
extends RefCounted
class_name SongSettings

# Signals
signal checkpoint_reached(timestamp: float, checkpoint_name: String)
signal transition_started(from_checkpoint: String, to_checkpoint: String, duration: float)
signal transition_completed(checkpoint_name: String)

# References
var parameter_manager: ParameterManager
var color_palette_manager: ColorPaletteManager
var audio_manager: AudioManager

# Song sync data
var song_duration: float = 0.0
var checkpoints: = []
var current_checkpoint_index: int = -1
var next_checkpoint_index: int = -1

# Transition state
var is_transitioning: bool = false
var transition_start_time: float = 0.0
var transition_duration: float = 0.0
var transition_from_settings: Dictionary = {}
var transition_to_settings: Dictionary = {}

# Interpolation curves - these affect how smooth transitions feel
enum TransitionCurve {
	LINEAR,     # Constant speed
	EASE_IN,    # Slow start, fast end
	EASE_OUT,   # Fast start, slow end  
	EASE_IN_OUT, # Slow start and end, fast middle
	BOUNCE      # Overshoot and settle
}

func _init():
	setup_default_song_structure()

func connect_managers(param_mgr: ParameterManager, color_mgr: ColorPaletteManager, audio_mgr: AudioManager):
	"""Connect to the main system managers"""
	parameter_manager = param_mgr
	color_palette_manager = color_mgr
	audio_manager = audio_mgr
	
	if audio_manager and audio_manager.stream:
		song_duration = audio_manager.stream.get_length()
		print("SongSettings: Connected to audio, song duration: %.1f seconds" % song_duration)
	
	print("SongSettings: Connected to parameter and color managers")

func setup_default_song_structure():
	"""Setup empty checkpoints array - use import_audacity_labels() to load from Audacity"""
	checkpoints = []
	print("SongSettings: Empty checkpoints array initialized. Use import_audacity_labels() to load from Audacity.")

func update_sync(current_time: float):
	"""Call this every frame with the current audio playback time"""
	if not audio_manager or not audio_manager.playing:
		return
	
	# Check if we've reached a new checkpoint
	check_for_checkpoint_triggers(current_time)
	
	# Update any active transitions
	update_transitions(current_time)

func check_for_checkpoint_triggers(current_time: float):
	"""Check if we need to trigger a new checkpoint transition"""
	for i in range(checkpoints.size()):
		var checkpoint = checkpoints[i]
		var timestamp = checkpoint.timestamp
		
		# Check if we've just passed this checkpoint (within 0.1 seconds)
		if abs(current_time - timestamp) < 0.1 and i != current_checkpoint_index:
			current_checkpoint_index = i
			checkpoint_reached.emit(timestamp, checkpoint.name)
			break

func trigger_checkpoint_transition(checkpoint_index: int, current_time: float):
	"""Start transitioning to a new checkpoint"""
	var checkpoint = checkpoints[checkpoint_index]
	
	# Store current state as transition starting point
	if parameter_manager:
		transition_from_settings = get_current_parameter_values()
	
	# Set up transition
	current_checkpoint_index = checkpoint_index
	transition_to_settings = checkpoint.settings
	transition_duration = checkpoint.transition_duration
	transition_start_time = current_time
	
	if transition_duration > 0.0:
		is_transitioning = true
		transition_started.emit(
			checkpoints[checkpoint_index - 1].name if checkpoint_index > 0 else "Start",
			checkpoint.name,
			transition_duration
		)
		print("SongSettings: Starting transition to '%s' over %.1fs" % [checkpoint.name, transition_duration])
	else:
		# Instant transition
		apply_settings_immediately(checkpoint.settings)
		is_transitioning = false
		transition_completed.emit(checkpoint.name)
	
	checkpoint_reached.emit(checkpoint.timestamp, checkpoint.name)

func update_transitions(current_time: float):
	"""Update active parameter transitions"""
	if not is_transitioning:
		return
	
	var elapsed = current_time - transition_start_time
	var progress = elapsed / transition_duration
	
	if progress >= 1.0:
		# Transition complete
		apply_settings_immediately(transition_to_settings)
		is_transitioning = false
		var checkpoint = checkpoints[current_checkpoint_index]
		transition_completed.emit(checkpoint.name)
		print("SongSettings: Completed transition to '%s'" % checkpoint.name)
		return
	
	# Apply interpolated values
	var checkpoint = checkpoints[current_checkpoint_index]
	var curve_type = checkpoint.get("transition_curve", TransitionCurve.LINEAR)
	var curved_progress = apply_curve(progress, curve_type)
	
	interpolate_and_apply_settings(curved_progress)

func apply_curve(progress: float, curve_type: TransitionCurve) -> float:
	"""Apply easing curves to transition progress"""
	match curve_type:
		TransitionCurve.LINEAR:
			return progress
		TransitionCurve.EASE_IN:
			return progress * progress
		TransitionCurve.EASE_OUT:
			return 1.0 - (1.0 - progress) * (1.0 - progress)
		TransitionCurve.EASE_IN_OUT:
			if progress < 0.5:
				return 2.0 * progress * progress
			else:
				return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
		TransitionCurve.BOUNCE:
			# Simple bounce effect - overshoot then settle
			if progress < 0.8:
				var t = progress / 0.8
				return t * t * (2.2 * t - 1.2)  # Overshoot
			else:
				var t = (progress - 0.8) / 0.2
				return 1.0 + (1.0 - t) * 0.1 * sin(t * PI * 4)  # Settle
		_:
			return progress

func interpolate_and_apply_settings(progress: float):
	"""Interpolate between current and target settings and apply them"""
	if not parameter_manager:
		return
	
	for param_name in transition_to_settings:
		if param_name == "color_palette_index":
			# Handle color palette transitions specially
			handle_color_palette_transition(param_name, progress)
		else:
			# Handle regular parameter interpolation
			var from_value = transition_from_settings.get(param_name, 0.0)
			var to_value = transition_to_settings[param_name]
			var interpolated_value = lerp(from_value, to_value, progress)
			
			# Special handling for kaleidoscope segments - ensure even values
			if param_name == "kaleidoscope_segments":
				interpolated_value = round(interpolated_value / 2.0) * 2.0
				interpolated_value = clamp(interpolated_value, 4.0, 80.0)
			
			parameter_manager.set_parameter_value(param_name, interpolated_value)

func handle_color_palette_transition(param_name: String, progress: float):
	"""Handle color palette transitions (can be instant or gradual)"""
	if not color_palette_manager:
		return
	
	var target_index = int(transition_to_settings[param_name])
	
	# For now, do instant palette changes at 50% progress
	# You could make this more sophisticated with custom palette blending
	if progress >= 0.5 and color_palette_manager.current_palette_index != target_index:
		color_palette_manager.current_palette_index = target_index
		color_palette_manager.emit_current_palette()

func apply_settings_immediately(settings: Dictionary):
	"""Apply all settings instantly without interpolation"""
	if not parameter_manager:
		return
	
	for param_name in settings:
		if param_name == "color_palette_index":
			if color_palette_manager:
				color_palette_manager.current_palette_index = int(settings[param_name])
				color_palette_manager.emit_current_palette()
		else:
			var value = settings[param_name]
			
			# Special handling for kaleidoscope segments
			if param_name == "kaleidoscope_segments":
				value = round(value / 2.0) * 2.0
				value = clamp(value, 4.0, 80.0)
			
			parameter_manager.set_parameter_value(param_name, value)

func get_current_parameter_values() -> Dictionary:
	"""Get current values of all parameters that might be animated"""
	var values = {}
	if parameter_manager:
		var all_params = parameter_manager.get_all_parameters()
		for param_name in all_params:
			if param_name != "color_palette":  # Skip this meta-parameter
				values[param_name] = all_params[param_name]["current"]
	
	if color_palette_manager:
		values["color_palette_index"] = color_palette_manager.current_palette_index
	
	return values

# ====================
# AUDACITY LABEL IMPORT
# ====================

func import_audacity_labels(file_path: String, default_transition_duration: float = 2.0) -> bool:
	"""Import checkpoints from Audacity label track export
	
	Audacity label format:
	start_time	end_time	label_text
	OR
	point_time	point_time	label_text
	
	Example file content:
	0.000000	0.000000	Intro
	8.250000	8.250000	Beat Drop
	20.500000	20.500000	Verse Build
	35.000000	35.000000	Chorus Peak
	"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("SongSettings: ERROR - Could not open Audacity labels file: %s" % file_path)
		return false
	
	var imported_checkpoints = []
	var line_number = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		line_number += 1
		
		if line == "" or line.begins_with("#"):
			continue  # Skip empty lines and comments
		
		var parts = line.split("\t")
		if parts.size() < 3:
			print("SongSettings: WARNING - Invalid line %d in labels file: %s" % [line_number, line])
			continue
		
		var start_time = float(parts[0])
		var end_time = float(parts[1])
		var label_text = parts[2]
		
		# Use start_time as the checkpoint timestamp
		var checkpoint_time = start_time
		
		# Parse label text for special commands
		var parsed_data = parse_label_text(label_text)
		var checkpoint_name = parsed_data.name
		var transition_duration = parsed_data.get("transition_duration", default_transition_duration)
		var transition_curve = parsed_data.get("transition_curve", TransitionCurve.EASE_IN_OUT)
		
		# Create checkpoint with current parameter values as defaults
		# User will capture/modify these later
		var checkpoint = {
			"timestamp": checkpoint_time,
			"name": checkpoint_name,
			"settings": get_default_checkpoint_settings(),
			"transition_duration": transition_duration,
			"transition_curve": transition_curve
		}
		
		imported_checkpoints.append(checkpoint)
		print("SongSettings: Imported checkpoint '%.1fs - %s' (transition: %.1fs)" % [checkpoint_time, checkpoint_name, transition_duration])
	
	file.close()
	
	if imported_checkpoints.size() > 0:
		# Replace current checkpoints with imported ones
		checkpoints = imported_checkpoints
		checkpoints.sort_custom(func(a, b): return a.timestamp < b.timestamp)
		
		# Reset state
		current_checkpoint_index = -1
		is_transitioning = false
		
		print("SongSettings: Successfully imported %d checkpoints from Audacity labels" % checkpoints.size())
		return true
	else:
		print("SongSettings: No valid checkpoints found in labels file")
		return false

func parse_label_text(label_text: String) -> Dictionary:
	"""Parse label text for special formatting and commands
	
	Supported formats:
	- "Intro" -> Simple name
	- "Beat Drop [3s]" -> Name with custom transition duration
	- "Chorus [2s,bounce]" -> Name with duration and curve type
	- "Bridge [1.5s,ease_in]" -> Name with specific easing
	"""
	var result = {"name": label_text}
	
	# Check for commands in brackets [...]
	var bracket_start = label_text.find("[")
	var bracket_end = label_text.find("]")
	
	if bracket_start != -1 and bracket_end != -1 and bracket_end > bracket_start:
		# Extract the base name
		result.name = label_text.substr(0, bracket_start).strip_edges()
		
		# Extract and parse commands
		var commands_text = label_text.substr(bracket_start + 1, bracket_end - bracket_start - 1)
		var commands = commands_text.split(",")
		
		for command in commands:
			command = command.strip_edges().to_lower()
			
			# Parse transition duration (e.g., "3s", "2.5s")
			if command.ends_with("s") and command.length() > 1:
				var duration_str = command.substr(0, command.length() - 1)
				var duration = float(duration_str)
				if duration > 0:
					result.transition_duration = duration
			
			# Parse transition curve types
			elif command in ["linear", "ease_in", "ease_out", "ease_in_out", "bounce"]:
				match command:
					"linear":
						result.transition_curve = TransitionCurve.LINEAR
					"ease_in":
						result.transition_curve = TransitionCurve.EASE_IN
					"ease_out":
						result.transition_curve = TransitionCurve.EASE_OUT
					"ease_in_out":
						result.transition_curve = TransitionCurve.EASE_IN_OUT
					"bounce":
						result.transition_curve = TransitionCurve.BOUNCE
	
	return result

func get_default_checkpoint_settings() -> Dictionary:
	"""Get default parameter values for new checkpoints"""
	return {
		"fly_speed": 0.25,
		"rotation_speed": 0.025,
		"zoom_level": 0.3,
		"kaleidoscope_segments": 10.0,
		"truchet_radius": 0.35,
		"color_intensity": 1.0,
		"contrast": 1.0,
		"plane_rotation_speed": 0.5,
		"camera_tilt_x": 0.0,
		"camera_tilt_y": 0.0,
		"camera_roll": 0.0,
		"path_stability": 1.0,
		"path_skew": 1.0,
		"color_speed": 0.5,
		"color_palette_index": 0
	}

func export_to_audacity_labels(file_path: String) -> bool:
	"""Export current checkpoints back to Audacity label format"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("SongSettings: ERROR - Could not create labels file: %s" % file_path)
		return false
	
	# Write header comment
	file.store_line("# Audacity labels exported from Kaldao Fractal Visualizer")
	file.store_line("# Format: start_time\tend_time\tlabel_text")
	file.store_line("# Import this file into Audacity using: Tracks > New > Label Track, then Import > Labels")
	file.store_line("")
	
	for checkpoint in checkpoints:
		var timestamp = checkpoint.timestamp
		var name = checkpoint.name
		var duration = checkpoint.transition_duration
		
		# Convert curve type back to text
		var curve_name = ""
		match checkpoint.transition_curve:
			TransitionCurve.LINEAR:
				curve_name = "linear"
			TransitionCurve.EASE_IN:
				curve_name = "ease_in"
			TransitionCurve.EASE_OUT:
				curve_name = "ease_out"
			TransitionCurve.EASE_IN_OUT:
				curve_name = "ease_in_out"
			TransitionCurve.BOUNCE:
				curve_name = "bounce"
		
		# Format label with metadata
		var label_text = name
		if duration != 2.0 or curve_name != "ease_in_out":  # Only add brackets if non-default
			var metadata = []
			if duration != 2.0:
				metadata.append("%.1fs" % duration)
			if curve_name != "ease_in_out":
				metadata.append(curve_name)
			
			if metadata.size() > 0:
				label_text += " [%s]" % ",".join(metadata)
		
		# Write label line (point label format: same start and end time)
		file.store_line("%.6f\t%.6f\t%s" % [timestamp, timestamp, label_text])
	
	file.close()
	print("SongSettings: Exported %d checkpoints to Audacity labels: %s" % [checkpoints.size(), file_path])
	return true

# ====================
# CHECKPOINT EDITING API
# ====================

func add_checkpoint(timestamp: float, name: String, settings: Dictionary, transition_duration: float = 2.0, curve: TransitionCurve = TransitionCurve.EASE_IN_OUT):
	"""Add a new checkpoint to the song"""
	var new_checkpoint = {
		"timestamp": timestamp,
		"name": name,
		"settings": settings,
		"transition_duration": transition_duration,
		"transition_curve": curve
	}
	
	checkpoints.append(new_checkpoint)
	checkpoints.sort_custom(func(a, b): return a.timestamp < b.timestamp)
	print("SongSettings: Added checkpoint '%s' at %.1fs" % [name, timestamp])

func remove_checkpoint(timestamp: float) -> bool:
	"""Remove a checkpoint by timestamp"""
	for i in range(checkpoints.size()):
		if abs(checkpoints[i].timestamp - timestamp) < 0.1:  # 0.1s tolerance
			var removed = checkpoints.pop_at(i)
			print("SongSettings: Removed checkpoint '%s'" % removed.name)
			return true
	return false

func update_checkpoint_settings(timestamp: float, new_settings: Dictionary) -> bool:
	"""Update the settings for an existing checkpoint"""
	for checkpoint in checkpoints:
		if abs(checkpoint.timestamp - timestamp) < 0.1:
			checkpoint.settings = new_settings
			print("SongSettings: Updated settings for checkpoint '%s'" % checkpoint.name)
			return true
	return false

func get_checkpoint_at_time(timestamp: float) -> Dictionary:
	"""Get the checkpoint closest to a given timestamp"""
	var closest_checkpoint = {}
	var closest_distance = INF
	
	for checkpoint in checkpoints:
		var distance = abs(checkpoint.timestamp - timestamp)
		if distance < closest_distance:
			closest_distance = distance
			closest_checkpoint = checkpoint
	
	return closest_checkpoint

func capture_current_settings_as_checkpoint(timestamp: float, name: String, transition_duration: float = 2.0):
	"""Capture the current parameter state as a new checkpoint"""
	var current_settings = get_current_parameter_values()
	add_checkpoint(timestamp, name, current_settings, transition_duration)

# ====================
# SAVE/LOAD SYSTEM
# ====================

func save_song_settings(filename: String = "song_settings.json"):
	"""Save the current checkpoint configuration"""
	var save_data = {
		"song_file": "KOCH5.wav",
		"song_duration": song_duration,
		"checkpoints": checkpoints,
		"version": "1.0",
		"created": Time.get_datetime_string_from_system()
	}
	
	var file_path = "user://" + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		
		var absolute_path = ProjectSettings.globalize_path(file_path)
		print("SongSettings: Saved to %s" % absolute_path)
		return true
	else:
		print("SongSettings: ERROR - Could not save to %s" % file_path)
		return false

func load_song_settings(filename: String = "song_settings.json") -> bool:
	"""Load a checkpoint configuration"""
	var file_path = "user://" + filename
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("SongSettings: No saved settings found at %s" % file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("SongSettings: ERROR - Could not parse settings file")
		return false
	
	var save_data = json.data
	
	if "checkpoints" in save_data:
		checkpoints = save_data.checkpoints
		checkpoints.sort_custom(func(a, b): return a.timestamp < b.timestamp)
		print("SongSettings: Loaded %d checkpoints from %s" % [checkpoints.size(), filename])
		
		# Reset state
		current_checkpoint_index = -1
		is_transitioning = false
		
		return true
	
	return false

# ====================
# DEBUG AND UTILITIES
# ====================

func get_status_text() -> String:
	"""Get current status for debugging"""
	var status = "=== SONG SETTINGS STATUS ===\n"
	status += "Checkpoints: %d\n" % checkpoints.size()
	status += "Current Index: %d\n" % current_checkpoint_index
	status += "Transitioning: %s\n" % str(is_transitioning)
	
	if audio_manager:
		var current_time = audio_manager.get_playback_position()
		status += "Audio Time: %.1fs\n" % current_time
		
		# Show next checkpoint
		for i in range(current_checkpoint_index + 1, checkpoints.size()):
			var next_checkpoint = checkpoints[i]
			if next_checkpoint.timestamp > current_time:
				status += "Next: '%s' at %.1fs (in %.1fs)\n" % [
					next_checkpoint.name, 
					next_checkpoint.timestamp,
					next_checkpoint.timestamp - current_time
				]
				break
	
	return status

func list_all_checkpoints():
	"""Print all checkpoints for debugging"""
	print("SongSettings: All checkpoints:")
	for i in range(checkpoints.size()):
		var cp = checkpoints[i]
		print("  %d. %.1fs - %s (transition: %.1fs)" % [i, cp.timestamp, cp.name, cp.transition_duration])

# Call this from CanvasManager._process(delta) to keep sync active
func process_song_sync(delta: float):
	"""Call this every frame to maintain song synchronization"""
	if audio_manager and audio_manager.playing:
		var current_time = audio_manager.get_playback_position()
		update_sync(current_time)
