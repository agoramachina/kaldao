class_name AudioAnalyzer
extends RefCounted

## AudioAnalyzer - Isolated Audio Frequency Analysis Component
##
## This component handles FFT-based audio analysis, separating frequency bands
## and providing real-time audio level monitoring. It's designed to be used
## by the AudioManager but can work independently.
##
## Usage:
##   var analyzer = AudioAnalyzer.new()
##   analyzer.initialize(audio_effect_instance)
##   analyzer.process_audio(delta)

# Signals for audio level updates
signal audio_levels_updated(bass: float, mid: float, treble: float)

# Audio effect instance for spectrum analysis
var _audio_effect: AudioEffectSpectrumAnalyzerInstance

# Current audio levels
var _current_bass: float = 0.0
var _current_mid: float = 0.0
var _current_treble: float = 0.0

# Configuration settings (loaded from ConfigManager)
var _frequency_ranges: Dictionary = {}
var _amplifiers: Dictionary = {}
var _analysis_settings: Dictionary = {}

# Debug settings
var _debug_enabled: bool = false
var _debug_frame_counter: int = 0
var _debug_print_interval: int = 30

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the audio analyzer with configuration
## @param audio_effect: AudioEffectSpectrumAnalyzerInstance for analysis
## @return: True if initialization was successful
func initialize(audio_effect: AudioEffectSpectrumAnalyzerInstance) -> bool:
	if _is_initialized:
		print("AudioAnalyzer: Already initialized")
		return true
	
	if not audio_effect:
		push_error("AudioAnalyzer: Invalid audio effect instance provided")
		return false
	
	_audio_effect = audio_effect
	
	# Load configuration
	_load_configuration()
	
	_is_initialized = true
	print("AudioAnalyzer: Initialized successfully")
	return true

## Load configuration from ConfigManager
func _load_configuration() -> void:
	print("AudioAnalyzer: Loading configuration...")
	
	# Load frequency ranges
	_frequency_ranges = {
		"bass_min": ConfigManager.get_config_value("audio.frequency_ranges.bass_min", 20.0),
		"bass_max": ConfigManager.get_config_value("audio.frequency_ranges.bass_max", 200.0),
		"mid_min": ConfigManager.get_config_value("audio.frequency_ranges.mid_min", 200.0),
		"mid_max": ConfigManager.get_config_value("audio.frequency_ranges.mid_max", 3000.0),
		"treble_min": ConfigManager.get_config_value("audio.frequency_ranges.treble_min", 3000.0),
		"treble_max": ConfigManager.get_config_value("audio.frequency_ranges.treble_max", 20000.0)
	}
	
	# Load amplifiers
	_amplifiers = ConfigManager.get_audio_amplifiers()
	
	# Load analysis settings
	_analysis_settings = {
		"sample_rate": ConfigManager.get_sample_rate(),
		"fft_size": ConfigManager.get_fft_size(),
		"smoothing_factor": ConfigManager.get_smoothing_factor(),
		"overall_gain": _amplifiers.overall
	}
	
	# Load debug settings
	_debug_enabled = ConfigManager.is_debug_mode()
	_debug_print_interval = ConfigManager.get_debug_print_interval()
	
	print("AudioAnalyzer: Configuration loaded")
	print("  Frequency ranges - Bass: %.0f-%.0fHz, Mid: %.0f-%.0fHz, Treble: %.0f-%.0fHz" % [
		_frequency_ranges.bass_min, _frequency_ranges.bass_max,
		_frequency_ranges.mid_min, _frequency_ranges.mid_max,
		_frequency_ranges.treble_min, _frequency_ranges.treble_max
	])
	print("  Amplifiers - Bass: %.1fx, Mid: %.1fx, Treble: %.1fx, Overall: %.1fx" % [
		_amplifiers.bass, _amplifiers.mid, _amplifiers.treble, _amplifiers.overall
	])

#endregion

#region Audio Processing

## Process audio analysis for the current frame
## @param delta: Time elapsed since last frame
func process_audio(delta: float) -> void:
	if not _is_initialized or not _audio_effect:
		return
	
	# Analyze frequency spectrum
	_analyze_spectrum()
	
	# Emit updated levels
	audio_levels_updated.emit(_current_bass, _current_mid, _current_treble)
	
	# Debug output if enabled
	_debug_output()

