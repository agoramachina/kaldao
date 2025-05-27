extends AudioStreamPlayer
class_name AudioManager

# Signals
signal bass_detected(intensity: float)
signal mid_detected(intensity: float) 
signal treble_detected(intensity: float)
signal beat_detected()

# Audio analysis
var spectrum_analyzer: AudioEffectSpectrumAnalyzer
var audio_effect: AudioEffectSpectrumAnalyzerInstance

# Current audio levels
var current_bass = 0.0
var current_mid = 0.0
var current_treble = 0.0

# Beat detection
var bass_history: Array[float] = []
var beat_threshold_multiplier = 1.3  # Lowered for more sensitive beat detection
var min_beat_interval = 0.12
var last_beat_time = 0.0

# Audio settings
var audio_file_path = "res://audio/SoS.wav"  # Updated to use SoS.wav
var audio_enabled = false
var audio_reactive = false
var is_paused = false
var pause_position = 0.0

# Enhanced frequency analysis settings
const BASS_FREQ_MIN = 20.0
const BASS_FREQ_MAX = 200.0    # Narrowed bass range for more punch
const MID_FREQ_MIN = 200.0     # Adjusted to not overlap
const MID_FREQ_MAX = 3000.0    # Focused mid range
const TREBLE_FREQ_MIN = 3000.0
const TREBLE_FREQ_MAX = 20000.0
const SAMPLE_RATE = 44100.0
const SMOOTHING = 0.08         # Faster response
const FFT_SIZE_VALUE = 2048

# AMPLIFIED intensity multipliers for much stronger effects
var bass_pulse_intensity = 8.0      # Massively increased from 1.5
var mid_rotation_intensity = 3.0    # Increased from 1.0
var treble_zoom_intensity = 2.5     # Increased from 0.8
var beat_reset_timer = 0.0
var beat_duration = 0.4             # Slightly longer beat effects

# Audio amplification settings
var bass_amplifier = 15.0           # NEW: Amplify bass signal
var mid_amplifier = 12.0            # NEW: Amplify mid signal  
var treble_amplifier = 10.0         # NEW: Amplify treble signal
var overall_gain = 3.0              # NEW: Overall audio gain

# Parameter manager for audio reactivity
var parameter_manager: ParameterManager
var base_values = {}

# Debug control
var debug_audio_levels = false
var debug_frame_counter = 0
var debug_print_interval = 30       # Print debug every 30 frames (0.5 seconds at 60fps)

func _ready():
	print("AudioManager: Initializing ENHANCED audio system for SoS.wav...")
	
	# Load the audio file
	load_audio_file()
	
	# Setup spectrum analyzer
	setup_spectrum_analyzer()
	
	print("AudioManager: Enhanced audio system ready with AMPLIFIED responses")
	print("  Bass Amplifier: %.1fx, Mid: %.1fx, Treble: %.1fx" % [bass_amplifier, mid_amplifier, treble_amplifier])
	print("  Controls: Shift+A - Toggle audio playback, A - Toggle audio reactive")

func load_audio_file():
	"""Load the audio file from res://audio/SoS.wav"""
	var audio_stream = load(audio_file_path) as AudioStream
	
	if audio_stream:
		stream = audio_stream
		print("AudioManager: Loaded audio file: %s" % audio_file_path)
		print("  Duration: %.1f seconds" % audio_stream.get_length())
	else:
		print("AudioManager: ERROR - Could not load audio file: %s" % audio_file_path)
		print("  Make sure the file exists and is a supported audio format (.wav, .ogg)")



func setup_spectrum_analyzer():
	"""Setup spectrum analyzer on Master bus for audio analysis"""
	spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
	spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	spectrum_analyzer.buffer_length = 2.0
	
	var bus_index = AudioServer.get_bus_index("Master")
	
	# Remove any existing spectrum analyzer effects
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	for i in range(effect_count - 1, -1, -1):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectSpectrumAnalyzer:
			AudioServer.remove_bus_effect(bus_index, i)
			print("AudioManager: Removed existing spectrum analyzer")
	
	# Add our spectrum analyzer
	AudioServer.add_bus_effect(bus_index, spectrum_analyzer)
	print("AudioManager: Added spectrum analyzer to Master bus")
	
	# Get the effect instance
	var effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	audio_effect = AudioServer.get_bus_effect_instance(bus_index, effect_index) as AudioEffectSpectrumAnalyzerInstance
	
	if audio_effect:
		print("AudioManager: Spectrum analyzer connected successfully")
	else:
		print("AudioManager: ERROR - Could not get spectrum analyzer instance!")

