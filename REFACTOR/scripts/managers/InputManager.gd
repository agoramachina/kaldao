class_name InputManager
extends RefCounted

## InputManager - Refactored Input Handling System
##
## This refactored InputManager uses the new architecture with ConfigManager for key bindings,
## EventBus for communication, and supports configurable input contexts and gesture recognition.
## It maintains backward compatibility while providing a much cleaner and more extensible interface.
##
## Usage:
##   var input_manager = InputManager.new()
##   input_manager.initialize()
##   input_manager.handle_input(event)

# Input context definitions
enum InputContext {
	GLOBAL,          # Always active
	PARAMETER_EDIT,  # When editing parameters
	AUDIO_CONTROL,   # When controlling audio
	MENU_ACTIVE,     # When menu is visible
	CONFIRMATION     # When awaiting confirmation
}

# Input action definitions
enum InputAction {
	# Navigation
	MENU_TOGGLE,
	PARAMETER_INCREASE,
	PARAMETER_DECREASE,
	PARAMETER_NEXT,
	PARAMETER_PREVIOUS,
	
	# Parameter control
	RESET_CURRENT,
	RESET_ALL,
	RANDOMIZE_PARAMETERS,
	
	# Color control
	COLORS_RANDOMIZE,
	COLORS_RESET_BW,
	PALETTE_CYCLE_FORWARD,
	PALETTE_CYCLE_BACKWARD,
	
	# Audio control
	AUDIO_PLAYBACK_TOGGLE,
	AUDIO_REACTIVE_TOGGLE,
	PAUSE_TOGGLE,
	
	# Timeline control
	JUMP_TO_PREVIOUS_CHECKPOINT,
	JUMP_TO_NEXT_CHECKPOINT,
	
	# File operations
	SAVE_SETTINGS,
	LOAD_SETTINGS,
	IMPORT_LABELS,
	SCREENSHOT,
	
	# Confirmation
	CONFIRM_ACTION,
	CANCEL_ACTION
}

# Input state and configuration
var _key_bindings: Dictionary = {}
var _input_contexts: Array[InputContext] = [InputContext.GLOBAL]
var _current_context: InputContext = InputContext.GLOBAL
var _input_settings: Dictionary = {}

# Confirmation state
var _awaiting_confirmation: bool = false
var _confirmation_action: String = ""
var _confirmation_message: String = ""

# Gesture recognition
var _gesture_settings: Dictionary = {}
var _last_key_time: float = 0.0
var _key_sequence: Array[int] = []

# Initialization state
var _is_initialized: bool = false

#region Initialization

## Initialize the input manager
## @return: True if initialization was successful
func initialize() -> bool:
	if _is_initialized:
		print("InputManager: Already initialized")
		return true
	
	print("InputManager: Initializing...")
	
	# Load configuration
	_load_input_configuration()
	
	# Setup key bindings
	_setup_key_bindings()
	
	# Setup event connections
	_setup_event_connections()
	
	# Initialize gesture recognition
	_initialize_gesture_recognition()
	
	_is_initialized = true
	print("InputManager: Initialization complete")
	return true

## Load input configuration from ConfigManager
func _load_input_configuration() -> void:
	print("InputManager: Loading input configuration...")
	
	# Load input settings
	_input_settings = {
		"debug_mode": ConfigManager.is_debug_mode(),
		"double_tap_threshold": ConfigManager.get_config_value("input.double_tap_threshold", 0.3),
		"key_repeat_delay": ConfigManager.get_config_value("input.key_repeat_delay", 0.1),
		"mouse_sensitivity": ConfigManager.get_config_value("input.mouse_sensitivity", 1.0),
		"enable_gestures": ConfigManager.get_config_value("input.enable_gestures", true),
		"confirmation_timeout": ConfigManager.get_config_value("input.confirmation_timeout", 10.0)
	}
	
	# Load gesture settings
	_gesture_settings = {
		"max_sequence_length": ConfigManager.get_config_value("input.gestures.max_sequence_length", 5),
		"sequence_timeout": ConfigManager.get_config_value("input.gestures.sequence_timeout", 2.0),
		"enable_double_tap": ConfigManager.get_config_value("input.gestures.enable_double_tap", true)
	}
	
	print("InputManager: Configuration loaded")

