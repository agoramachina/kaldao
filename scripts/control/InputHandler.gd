extends RefCounted
class_name InputHandler

# Signals
signal menu_toggle_requested
signal parameter_increase_requested
signal parameter_decrease_requested
signal parameter_next_requested
signal parameter_previous_requested
signal reset_current_requested
signal reset_all_requested
signal colors_randomize_requested
signal colors_reset_bw_requested
signal randomize_parameters_requested
signal audio_playback_toggle_requested
signal audio_reactive_toggle_requested
signal import_labels_requested
signal jump_to_previous_checkpoint_requested
signal jump_to_next_checkpoint_requested
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
			return true
	
	# Handle menu visibility
	if event.keycode == KEY_F1:
		print("DEBUG: F1 pressed - toggling menu")
		menu_toggle_requested.emit()
		return true
	elif event.keycode == KEY_ESCAPE:
		print("DEBUG: Escape pressed - toggling menu")
		menu_toggle_requested.emit()
		return true
	
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
				awaiting_reset_confirmation = true
				return true
			else:
				print("DEBUG: R - reset current setting")
				reset_current_requested.emit()
				return true
		
		# Color controls
		KEY_C:
			if event.shift_pressed:
				print("DEBUG: Shift+C - reset colors to B&W")
				colors_reset_bw_requested.emit()
			else:
				print("DEBUG: C - randomize colors")
				colors_randomize_requested.emit()
			return true
		
		# Parameter randomization
		KEY_PERIOD:  # "." key
			print("DEBUG: Period (.) - randomize all non-color parameters")
			randomize_parameters_requested.emit()
			return true
		
		# Save/Load
		KEY_S:
			if event.ctrl_pressed:
				print("DEBUG: Ctrl+S - save settings")
				save_settings_requested.emit()
				return true
		
		KEY_L:
			if event.ctrl_pressed:
				print("DEBUG: Ctrl+L - load settings")
				load_settings_requested.emit()
				return true
		
		# Audio controls
		KEY_A:
			if event.shift_pressed:
				print("DEBUG: Shift+A - toggle audio playback")
				audio_playback_toggle_requested.emit()
			else:
				print("DEBUG: A - toggle audio reactive")
				audio_reactive_toggle_requested.emit()
			return true
		
		# Import Audacity Labels
		KEY_I:
			if event.ctrl_pressed:
				print("DEBUG: Ctrl+I - import labels")
				import_labels_requested.emit()
				return true
		
		# Jump to checkpoints		
		KEY_BRACKETLEFT:  # "[" key
			print("DEBUG: [ - jump to previous checkpoint")
			jump_to_previous_checkpoint_requested.emit()
			return true

		KEY_BRACKETRIGHT:  # "]" key
			print("DEBUG: ] - jump to next checkpoint")
			jump_to_next_checkpoint_requested.emit()
			return true		
		
		# Pause
		KEY_SPACE:
			print("DEBUG: SPACE - toggle pause")
			pause_toggle_requested.emit()
			return true
		
		# Pause Music (and visualiser)
		KEY_COMMA:
			print("DEBUG: COMMA - toggle music")
			audio_playback_toggle_requested.emit()
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