func toggle_audio_playback() -> bool:
	"""Toggle audio playback with proper pause/resume"""
	if not stream:
		print("AudioManager: No audio file loaded!")
		return false
	
	if playing and not is_paused:
		# Currently playing - pause it
		pause_position = get_playback_position()
		stream_paused = true
		is_paused = true
		print("AudioManager: Audio paused at %.2fs" % pause_position)
	elif is_paused:
		# Currently paused - resume from saved position
		stream_paused = false
		is_paused = false
		print("AudioManager: Audio resumed from %.2fs" % pause_position)
	else:
		# Not playing at all - start from beginning or saved position
		if pause_position > 0:
			play(pause_position)
		else:
			play()
		is_paused = false
		audio_enabled = true
		print("AudioManager: Audio started")
	
	return playing and not is_paused

func toggle_audio_reactive() -> bool:
	"""Toggle audio reactivity on/off"""
	audio_reactive = !audio_reactive
	
	if audio_reactive:
		store_base_values()
		print("AudioManager: Audio reactivity ENABLED with AMPLIFIED responses")
	else:
		restore_base_values()
		print("AudioManager: Audio reactivity DISABLED")
	
	return audio_reactive

func connect_to_parameter_manager(param_manager: ParameterManager):
	"""Connect to parameter manager for audio reactivity"""
	parameter_manager = param_manager
	print("AudioManager: Connected to parameter manager")

func store_base_values():
	"""Store current parameter values as base values"""
	if not parameter_manager:
		return
	
	base_values["truchet_radius"] = parameter_manager.get_parameter_value("truchet_radius")
	base_values["color_intensity"] = parameter_manager.get_parameter_value("color_intensity")
	base_values["rotation_speed"] = parameter_manager.get_parameter_value("rotation_speed")
	base_values["zoom_level"] = parameter_manager.get_parameter_value("zoom_level")
	base_values["kaleidoscope_segments"] = parameter_manager.get_parameter_value("kaleidoscope_segments")
	
	print("AudioManager: Stored base values for AMPLIFIED audio reactivity")

func restore_base_values():
	"""Restore parameters to their base values"""
	if not parameter_manager:
		return
	
	for param_name in base_values:
		parameter_manager.set_parameter_value(param_name, base_values[param_name])
	
	# Reset audio influences
	current_bass = 0.0
	current_mid = 0.0
	current_treble = 0.0
	beat_reset_timer = 0.0
	
	print("AudioManager: Restored base parameter values")

func _process(delta):
	"""Enhanced _process with gradual beat effect restoration"""
	if audio_effect and audio_enabled and playing:
		analyze_spectrum()
		detect_beats()
		
		if audio_reactive:
			apply_audio_reactivity()
	
	# Handle beat effect timing with gradual restoration
	if beat_reset_timer > 0.0:
		beat_reset_timer -= delta
		
		# Gradual restoration instead of instant snap-back
		if beat_reset_timer <= beat_duration * 0.5 and audio_reactive and parameter_manager:
			# Start gradual restoration halfway through beat duration
			var restore_progress = 1.0 - (beat_reset_timer / (beat_duration * 0.5))
			
			# Gradually restore kaleidoscope segments
			if "kaleidoscope_segments" in base_values:
				var current_segments = parameter_manager.get_parameter_value("kaleidoscope_segments")
				var target_segments = base_values["kaleidoscope_segments"]
				var restored_segments = lerp(current_segments, target_segments, restore_progress * 0.1)
				parameter_manager.set_parameter_value("kaleidoscope_segments", restored_segments)
			
			# Gradually restore zoom if it was boosted
			if "zoom_level" in base_values:
				var current_zoom = parameter_manager.get_parameter_value("zoom_level")
				var base_zoom = base_values["zoom_level"]
				if current_zoom > base_zoom * 1.1:  # If zoom was boosted
					var restored_zoom = lerp(current_zoom, base_zoom, restore_progress * 0.2)
					parameter_manager.set_parameter_value("zoom_level", restored_zoom)
			
			# Gradually restore color intensity if it was boosted
			if "color_intensity" in base_values:
				var current_color = parameter_manager.get_parameter_value("color_intensity")
				var base_color = base_values["color_intensity"]
				if current_color > base_color * 1.2:  # If color was boosted
					var restored_color = lerp(current_color, base_color, restore_progress * 0.15)
					parameter_manager.set_parameter_value("color_intensity", restored_color)
		
		elif beat_reset_timer <= 0.0:
			# Final snap to base values when timer expires
			if audio_reactive and parameter_manager:
				if "kaleidoscope_segments" in base_values:
					parameter_manager.set_parameter_value("kaleidoscope_segments", base_values["kaleidoscope_segments"])