## Analyze the frequency spectrum and update current levels
func _analyze_spectrum() -> void:
	# Get magnitude for each frequency band
	var bass_magnitude = _get_frequency_range_magnitude(_frequency_ranges.bass_min, _frequency_ranges.bass_max)
	var mid_magnitude = _get_frequency_range_magnitude(_frequency_ranges.mid_min, _frequency_ranges.mid_max)
	var treble_magnitude = _get_frequency_range_magnitude(_frequency_ranges.treble_min, _frequency_ranges.treble_max)
	
	# Apply amplifiers
	bass_magnitude *= _amplifiers.bass * _analysis_settings.overall_gain
	mid_magnitude *= _amplifiers.mid * _analysis_settings.overall_gain
	treble_magnitude *= _amplifiers.treble * _analysis_settings.overall_gain
	
	# Apply smoothing
	var smoothing = _analysis_settings.smoothing_factor
	_current_bass = lerp(_current_bass, bass_magnitude, smoothing)
	_current_mid = lerp(_current_mid, mid_magnitude, smoothing)
	_current_treble = lerp(_current_treble, treble_magnitude, smoothing)

## Calculate magnitude for a specific frequency range
## @param freq_min: Minimum frequency in Hz
## @param freq_max: Maximum frequency in Hz
## @return: Average magnitude for the frequency range
func _get_frequency_range_magnitude(freq_min: float, freq_max: float) -> float:
	var magnitude: float = 0.0
	var count: int = 0
	
	var sample_rate = _analysis_settings.sample_rate
	var fft_size = _analysis_settings.fft_size
	
	# Calculate frequency bin range
	var bin_min = int(freq_min / sample_rate * fft_size)
	var bin_max = int(freq_max / sample_rate * fft_size)
	
	# Clamp to valid range
	bin_min = max(bin_min, 0)
	bin_max = min(bin_max, fft_size / 2)
	
	# Sum magnitudes across the frequency range
	for i in range(bin_min, bin_max):
		var freq = i * sample_rate / fft_size
		var freq_magnitude = _audio_effect.get_magnitude_for_frequency_range(freq, freq + sample_rate / fft_size)
		magnitude += freq_magnitude.length()
		count += 1
	
	# Return average magnitude
	return magnitude / max(count, 1) if count > 0 else 0.0

## Debug output for audio levels
func _debug_output() -> void:
	if not _debug_enabled:
		return
	
	_debug_frame_counter += 1
	if _debug_frame_counter >= _debug_print_interval:
		_debug_frame_counter = 0
		
		# Only print if there's significant audio activity
		if _current_bass > 0.01 or _current_mid > 0.01 or _current_treble > 0.01:
			print("AudioAnalyzer: Bass: %.3f, Mid: %.3f, Treble: %.3f" % [_current_bass, _current_mid, _current_treble])

#endregion

#region Public API

## Get current audio levels
## @return: Dictionary with current audio levels
func get_current_levels() -> Dictionary:
	return {
		"bass": _current_bass,
		"mid": _current_mid,
		"treble": _current_treble,
		"overall": (_current_bass + _current_mid + _current_treble) / 3.0
	}

## Update amplifier settings
## @param bass: Bass amplifier value
## @param mid: Mid amplifier value
## @param treble: Treble amplifier value
## @param overall: Overall gain value
func update_amplifiers(bass: float, mid: float, treble: float, overall: float) -> void:
	_amplifiers.bass = bass
	_amplifiers.mid = mid
	_amplifiers.treble = treble
	_amplifiers.overall = overall
	_analysis_settings.overall_gain = overall
	
	print("AudioAnalyzer: Updated amplifiers - Bass: %.1fx, Mid: %.1fx, Treble: %.1fx, Overall: %.1fx" % [bass, mid, treble, overall])

## Update frequency ranges
## @param bass_min: Minimum bass frequency
## @param bass_max: Maximum bass frequency
## @param mid_min: Minimum mid frequency
## @param mid_max: Maximum mid frequency
## @param treble_min: Minimum treble frequency
## @param treble_max: Maximum treble frequency
func update_frequency_ranges(bass_min: float, bass_max: float, mid_min: float, mid_max: float, treble_min: float, treble_max: float) -> void:
	_frequency_ranges.bass_min = bass_min
	_frequency_ranges.bass_max = bass_max
	_frequency_ranges.mid_min = mid_min
	_frequency_ranges.mid_max = mid_max
	_frequency_ranges.treble_min = treble_min
	_frequency_ranges.treble_max = treble_max
	
	print("AudioAnalyzer: Updated frequency ranges")
	print("  Bass: %.0f-%.0fHz, Mid: %.0f-%.0fHz, Treble: %.0f-%.0fHz" % [bass_min, bass_max, mid_min, mid_max, treble_min, treble_max])