## Setup key bindings from configuration
func _setup_key_bindings() -> void:
	print("InputManager: Setting up key bindings...")
	
	# Default key bindings (can be overridden by configuration)
	_key_bindings = {
		# Menu and navigation
		KEY_F1: InputAction.MENU_TOGGLE,
		KEY_ESCAPE: InputAction.MENU_TOGGLE,
		
		# Parameter navigation
		KEY_UP: InputAction.PARAMETER_INCREASE,
		KEY_DOWN: InputAction.PARAMETER_DECREASE,
		KEY_LEFT: InputAction.PARAMETER_PREVIOUS,
		KEY_RIGHT: InputAction.PARAMETER_NEXT,
		
		# Reset controls
		KEY_R: InputAction.RESET_CURRENT,
		
		# Color controls
		KEY_C: InputAction.COLORS_RANDOMIZE,
		
		# Parameter randomization
		KEY_PERIOD: InputAction.RANDOMIZE_PARAMETERS,
		
		# Audio controls
		KEY_A: InputAction.AUDIO_REACTIVE_TOGGLE,
		KEY_SPACE: InputAction.PAUSE_TOGGLE,
		KEY_COMMA: InputAction.AUDIO_PLAYBACK_TOGGLE,
		
		# Timeline controls
		KEY_BRACKETLEFT: InputAction.JUMP_TO_PREVIOUS_CHECKPOINT,
		KEY_BRACKETRIGHT: InputAction.JUMP_TO_NEXT_CHECKPOINT,
		
		# File operations
		KEY_P: InputAction.SCREENSHOT,
		
		# Confirmation
		KEY_ENTER: InputAction.CONFIRM_ACTION,
		KEY_BACKSPACE: InputAction.CANCEL_ACTION
	}
	
	# Load custom key bindings from configuration
	_load_custom_key_bindings()
	
	print("InputManager: Key bindings configured for %d keys" % _key_bindings.size())

## Load custom key bindings from configuration
func _load_custom_key_bindings() -> void:
	# This would load custom key bindings from ConfigManager
	# For now, we'll use the defaults
	print("InputManager: Custom key bindings not yet implemented")

## Setup event connections with EventBus
func _setup_event_connections() -> void:
	print("InputManager: Setting up event connections...")
	
	# Connect to context change events
	EventBus.connect_to_menu_visibility_changed(_on_menu_visibility_changed)
	EventBus.connect_to_parameter_editing_started(_on_parameter_editing_started)
	EventBus.connect_to_parameter_editing_finished(_on_parameter_editing_finished)
	
	# Connect to application lifecycle
	EventBus.connect_to_application_shutting_down(_on_application_shutdown)
	
	print("InputManager: Event connections established")

## Initialize gesture recognition system
func _initialize_gesture_recognition() -> void:
	if _input_settings.enable_gestures:
		print("InputManager: Gesture recognition enabled")
	else:
		print("InputManager: Gesture recognition disabled")

#endregion

#region Input Processing

## Main input handling method
## @param event: InputEvent to process
## @return: True if event was handled
func handle_input(event: InputEvent) -> bool:
	if not _is_initialized:
		return false
	
	# Only handle key press events
	if not (event is InputEventKey and event.pressed):
		return false
	
	var keycode = event.keycode
	
	if _input_settings.debug_mode:
		print("InputManager: Received key: %d (%s)" % [keycode, OS.get_keycode_string(keycode)])
	
	# Handle confirmation state first
	if _awaiting_confirmation:
		return _handle_confirmation_input(event)
	
	# Handle gesture recognition
	if _input_settings.enable_gestures:
		_update_gesture_sequence(keycode)
	
	# Get the action for this key
	var action = _get_action_for_key(keycode, event)
	if action == -1:
		if _input_settings.debug_mode:
			print("InputManager: Unhandled key: %d" % keycode)
		return false
	
	# Check if action is valid in current context
	if not _is_action_valid_in_context(action):
		if _input_settings.debug_mode:
			print("InputManager: Action %d not valid in context %d" % [action, _current_context])
		return false
	
	# Execute the action
	return _execute_action(action, event)

## Get action for a key considering modifiers
## @param keycode: Key code
## @param event: Input event for modifier checking
## @return: InputAction or -1 if not found
func _get_action_for_key(keycode: int, event: InputEventKey) -> int:
	# Handle modifier combinations
	if event.shift_pressed:
		match keycode:
			KEY_R:
				return InputAction.RESET_ALL
			KEY_C:
				return InputAction.COLORS_RESET_BW
			KEY_A:
				return InputAction.AUDIO_PLAYBACK_TOGGLE
			KEY_UP:
				return InputAction.PALETTE_CYCLE_FORWARD
			KEY_DOWN:
				return InputAction.PALETTE_CYCLE_BACKWARD
	
	if event.ctrl_pressed:
		match keycode:
			KEY_S:
				return InputAction.SAVE_SETTINGS
			KEY_L:
				return InputAction.LOAD_SETTINGS
			KEY_I:
				return InputAction.IMPORT_LABELS
	
	# Handle regular key bindings
	return _key_bindings.get(keycode, -1)