func analyze_spectrum():
	"""Analyze the frequency spectrum with AMPLIFIED responses"""
	var bass_magnitude = get_frequency_range_magnitude(BASS_FREQ_MIN, BASS_FREQ_MAX) * bass_amplifier
	var mid_magnitude = get_frequency_range_magnitude(MID_FREQ_MIN, MID_FREQ_MAX) * mid_amplifier
	var treble_magnitude = get_frequency_range_magnitude(TREBLE_FREQ_MIN, TREBLE_FREQ_MAX) * treble_amplifier
	
	# Apply overall gain
	bass_magnitude *= overall_gain
	mid_magnitude *= overall_gain
	treble_magnitude *= overall_gain
	
	# Smooth the values
	current_bass = lerp(current_bass, bass_magnitude, SMOOTHING)
	current_mid = lerp(current_mid, mid_magnitude, SMOOTHING)
	current_treble = lerp(current_treble, treble_magnitude, SMOOTHING)
	
	# Emit signals
	bass_detected.emit(current_bass)
	mid_detected.emit(current_mid)
	treble_detected.emit(current_treble)
	
	# Controlled debug output
	debug_frame_counter += 1
	if debug_audio_levels and debug_frame_counter >= debug_print_interval:
		debug_frame_counter = 0
		if current_bass > 0.01 or current_mid > 0.01 or current_treble > 0.01:
			print("AUDIO: Bass: %.3f, Mid: %.3f, Treble: %.3f" % [current_bass, current_mid, current_treble])

func get_frequency_range_magnitude(freq_min: float, freq_max: float) -> float:
	"""Calculate magnitude for a frequency range"""
	var magnitude = 0.0
	var count = 0
	
	var bin_min = int(freq_min / SAMPLE_RATE * FFT_SIZE_VALUE)
	var bin_max = int(freq_max / SAMPLE_RATE * FFT_SIZE_VALUE)
	
	bin_min = max(bin_min, 0)
	bin_max = min(bin_max, FFT_SIZE_VALUE / 2)
	
	for i in range(bin_min, bin_max):
		var freq = i * SAMPLE_RATE / FFT_SIZE_VALUE
		var freq_magnitude = audio_effect.get_magnitude_for_frequency_range(freq, freq + SAMPLE_RATE / FFT_SIZE_VALUE)
		magnitude += freq_magnitude.length()
		count += 1
	
	return magnitude / max(count, 1) if count > 0 else 0.0

