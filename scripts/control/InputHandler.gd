extends RefCounted
class_name InputHandler

# Signals
signal menu_toggle_requested
signal menu_hide_requested
signal parameter_increase_requested
signal parameter_decrease_requested
signal parameter_next_requested
signal parameter_previous_requested
signal reset_current_requested
signal reset_all_requested
signal colors_randomize_requested
signal colors_reset_bw_requested
signal randomize_parameters_requested  # NEW: Signal for randomizing all non-color parameters
signal audio_toggle_requested
signal audio_device_cycle_requested
signal audio_processing_toggle_requested  # New signal for toggling audio processing
signal audio_output_cycle_requested  # New signal for output device cycling
signal pause_toggle_requested
signal screenshot_requested
signal save_settings_requested
signal load_settings_requested

var awaiting_reset_confirmation = false

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	
	print("DEBUG: InputHandler received key: ", event.keycode, " (", OS.get_keycode_string(event.keycode), ")")
	
	# Handle reset confirmation
	if awaiting_reset_confirmation:
		print("DEBUG: In reset confirmation mode")
		if event.keycode == KEY_ENTER:
			print("DEBUG: Reset confirmed")
			reset_all_requested.emit()
			awaiting_reset_confirmation = false
			return true
		else:
			print("DEBUG: Reset cancelled")
			awaiting_reset_confirmation = false
			# Emit a signal or handle reset cancellation
			return true
	
	# Handle menu visibility
	if event.keycode == KEY_F1:
		print("DEBUG: F1 pressed - toggling menu")
		menu_toggle_requested.emit()
		return true
	elif event.keycode == KEY_ESCAPE:
		print("DEBUG: Escape pressed - hiding menu")
		menu_hide_requested.emit()
		return true
	
	# Don't process other controls if menu is visible - this check should be done by caller
	
	match event.keycode:
		# Parameter navigation
		KEY_UP:
			print("DEBUG: Up arrow - increase parameter")
			parameter_increase_requested.emit()
			return true
		KEY_DOWN:
			print("DEBUG: Down arrow - decrease parameter")
			parameter_decrease_requested.emit()
			return true
		KEY_LEFT:
			print("DEBUG: Left arrow - previous parameter")
			parameter_previous_requested.emit()
			return true
		KEY_RIGHT:
			print("DEBUG: Right arrow - next parameter")
			parameter_next_requested.emit()
			return true
		
		# Reset controls
		KEY_R:
			if event.shift_pressed:
				print("DEBUG: Shift+R - reset all (requesting confirmation)")
				# Shift+R: Reset all (with confirmation)
				awaiting_reset_confirmation = true
				# Emit signal for confirmation message
				return true
			else:
				print("DEBUG: R - reset current setting")
				# r: Reset current setting
				reset_current_requested.emit()
				return true
		
		# Color controls
		KEY_C:
			if event.shift_pressed:
				print("DEBUG: Shift+C - reset colors to B&W")
				# Shift+C: Reset to B&W
				colors_reset_bw_requested.emit()
			else:
				print("DEBUG: C - randomize colors")
				# C: Randomize colors
				colors_randomize_requested.emit()
			return true
		
		# NEW: Parameter randomization
		KEY_PERIOD:  # "." key
			print("DEBUG: Period (.) - randomize all non-color parameters")
			randomize_parameters_requested.emit()
			return true
		
		# Save/Load
		KEY_S:
			if event.ctrl_pressed:
				print("DEBUG: Ctrl+S - save settings")
				# Ctrl+S: Save settings
				save_settings_requested.emit()
				return true
		
		KEY_L:
			if event.ctrl_pressed:
				print("DEBUG: Ctrl+L - load settings")
				# Ctrl+L: Load settings
				load_settings_requested.emit()
				return true
		
		# Audio controls
		KEY_A:
			if event.shift_pressed:
				print("DEBUG: Shift+A - toggle audio processing")
				# Shift+A: Toggle audio processing (microphone on/off)
				audio_processing_toggle_requested.emit()
			else:
				print("DEBUG: A - toggle audio reactive")
				# A: Toggle audio reactivity
				audio_toggle_requested.emit()
			return true
		
		# Audio device switching
		KEY_I:
			print("DEBUG: I - cycle input device")
			audio_device_cycle_requested.emit()
			return true
		
		KEY_O:
			print("DEBUG: O - cycle output device")
			audio_output_cycle_requested.emit()
			return true
		
		# Pause
		KEY_SPACE:
			print("DEBUG: SPACE - toggle pause")
			pause_toggle_requested.emit()
			return true
			
		# Screenshot
		KEY_P:
			print("DEBUG: P - take screenshot")
			screenshot_requested.emit()
			return true
	
	print("DEBUG: Unhandled key: ", event.keycode)
	return false

func is_awaiting_reset_confirmation() -> bool:
	return awaiting_reset_confirmation

func get_reset_confirmation_message() -> String:
	return "Reset ALL settings? Press ENTER to confirm, any other key to cancel"