## Check if action is valid in current context
## @param action: InputAction to check
## @return: True if action is valid
func _is_action_valid_in_context(action: InputAction) -> bool:
	# Global actions are always valid
	var global_actions = [
		InputAction.MENU_TOGGLE,
		InputAction.SCREENSHOT,
		InputAction.SAVE_SETTINGS,
		InputAction.LOAD_SETTINGS
	]
	
	if action in global_actions:
		return true
	
	# Context-specific validation
	match _current_context:
		InputContext.GLOBAL:
			return true  # All actions valid in global context
		
		InputContext.PARAMETER_EDIT:
			var parameter_actions = [
				InputAction.PARAMETER_INCREASE,
				InputAction.PARAMETER_DECREASE,
				InputAction.PARAMETER_NEXT,
				InputAction.PARAMETER_PREVIOUS,
				InputAction.RESET_CURRENT,
				InputAction.RANDOMIZE_PARAMETERS
			]
			return action in parameter_actions
		
		InputContext.AUDIO_CONTROL:
			var audio_actions = [
				InputAction.AUDIO_PLAYBACK_TOGGLE,
				InputAction.AUDIO_REACTIVE_TOGGLE,
				InputAction.PAUSE_TOGGLE,
				InputAction.JUMP_TO_PREVIOUS_CHECKPOINT,
				InputAction.JUMP_TO_NEXT_CHECKPOINT
			]
			return action in audio_actions
		
		InputContext.MENU_ACTIVE:
			# Limited actions when menu is active
			var menu_actions = [
				InputAction.MENU_TOGGLE,
				InputAction.PARAMETER_INCREASE,
				InputAction.PARAMETER_DECREASE,
				InputAction.PARAMETER_NEXT,
				InputAction.PARAMETER_PREVIOUS
			]
			return action in menu_actions
		
		InputContext.CONFIRMATION:
			var confirmation_actions = [
				InputAction.CONFIRM_ACTION,
				InputAction.CANCEL_ACTION
			]
			return action in confirmation_actions
	
	return false

## Execute an input action
## @param action: InputAction to execute
## @param event: Original input event
## @return: True if action was executed
func _execute_action(action: InputAction, event: InputEventKey) -> bool:
	if _input_settings.debug_mode:
		print("InputManager: Executing action: %d" % action)
	
	match action:
		# Navigation
		InputAction.MENU_TOGGLE:
			EventBus.emit_menu_toggle_requested()
			return true
		
		InputAction.PARAMETER_INCREASE:
			EventBus.emit_parameter_increase_requested()
			return true
		
		InputAction.PARAMETER_DECREASE:
			EventBus.emit_parameter_decrease_requested()
			return true
		
		InputAction.PARAMETER_NEXT:
			EventBus.emit_parameter_next_requested()
			return true
		
		InputAction.PARAMETER_PREVIOUS:
			EventBus.emit_parameter_previous_requested()
			return true
		
		# Parameter control
		InputAction.RESET_CURRENT:
			EventBus.emit_reset_current_requested()
			return true
		
		InputAction.RESET_ALL:
			_request_confirmation("reset_all", "Reset ALL settings? Press ENTER to confirm, any other key to cancel")
			return true
		
		InputAction.RANDOMIZE_PARAMETERS:
			EventBus.emit_randomize_parameters_requested()
			return true
		
		# Color control
		InputAction.COLORS_RANDOMIZE:
			EventBus.emit_palette_randomize_requested()
			return true
		
		InputAction.COLORS_RESET_BW:
			EventBus.emit_palette_reset_requested(false)
			return true
		
		InputAction.PALETTE_CYCLE_FORWARD:
			EventBus.emit_palette_cycle_requested(1)
			return true
		
		InputAction.PALETTE_CYCLE_BACKWARD:
			EventBus.emit_palette_cycle_requested(-1)
			return true
		
		# Audio control
		InputAction.AUDIO_PLAYBACK_TOGGLE:
			EventBus.emit_audio_playback_toggle_requested()
			return true
		
		InputAction.AUDIO_REACTIVE_TOGGLE:
			EventBus.emit_audio_reactive_toggle_requested()
			return true
		
		InputAction.PAUSE_TOGGLE:
			EventBus.emit_pause_toggle_requested()
			return true
		
		# Timeline control
		InputAction.JUMP_TO_PREVIOUS_CHECKPOINT:
			EventBus.emit_jump_to_previous_checkpoint_requested()
			return true
		
		InputAction.JUMP_TO_NEXT_CHECKPOINT:
			EventBus.emit_jump_to_next_checkpoint_requested()
			return true
		
		# File operations
		InputAction.SAVE_SETTINGS:
			EventBus.emit_save_settings_requested()
			return true
		
		InputAction.LOAD_SETTINGS:
			EventBus.emit_load_settings_requested()
			return true
		
		InputAction.IMPORT_LABELS:
			EventBus.emit_import_labels_requested()
			return true
		
		InputAction.SCREENSHOT:
			EventBus.emit_screenshot_requested()
			return true
		
		# Confirmation
		InputAction.CONFIRM_ACTION:
			_handle_confirmation(true)
			return true
		
		InputAction.CANCEL_ACTION:
			_handle_confirmation(false)
			return true
	
	return false