func detect_beats():
	"""ENHANCED beat detection with PROPER kaleidoscope segment handling"""
	bass_history.append(current_bass)
	
	# Keep history to reasonable size (about 3 seconds at 60fps for better averaging)
	var max_history_size = 180
	if bass_history.size() > max_history_size:
		bass_history.pop_front()
	
	# Need minimum history for reliable detection
	if bass_history.size() < 10:
		return
	
	# Get current time in a more precise way
	var current_time = Time.get_time_dict_from_system()
	var precise_time = current_time.hour * 3600 + current_time.minute * 60 + current_time.second + (Engine.get_process_frames() % 60) / 60.0
	var time_since_last_beat = precise_time - last_beat_time
	
	# Don't detect beats too frequently
	if time_since_last_beat < min_beat_interval:
		return
	
	# Calculate different types of averages for better detection
	var recent_history_size = min(bass_history.size(), 30)  # Last 0.5 seconds
	var medium_history_size = min(bass_history.size(), 90)  # Last 1.5 seconds
	
	# Recent average (immediate context)
	var recent_avg = 0.0
	for i in range(bass_history.size() - recent_history_size, bass_history.size()):
		recent_avg += bass_history[i]
	recent_avg /= recent_history_size
	
	# Medium-term average (broader context)
	var medium_avg = 0.0
	for i in range(bass_history.size() - medium_history_size, bass_history.size()):
		medium_avg += bass_history[i]
	medium_avg /= medium_history_size
	
	# Overall average
	var overall_avg = 0.0
	for val in bass_history:
		overall_avg += val
	overall_avg /= bass_history.size()
	
	# Calculate variance for dynamic threshold
	var variance = 0.0
	for val in bass_history:
		variance += (val - overall_avg) * (val - overall_avg)
	variance /= bass_history.size()
	var std_dev = sqrt(variance)
	
	# Dynamic threshold based on audio content
	var dynamic_threshold = beat_threshold_multiplier
	if std_dev > 0.1:  # If audio is dynamic, lower threshold
		dynamic_threshold *= 0.8
	elif std_dev < 0.05:  # If audio is quiet, raise threshold
		dynamic_threshold *= 1.3
	
	# Multiple beat detection methods
	var beat_detected_basic = current_bass > overall_avg * dynamic_threshold
	var beat_detected_recent = current_bass > recent_avg * (dynamic_threshold * 0.9)
	var beat_detected_variance = current_bass > (overall_avg + std_dev * 2.0)
	
	# Beat is detected if ANY method triggers (OR logic for sensitivity)
	var beat_triggered = beat_detected_basic or beat_detected_recent or beat_detected_variance
	
	if beat_triggered:
		beat_detected.emit()
		last_beat_time = precise_time
		
		# FIXED: Enhanced beat effects with PROPER segment values
		if audio_reactive and parameter_manager and "kaleidoscope_segments" in base_values:
			var original_segments = base_values["kaleidoscope_segments"]
			
			# Beat intensity affects the change magnitude
			var beat_intensity = max(
				current_bass / max(overall_avg, 0.01),
				current_bass / max(recent_avg, 0.01)
			)
			
			# FIXED: Generate proper even integer segment values
			var max_change_steps = 12  # Maximum steps of 2 to change
			var change_steps = randi_range(-max_change_steps, max_change_steps)  # Integer steps
			var segment_change = change_steps * 2.0  # Multiply by 2 to ensure even values
			
			# Scale change based on beat intensity but keep it as even integers
			segment_change *= min(beat_intensity / 2.0, 1.0)
			segment_change = round(segment_change / 2.0) * 2.0  # Ensure it's still even after scaling
			
			# Calculate new segments and ensure they're even integers within range
			var new_segments = original_segments + segment_change
			new_segments = clamp(new_segments, 4, 80)  # Ensure minimum is even
			new_segments = round(new_segments / 2.0) * 2.0  # Force to even integer
			
			parameter_manager.set_parameter_value("kaleidoscope_segments", new_segments)
			beat_reset_timer = beat_duration
			
			# Additional beat effects for stronger response
			if beat_intensity > 2.0:  # Strong beat
				# Temporary zoom burst
				var base_zoom = base_values.get("zoom_level", 1.25)
				var zoom_burst = base_zoom + (beat_intensity * 0.2)
				parameter_manager.set_parameter_value("zoom_level", clamp(zoom_burst, 0.05, 2.0))
				
				# Temporary color intensity burst
				var base_color = base_values.get("color_intensity", 1.0)
				var color_burst = base_color + (beat_intensity * 0.3)
				parameter_manager.set_parameter_value("color_intensity", clamp(color_burst, 0.5, 4.0))
			
		# Enhanced debug output
		var detection_method = ""
		if beat_detected_basic: detection_method += "BASIC "
		if beat_detected_recent: detection_method += "RECENT "
		if beat_detected_variance: detection_method += "VARIANCE "
		
		#print("AudioManager: BEAT [%s]! Intensity: %.2f, Bass: %.3f vs Avg: %.3f/%.3f, Segments: %.0f" % [
			#detection_method.strip_edges(), 
			#current_bass / max(overall_avg, 0.01), 
			#current_bass, 
			#overall_avg, 
			#recent_avg, 
			#parameter_manager.get_parameter_value("kaleidoscope_segments") if parameter_manager else 0
		#])