## Update analysis settings
## @param smoothing_factor: Smoothing factor for level changes (0.0-1.0)
## @param sample_rate: Audio sample rate
## @param fft_size: FFT size for analysis
func update_analysis_settings(smoothing_factor: float, sample_rate: float = 44100.0, fft_size: int = 2048) -> void:
	_analysis_settings.smoothing_factor = clamp(smoothing_factor, 0.0, 1.0)
	_analysis_settings.sample_rate = sample_rate
	_analysis_settings.fft_size = fft_size
	
	print("AudioAnalyzer: Updated analysis settings - Smoothing: %.3f, Sample Rate: %.0fHz, FFT Size: %d" % [smoothing_factor, sample_rate, fft_size])

## Enable or disable debug output
## @param enabled: Whether to enable debug output
## @param print_interval: Frames between debug prints
func set_debug_enabled(enabled: bool, print_interval: int = 30) -> void:
	_debug_enabled = enabled
	_debug_print_interval = print_interval
	_debug_frame_counter = 0
	
	print("AudioAnalyzer: Debug output %s (interval: %d frames)" % ("enabled" if enabled else "disabled", print_interval))

## Get detailed analysis information for debugging
## @return: Dictionary with analysis information
func get_analysis_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"current_levels": get_current_levels(),
		"frequency_ranges": _frequency_ranges.duplicate(),
		"amplifiers": _amplifiers.duplicate(),
		"analysis_settings": _analysis_settings.duplicate(),
		"debug_enabled": _debug_enabled
	}

## Check if the analyzer is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized and _audio_effect != null

#endregion

#region Utility Methods

## Get the frequency bin for a given frequency
## @param frequency: Frequency in Hz
## @return: Corresponding FFT bin index
func get_frequency_bin(frequency: float) -> int:
	return int(frequency / _analysis_settings.sample_rate * _analysis_settings.fft_size)

## Get the frequency for a given bin
## @param bin_index: FFT bin index
## @return: Corresponding frequency in Hz
func get_bin_frequency(bin_index: int) -> float:
	return bin_index * _analysis_settings.sample_rate / _analysis_settings.fft_size

## Get magnitude for a specific frequency bin
## @param bin_index: FFT bin index
## @return: Magnitude value for the bin
func get_bin_magnitude(bin_index: int) -> float:
	if not _audio_effect or bin_index < 0 or bin_index >= _analysis_settings.fft_size / 2:
		return 0.0
	
	var frequency = get_bin_frequency(bin_index)
	var freq_magnitude = _audio_effect.get_magnitude_for_frequency_range(frequency, frequency + _analysis_settings.sample_rate / _analysis_settings.fft_size)
	return freq_magnitude.length()

## Get spectrum data for visualization
## @param num_bands: Number of frequency bands to return
## @return: Array of magnitude values for visualization
func get_spectrum_data(num_bands: int = 64) -> Array[float]:
	var spectrum_data: Array[float] = []
	
	if not _audio_effect:
		# Return empty array if not initialized
		for i in range(num_bands):
			spectrum_data.append(0.0)
		return spectrum_data
	
	var max_bin = _analysis_settings.fft_size / 2
	var bins_per_band = max_bin / num_bands
	
	for band in range(num_bands):
		var start_bin = int(band * bins_per_band)
		var end_bin = int((band + 1) * bins_per_band)
		var band_magnitude: float = 0.0
		
		# Average magnitude across bins in this band
		for bin_index in range(start_bin, end_bin):
			band_magnitude += get_bin_magnitude(bin_index)
		
		band_magnitude /= (end_bin - start_bin)
		spectrum_data.append(band_magnitude)
	
	return spectrum_data

#endregion

#region Cleanup

## Clean up resources and reset state
func cleanup() -> void:
	print("AudioAnalyzer: Cleaning up resources...")
	
	# Clear references
	_audio_effect = null
	
	# Reset state
	_current_bass = 0.0
	_current_mid = 0.0
	_current_treble = 0.0
	_debug_frame_counter = 0
	
	# Clear configuration
	_frequency_ranges.clear()
	_amplifiers.clear()
	_analysis_settings.clear()
	
	_is_initialized = false
	print("AudioAnalyzer: Cleanup complete")

#endregion