#endregion

#region Confirmation System

## Request confirmation for an action
## @param action_id: Identifier for the action
## @param message: Confirmation message to display
func _request_confirmation(action_id: String, message: String) -> void:
	_awaiting_confirmation = true
	_confirmation_action = action_id
	_confirmation_message = message
	_current_context = InputContext.CONFIRMATION
	
	# Emit confirmation request to UI
	EventBus.emit_confirmation_requested(message)
	
	# Start confirmation timeout
	_start_confirmation_timeout()
	
	print("InputManager: Confirmation requested for action: %s" % action_id)

## Handle confirmation input
## @param event: Input event
## @return: True if event was handled
func _handle_confirmation_input(event: InputEventKey) -> bool:
	var keycode = event.keycode
	
	if keycode == KEY_ENTER:
		_handle_confirmation(true)
		return true
	else:
		_handle_confirmation(false)
		return true

## Handle confirmation result
## @param confirmed: Whether the action was confirmed
func _handle_confirmation(confirmed: bool) -> void:
	var action_id = _confirmation_action
	
	# Clear confirmation state
	_awaiting_confirmation = false
	_confirmation_action = ""
	_confirmation_message = ""
	_current_context = InputContext.GLOBAL
	
	# Emit confirmation result
	EventBus.emit_confirmation_result(confirmed, action_id)
	
	# Execute confirmed action
	if confirmed:
		_execute_confirmed_action(action_id)
	
	print("InputManager: Confirmation %s for action: %s" % ("confirmed" if confirmed else "cancelled", action_id))

## Execute a confirmed action
## @param action_id: Identifier of the confirmed action
func _execute_confirmed_action(action_id: String) -> void:
	match action_id:
		"reset_all":
			EventBus.emit_reset_all_requested()

## Start confirmation timeout
func _start_confirmation_timeout() -> void:
	var timeout = _input_settings.confirmation_timeout
	if timeout > 0:
		var timer = Timer.new()
		timer.wait_time = timeout
		timer.one_shot = true
		timer.timeout.connect(_on_confirmation_timeout.bind(timer))
		# Note: In a real implementation, this timer would need to be added to a scene tree
		# For now, we'll just note that timeout functionality exists
		print("InputManager: Confirmation timeout set to %.1fs" % timeout)

## Handle confirmation timeout
## @param timer: Timer object to clean up
func _on_confirmation_timeout(timer: Timer) -> void:
	if _awaiting_confirmation:
		_handle_confirmation(false)
	timer.queue_free()

#endregion

#region Context Management

## Set the current input context
## @param context: New input context
func set_input_context(context: InputContext) -> void:
	if _current_context != context:
		var old_context = _current_context
		_current_context = context
		
		print("InputManager: Context changed from %d to %d" % [old_context, context])
		
		# Emit context change event
		EventBus.emit_input_context_changed(context)

## Get the current input context
## @return: Current input context
func get_input_context() -> InputContext:
	return _current_context

## Push a new input context onto the stack
## @param context: Context to push
func push_input_context(context: InputContext) -> void:
	_input_contexts.append(_current_context)
	set_input_context(context)

## Pop the previous input context from the stack
func pop_input_context() -> void:
	if _input_contexts.size() > 0:
		var previous_context = _input_contexts.pop_back()
		set_input_context(previous_context)