func _process_beat_effects(delta):
	"""Enhanced beat effect handling with proper segment restoration"""
	# Handle beat effect timing with gradual restoration
	if beat_reset_timer > 0.0:
		beat_reset_timer -= delta
		
		# Gradual restoration instead of instant snap-back
		if beat_reset_timer <= beat_duration * 0.5 and audio_reactive and parameter_manager:
			# Start gradual restoration halfway through beat duration
			var restore_progress = 1.0 - (beat_reset_timer / (beat_duration * 0.5))
			
			# FIXED: Gradually restore kaleidoscope segments with proper even values
			if "kaleidoscope_segments" in base_values:
				var current_segments = parameter_manager.get_parameter_value("kaleidoscope_segments")
				var target_segments = base_values["kaleidoscope_segments"]
				var restored_segments = lerp(current_segments, target_segments, restore_progress * 0.1)
				
				# ENSURE restored value is even integer
				restored_segments = round(restored_segments / 2.0) * 2.0
				restored_segments = clamp(restored_segments, 4, 80)
				
				parameter_manager.set_parameter_value("kaleidoscope_segments", restored_segments)
			
			# Gradually restore zoom if it was boosted
			if "zoom_level" in base_values:
				var current_zoom = parameter_manager.get_parameter_value("zoom_level")
				var base_zoom = base_values["zoom_level"]
				if current_zoom > base_zoom * 1.1:  # If zoom was boosted
					var restored_zoom = lerp(current_zoom, base_zoom, restore_progress * 0.2)
					parameter_manager.set_parameter_value("zoom_level", restored_zoom)
			
			# Gradually restore color intensity if it was boosted
			if "color_intensity" in base_values:
				var current_color = parameter_manager.get_parameter_value("color_intensity")
				var base_color = base_values["color_intensity"]
				if current_color > base_color * 1.2:  # If color was boosted
					var restored_color = lerp(current_color, base_color, restore_progress * 0.15)
					parameter_manager.set_parameter_value("color_intensity", restored_color)
		
		elif beat_reset_timer <= 0.0:
			# FIXED: Final snap to base values when timer expires - ensure even segments
			if audio_reactive and parameter_manager:
				if "kaleidoscope_segments" in base_values:
					var final_segments = base_values["kaleidoscope_segments"]
					# Ensure base value is also even (safety check)
					final_segments = round(final_segments / 2.0) * 2.0
					parameter_manager.set_parameter_value("kaleidoscope_segments", final_segments)
					
# Helper function to ensure kaleidoscope segments are always even
func ensure_even_segments(segments: float) -> float:
	"""Ensure kaleidoscope segments is an even integer within valid range"""
	segments = clamp(segments, 4, 80)  # Clamp to valid range
	segments = round(segments / 2.0) * 2.0  # Force to even integer
	return segments

# Function to fix any existing odd segment values
func fix_current_segments():
	"""Call this once to fix any existing odd segment values"""
	if parameter_manager:
		var current = parameter_manager.get_parameter_value("kaleidoscope_segments")
		var fixed = ensure_even_segments(current)
		if current != fixed:
			parameter_manager.set_parameter_value("kaleidoscope_segments", fixed)
			print("AudioManager: Fixed kaleidoscope segments from %.1f to %.1f" % [current, fixed])
			
