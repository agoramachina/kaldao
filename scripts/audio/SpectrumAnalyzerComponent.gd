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
const FFT_SIZE = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
const SAMPLE_RATE = 44100.0
const SMOOTHING = 0.1

# Beat detection
var bass_history: Array[float] = []
var beat_threshold_multiplier = 1.5
var min_beat_interval = 0.1  # Minimum time between beats
var last_beat_time = 0.0

# Current intensity values
var current_bass = 0.0
var current_mid = 0.0
var current_treble = 0.0

func set_audio_effect(effect: AudioEffectSpectrumAnalyzerInstance):
	audio_effect = effect

func get_fft_size() -> AudioEffectSpectrumAnalyzer.FFTSize:
	return FFT_SIZE

func process_audio():
	if audio_effect == null:
		return
	
	# Analyze frequency spectrum
	analyze_spectrum()
	
	# Detect beats
	detect_beats()

func analyze_spectrum():
	var bass_magnitude = get_frequency_range_magnitude(BASS_FREQ_MIN, BASS_FREQ_MAX)
	var mid_magnitude = get_frequency_range_magnitude(MID_FREQ_MIN, MID_FREQ_MAX)
	var treble_magnitude = get_frequency_range_magnitude(TREBLE_FREQ_MIN, TREBLE_FREQ_MAX)
	
	# Smooth the values
	current_bass = lerp(current_bass, bass_magnitude, SMOOTHING)
	current_mid = lerp(current_mid, mid_magnitude, SMOOTHING)
	current_treble = lerp(current_treble, treble_magnitude, SMOOTHING)
	
	# Emit signals with intensity values
	bass_detected.emit(current_bass)
	mid_detected.emit(current_mid)
	treble_detected.emit(current_treble)

func get_frequency_range_magnitude(freq_min: float, freq_max: float) -> float:
	var magnitude = 0.0
	var count = 0
	
	# Convert frequency range to bin indices
	var bin_min = int(freq_min / SAMPLE_RATE * FFT_SIZE)
	var bin_max = int(freq_max / SAMPLE_RATE * FFT_SIZE)
	
	# Sum magnitudes in the frequency range
	for i in range(bin_min, min(bin_max, FFT_SIZE / 2)):
		var freq = i * SAMPLE_RATE / FFT_SIZE
		magnitude += audio_effect.get_magnitude_for_frequency_range(freq, freq + 1.0).length()
		count += 1
	
	return magnitude / max(count, 1) if count > 0 else 0.0

func detect_beats():
	# Add current bass to history
	bass_history.append(current_bass)
	
	# Keep only recent history (about 1 second)
	var max_history_size = int(60)  # Assuming 60 FPS
	if bass_history.size() > max_history_size:
		bass_history.pop_front()
	
	# Calculate average bass over recent history
	if bass_history.size() < 10:
		return
	
	var avg_bass = 0.0
	for val in bass_history:
		avg_bass += val
	avg_bass /= bass_history.size()
	
	# Detect beat if current bass is significantly higher than average
	var current_time = Time.get_time_dict_from_system()
	var time_since_last_beat = Time.get_time_dict_from_system().get("second", 0) - last_beat_time
	
	if current_bass > avg_bass * beat_threshold_multiplier and time_since_last_beat > min_beat_interval:
		beat_detected.emit()
		last_beat_time = Time.get_time_dict_from_system().get("second", 0)

# Public functions to get current values
func get_bass_intensity() -> float:
	return current_bass

func get_mid_intensity() -> float:
	return current_mid

func get_treble_intensity() -> float:
	return current_treble

# Helper function to get overall volume
func get_overall_volume() -> float:
	return (current_bass + current_mid + current_treble) / 3.0
