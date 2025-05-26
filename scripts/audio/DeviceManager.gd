extends RefCounted
class_name DeviceManager

# Signals
signal device_changed(device_name: String, is_input: bool)

# Device management
var input_devices: PackedStringArray = []
var output_devices: PackedStringArray = []
var current_input_index = 0
var current_output_index = 0

func enumerate_devices():
	# Get input devices (microphones) - Godot 4 API
	var input_device_list = AudioServer.get_input_device_list()
	for device_name in input_device_list:
		input_devices.append(device_name)
		print("Input device: %s" % device_name)
	
	# Get output devices (speakers) - Godot 4 API  
	var output_device_list = AudioServer.get_output_device_list()
	for device_name in output_device_list:
		output_devices.append(device_name)
		print("Output device: %s" % device_name)
	
	print("Found %d input devices and %d output devices" % [input_devices.size(), output_devices.size()])

func setup_microphone_input(audio_player: AudioStreamPlayer):
	# Set the current input device
	if input_devices.size() > 0:
		AudioServer.set_input_device(input_devices[current_input_index])
		print("Set input device to: ", input_devices[current_input_index])
	
	# Create an audio stream for microphone input
	var audio_stream = AudioStreamMicrophone.new()
	audio_player.stream = audio_stream
	
	# Start playing (this will capture microphone input)
	audio_player.play()

func cycle_output_device() -> bool:
	if output_devices.size() <= 1:
		return false  # No other output devices available
	
	# Cycle to next device
	current_output_index = (current_output_index + 1) % output_devices.size()
	
	# Set the output device
	AudioServer.set_output_device(output_devices[current_output_index])
	
	var device_name = output_devices[current_output_index]
	device_changed.emit(device_name, false)
	print("Switched to output device: ", device_name)
	return true

func cycle_input_device(audio_player: AudioStreamPlayer) -> bool:
	if input_devices.size() <= 1:
		return false  # No other input devices available
	
	# Stop current playback
	audio_player.stop()
	
	# Cycle to next device
	current_input_index = (current_input_index + 1) % input_devices.size()
	
	# Set up new device
	setup_microphone_input(audio_player)
	
	var device_name = input_devices[current_input_index]
	device_changed.emit(device_name, true)
	print("Switched to input device: ", device_name)
	return true

func get_current_input_device() -> String:
	if input_devices.size() > 0:
		return input_devices[current_input_index]
	return "No input device"

func get_current_output_device() -> String:
	if output_devices.size() > 0:
		return output_devices[current_output_index]
	return "No output device"