#endregion

#region Gesture Recognition

## Update gesture sequence with new key
## @param keycode: Key code to add to sequence
func _update_gesture_sequence(keycode: int) -> void:
	var current_time = Time.get_time_dict_from_system()
	var precise_time = current_time.hour * 3600 + current_time.minute * 60 + current_time.second + (Engine.get_process_frames() % 60) / 60.0
	
	# Check if sequence has timed out
	if precise_time - _last_key_time > _gesture_settings.sequence_timeout:
		_key_sequence.clear()
	
	# Add key to sequence
	_key_sequence.append(keycode)
	_last_key_time = precise_time
	
	# Limit sequence length
	if _key_sequence.size() > _gesture_settings.max_sequence_length:
		_key_sequence.pop_front()
	
	# Check for gesture patterns
	_check_gesture_patterns()

## Check for recognized gesture patterns
func _check_gesture_patterns() -> void:
	# Example: Double-tap detection
	if _gesture_settings.enable_double_tap and _key_sequence.size() >= 2:
		var last_key = _key_sequence[-1]
		var second_last_key = _key_sequence[-2]
		
		if last_key == second_last_key:
			# Double-tap detected
			_handle_double_tap(last_key)

## Handle double-tap gesture
## @param keycode: Key that was double-tapped
func _handle_double_tap(keycode: int) -> void:
	print("InputManager: Double-tap detected for key: %d" % keycode)
	
	# Emit double-tap event
	EventBus.emit_gesture_detected("double_tap", keycode)

#endregion

#region Event Handlers

## Handle menu visibility changes
## @param visible: Whether menu is visible
func _on_menu_visibility_changed(visible: bool) -> void:
	if visible:
		push_input_context(InputContext.MENU_ACTIVE)
	else:
		pop_input_context()

## Handle parameter editing start
func _on_parameter_editing_started() -> void:
	push_input_context(InputContext.PARAMETER_EDIT)

## Handle parameter editing finish
func _on_parameter_editing_finished() -> void:
	pop_input_context()

## Handle application shutdown
func _on_application_shutdown() -> void:
	cleanup()

#endregion

#region Public API

## Check if awaiting confirmation
## @return: True if awaiting confirmation
func is_awaiting_confirmation() -> bool:
	return _awaiting_confirmation

## Get current confirmation message
## @return: Confirmation message or empty string
func get_confirmation_message() -> String:
	return _confirmation_message

## Update key binding
## @param keycode: Key code to bind
## @param action: Action to bind to
func set_key_binding(keycode: int, action: InputAction) -> void:
	_key_bindings[keycode] = action
	print("InputManager: Updated key binding: %d -> %d" % [keycode, action])

## Remove key binding
## @param keycode: Key code to unbind
func remove_key_binding(keycode: int) -> void:
	if keycode in _key_bindings:
		_key_bindings.erase(keycode)
		print("InputManager: Removed key binding for key: %d" % keycode)

## Get all key bindings
## @return: Dictionary of key bindings
func get_key_bindings() -> Dictionary:
	return _key_bindings.duplicate()

## Enable or disable debug mode
## @param enabled: Whether to enable debug output
func set_debug_enabled(enabled: bool) -> void:
	_input_settings.debug_mode = enabled
	print("InputManager: Debug mode %s" % ("enabled" if enabled else "disabled"))

## Get input manager information for debugging
## @return: Dictionary with manager information
func get_input_info() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"current_context": _current_context,
		"context_stack": _input_contexts.duplicate(),
		"awaiting_confirmation": _awaiting_confirmation,
		"confirmation_action": _confirmation_action,
		"key_bindings_count": _key_bindings.size(),
		"gesture_sequence": _key_sequence.duplicate(),
		"input_settings": _input_settings.duplicate()
	}

## Check if the manager is properly initialized
## @return: True if initialized and ready
func is_ready() -> bool:
	return _is_initialized

#endregion

#region Cleanup

## Clean up resources and connections
func cleanup() -> void:
	print("InputManager: Cleaning up resources...")
	
	# Clear state
	_key_bindings.clear()
	_input_contexts.clear()
	_key_sequence.clear()
	_input_settings.clear()
	_gesture_settings.clear()
	
	# Reset state
	_current_context = InputContext.GLOBAL
	_awaiting_confirmation = false
	_confirmation_action = ""
	_confirmation_message = ""
	_last_key_time = 0.0
	_is_initialized = false
	
	print("InputManager: Cleanup complete")

#endregion