# Additional function to add to AudioManager for real-time beat sensitivity adjustment
func adjust_beat_sensitivity(new_threshold: float, new_interval: float = 0.12):
	"""Adjust beat detection sensitivity in real-time"""
	beat_threshold_multiplier = new_threshold
	min_beat_interval = new_interval
	print("AudioManager: Beat sensitivity adjusted - Threshold: %.2f, Interval: %.3fs" % [new_threshold, new_interval])
	
# Function to get beat detection stats for debugging
func get_beat_stats() -> Dictionary:
	"""Get current beat detection statistics"""
	if bass_history.size() == 0:
		return {"error": "No audio history"}
	
	var overall_avg = 0.0
	for val in bass_history:
		overall_avg += val
	overall_avg /= bass_history.size()
	
	var variance = 0.0
	for val in bass_history:
		variance += (val - overall_avg) * (val - overall_avg)
	variance /= bass_history.size()
	
	return {
		"current_bass": current_bass,
		"average_bass": overall_avg,
		"variance": variance,
		"std_dev": sqrt(variance),
		"threshold": beat_threshold_multiplier,
		"history_size": bass_history.size(),
		"beat_timer": beat_reset_timer,
		"last_beat_time": last_beat_time
	}
		
func apply_audio_reactivity():
	"""Apply AMPLIFIED audio analysis to visual parameters"""
	if not parameter_manager:
		return
	
	# AMPLIFIED Bass affects truchet radius and color intensity
	var base_radius = base_values.get("truchet_radius", 0.25)
	var pulse_amount = current_bass * bass_pulse_intensity * 0.005  
	var new_radius = clamp(base_radius + pulse_amount, 0.1, 0.9)
	parameter_manager.set_parameter_value("truchet_radius", new_radius)
	
	# var base_color = base_values.get("color_intensity", 1.0)
	# var color_boost = current_bass * 0.2  # Doubled color boost
	# var new_color = clamp(base_color + color_boost, 0.5, 3.0)  # Higher max
	# parameter_manager.set_parameter_value("color_intensity", new_color)
	
	# AMPLIFIED Mid frequencies affect rotation speed
	var base_rotation = base_values.get("rotation_speed", 2.025)
	var rotation_mod = current_mid * mid_rotation_intensity * 0.1  # Increased
	var new_rotation = clamp(base_rotation + rotation_mod, -2.0, 2.0)  # Wider range
	parameter_manager.set_parameter_value("rotation_speed", new_rotation)
	
	# AMPLIFIED Treble affects zoom level
	var base_zoom = base_values.get("zoom_level", 0.3)
	var zoom_mod = current_treble * treble_zoom_intensity * 1.15  # Increased
	var new_zoom = clamp(base_zoom + zoom_mod, 0.05, 1.5)  # Wider range
	parameter_manager.set_parameter_value("zoom_level", new_zoom)

func get_audio_levels() -> Dictionary:
	"""Get current audio levels"""
	return {
		"bass": current_bass,
		"mid": current_mid,
		"treble": current_treble,
		"overall": (current_bass + current_mid + current_treble) / 3.0
	}

func get_status_info() -> Dictionary:
	"""Get audio status information"""
	return {
		"enabled": audio_enabled,
		"reactive": audio_reactive,
		"file": audio_file_path,
		"playing": playing,
		"position": get_playback_position(),
		"duration": stream.get_length() if stream else 0.0,
		"levels": get_audio_levels(),
		"amplifiers": {
			"bass": bass_amplifier,
			"mid": mid_amplifier, 
			"treble": treble_amplifier,
			"overall": overall_gain
		}
	}

func is_audio_reactive() -> bool:
	return audio_reactive

# Handle audio looping
func _on_finished():
	if audio_enabled:
		play()  # Loop the audio

# New function to adjust amplification on the fly
func set_audio_amplifiers(bass: float, mid: float, treble: float, overall: float = 3.0):
	bass_amplifier = bass
	mid_amplifier = mid
	treble_amplifier = treble
	overall_gain = overall
	print("AudioManager: Updated amplifiers - Bass: %.1f, Mid: %.1f, Treble: %.1f, Overall: %.1f" % [bass, mid, treble, overall])
