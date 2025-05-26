extends RefCounted
class_name SpectrumAnalyzerComponent

# Signals
signal bass_detected(intensity: float)
signal mid_detected(intensity: float) 
signal treble_detected(intensity: float)
signal beat_detected()

# Audio effect reference
var audio_effect: AudioEffectSpectrumAnalyzerInstance

# Frequency bands (Hz)
const BASS_FREQ_MIN = 20.0
const BASS_FREQ_MAX = 250.0
const MID_FREQ_MIN = 250.0
const MID_FREQ_MAX = 4000.0
const TREBLE_FREQ_MIN = 4000.0
const TREBLE_FREQ_MAX = 20000.0

# Analysis settings
const SAMPLE_RATE = 44100.0
const SMOOTHING = 0.12
const FFT_SIZE_VALUE = 2048

# Beat detection
var bass_history: Array[float] = []
var beat_threshold_multiplier = 1.4
var min_beat_interval = 0.15
var last_beat_time = 0.0

# Current intensity values
var current_bass = 0.0
var current_mid = 0.0
var current_treble = 0.0

func set_audio_effect(effect: AudioEffectSpectrumAnalyzerInstance):
	audio_effect = effect
	print("SpectrumAnalyzerComponent: Audio effect connected")

func process_audio():
	"""Main audio processing function"""
	if audio_effect == null:
		return
	
	# Analyze frequency spectrum
	analyze_spectrum()
	
	# Detect beats based on bass
	detect_beats()

func analyze_spectrum():
	"""Analyze the frequency spectrum and emit signals"""
	var bass_magnitude = get_frequency_range_magnitude(BASS_FREQ_MIN, BASS_FREQ_MAX)
	var mid_magnitude = get_frequency_range_magnitude(MID_FREQ_MIN, MID_FREQ_MAX)
	var treble_magnitude = get_frequency_range_magnitude(TREBLE_FREQ_MIN, TREBLE_FREQ_MAX)
	
	# Smooth the values to reduce jitter
	current_bass = lerp(current_bass, bass_magnitude, SMOOTHING)
	current_mid = lerp(current_mid, mid_magnitude, SMOOTHING)
	current_treble = lerp(current_treble, treble_magnitude, SMOOTHING)
	
	# Emit signals with smoothed intensity values
	bass_detected.emit(current_bass)
	mid_detected.emit(current_mid)
	treble_detected.emit(current_treble)

func get_frequency_range_magnitude(freq_min: float, freq_max: float) -> float:
	"""Calculate magnitude for a frequency range"""
	var magnitude = 0.0
	var count = 0
	
	# Convert frequency range to FFT bin indices
	var bin_min = int(freq_min / SAMPLE_RATE * FFT_SIZE_VALUE)
	var bin_max = int(freq_max / SAMPLE_RATE * FFT_SIZE_VALUE)
	
	# Clamp to valid range
	bin_min = max(bin_min, 0)
	bin_max = min(bin_max, FFT_SIZE_VALUE / 2)
	
	# Sum magnitudes in the frequency range
	for i in range(bin_min, bin_max):
		var freq = i * SAMPLE_RATE / FFT_SIZE_VALUE
		var freq_magnitude = audio_effect.get_magnitude_for_frequency_range(freq, freq + SAMPLE_RATE / FFT_SIZE_VALUE)
		magnitude += freq_magnitude.length()
		count += 1
	
	# Return average magnitude
	return magnitude / max(count, 1) if count > 0 else 0.0

func detect_beats():
	"""Simple beat detection based on bass intensity"""
	# Add current bass to history
	bass_history.append(current_bass)
	
	# Keep history to a reasonable size (about 2 seconds at 60fps)
	var max_history_size = 120
	if bass_history.size() > max_history_size:
		bass_history.pop_front()
	
	# Need minimum history for beat detection
	if bass_history.size() < 20:
		return
	
	# Calculate average bass over recent history
	var avg_bass = 0.0
	for val in bass_history:
		avg_bass += val
	avg_bass /= bass_history.size()
	
	# Check time since last beat
	var current_time = Time.get_time_dict_from_system()
	var current_seconds = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	var time_since_last_beat = current_seconds - last_beat_time
	
	# Detect beat if current bass significantly exceeds average and enough time has passed
	if current_bass > avg_bass * beat_threshold_multiplier and time_since_last_beat > min_beat_interval:
		beat_detected.emit()
		last_beat_time = current_seconds
		print("SpectrumAnalyzerComponent: Beat detected! Bass: %.3f vs Avg: %.3f" % [current_bass, avg_bass])

# Public getters for current values
func get_bass_intensity() -> float:
	return current_bass

func get_mid_intensity() -> float:
	return current_mid

func get_treble_intensity() -> float:
	return current_treble

func get_overall_volume() -> float:
	return (current_bass + current_mid + current_treble) / 3.0

func get_analysis_info() -> Dictionary:
	"""Get comprehensive analysis information"""
	return {
		"bass": current_bass,
		"mid": current_mid,
		"treble": current_treble,
		"overall": get_overall_volume(),
		"history_size": bass_history.size(),
		"has_effect": audio_effect != null
	}
