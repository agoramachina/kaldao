extends AudioStreamPlayer
class_name AudioManager

# Signals
signal bass_detected(intensity: float)
signal mid_detected(intensity: float) 
signal treble_detected(intensity: float)
signal beat_detected()
signal device_changed(device_name: String, is_input: bool)

# Component managers
var device_manager: DeviceManager
var spectrum_analyzer_comp: SpectrumAnalyzerComponent
var audio_reactivity: AudioReactivityManager

# Audio analysis
var spectrum_analyzer: AudioEffectSpectrumAnalyzer
var audio_effect: AudioEffectSpectrumAnalyzerInstance

# Audio stream for microphone
var microphone_stream: AudioStreamMicrophone

# Current device state
var current_input_device_index = 0
var current_output_device_index = 0
var available_input_devices: PackedStringArray = []
var available_output_devices: PackedStringArray = []

# Audio processing state
var is_audio_enabled = false

func _ready():
	print("AudioManager: Initializing...")
	
	# Initialize component managers
	device_manager = DeviceManager.new()
	spectrum_analyzer_comp = SpectrumAnalyzerComponent.new()
	audio_reactivity = AudioReactivityManager.new()
	
	# Connect components
	connect_components()
	
	# Setup audio system
	setup_audio_system()

func connect_components():
	# Connect device manager signals
	device_manager.device_changed.connect(on_device_changed)
	
	# Connect spectrum analyzer signals
	spectrum_analyzer_comp.bass_detected.connect(bass_detected.emit)
	spectrum_analyzer_comp.mid_detected.connect(mid_detected.emit)
	spectrum_analyzer_comp.treble_detected.connect(treble_detected.emit)
	spectrum_analyzer_comp.beat_detected.connect(beat_detected.emit)
	
	# CRITICAL: Connect audio reactivity to the detection signals
	spectrum_analyzer_comp.bass_detected.connect(audio_reactivity.on_bass_detected)
	spectrum_analyzer_comp.mid_detected.connect(audio_reactivity.on_mid_detected)
	spectrum_analyzer_comp.treble_detected.connect(audio_reactivity.on_treble_detected)
	spectrum_analyzer_comp.beat_detected.connect(audio_reactivity.on_beat_detected)
	
	print("AudioManager: Components connected")

func setup_audio_system():
	print("AudioManager: Setting up audio system...")
	
	# Enumerate available devices
	device_manager.enumerate_devices()
	available_input_devices = AudioServer.get_input_device_list()
	available_output_devices = AudioServer.get_output_device_list()
	
	if available_input_devices.size() == 0:
		print("AudioManager: No input devices found!")
		return
	
	# Create microphone stream
	microphone_stream = AudioStreamMicrophone.new()
	
	# Set up spectrum analyzer effect on Master bus
	setup_spectrum_analyzer()
	
	# Start with first available input device
	switch_to_input_device(0)
	
	print("AudioManager: Audio system setup complete")

func setup_spectrum_analyzer():
	# Create spectrum analyzer effect
	spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
	spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	spectrum_analyzer.buffer_length = 2.0
	
	# Add the effect to the Master bus
	var bus_index = AudioServer.get_bus_index("Master")
	
	# Remove any existing spectrum analyzer effects first
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	for i in range(effect_count - 1, -1, -1):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectSpectrumAnalyzer:
			AudioServer.remove_bus_effect(bus_index, i)
			print("AudioManager: Removed existing spectrum analyzer effect")
	
	# Add our spectrum analyzer
	AudioServer.add_bus_effect(bus_index, spectrum_analyzer)
	print("AudioManager: Added spectrum analyzer to Master bus")
	
	# Get the effect instance
	var effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	audio_effect = AudioServer.get_bus_effect_instance(bus_index, effect_index) as AudioEffectSpectrumAnalyzerInstance
	
	if audio_effect:
		spectrum_analyzer_comp.set_audio_effect(audio_effect)
		print("AudioManager: Spectrum analyzer effect instance connected")
	else:
		print("AudioManager: ERROR - Could not get spectrum analyzer effect instance!")

func switch_to_input_device(device_index: int):
	if device_index >= available_input_devices.size():
		print("AudioManager: Invalid device index: ", device_index)
		return
	
	# Stop current audio
	stop()
	
	# Set the input device
	var device_name = available_input_devices[device_index]
	AudioServer.set_input_device(device_name)
	current_input_device_index = device_index
	
	# Configure the audio stream player
	stream = microphone_stream
	
	# Start capturing audio
	play()
	is_audio_enabled = true
	
	print("AudioManager: Switched to input device: ", device_name)
	device_changed.emit(device_name, true)

func cycle_input_device():
	if available_input_devices.size() <= 1:
		print("AudioManager: No other input devices available")
		return
	
	# Cycle to next device
	var next_index = (current_input_device_index + 1) % available_input_devices.size()
	switch_to_input_device(next_index)

func cycle_output_device():
	if available_output_devices.size() <= 1:
		print("AudioManager: No other output devices available")
		return
	
	# Cycle to next output device
	current_output_device_index = (current_output_device_index + 1) % available_output_devices.size()
	var device_name = available_output_devices[current_output_device_index]
	AudioServer.set_output_device(device_name)
	
	print("AudioManager: Switched to output device: ", device_name)
	device_changed.emit(device_name, false)

func cycle_audio_device():
	# This function now cycles input devices (for backward compatibility)
	cycle_input_device()

func toggle_audio_processing() -> bool:
	if is_audio_enabled:
		stop()
		is_audio_enabled = false
		print("AudioManager: Audio processing disabled")
	else:
		if available_input_devices.size() > 0:
			switch_to_input_device(current_input_device_index)
			print("AudioManager: Audio processing enabled")
		else:
			print("AudioManager: No audio devices available")
	
	return is_audio_enabled

func _process(delta):
	# Only process audio if we have the effect and audio is enabled
	if audio_effect and is_audio_enabled and playing:
		spectrum_analyzer_comp.process_audio()

func get_current_input_device() -> String:
	if current_input_device_index < available_input_devices.size():
		return available_input_devices[current_input_device_index]
	return "No device"

func get_current_output_device() -> String:
	if current_output_device_index < available_output_devices.size():
		return available_output_devices[current_output_device_index]
	return "No output device"

func get_current_audio_device_info() -> String:
	var input_device = get_current_input_device()
	var status = "ON" if is_audio_enabled else "OFF"
	return "Audio Input (%s): %s" % [status, input_device]

func is_audio_reactive() -> bool:
	return audio_reactivity.is_audio_reactive() if audio_reactivity else false

func toggle_audio_reactive() -> bool:
	if audio_reactivity:
		return audio_reactivity.toggle_audio_reactive()
	return false

func on_device_changed(device_name: String, is_input: bool):
	device_changed.emit(device_name, is_input)

# Debug function to check audio levels
func get_audio_levels() -> Dictionary:
	if spectrum_analyzer_comp:
		return {
			"bass": spectrum_analyzer_comp.get_bass_intensity(),
			"mid": spectrum_analyzer_comp.get_mid_intensity(),
			"treble": spectrum_analyzer_comp.get_treble_intensity(),
			"overall": spectrum_analyzer_comp.get_overall_volume()
		}
	return {"bass": 0.0, "mid": 0.0, "treble": 0.0, "overall": 0.0}
