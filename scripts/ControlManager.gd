extends Control
# This script gets attached to your main Control node

@onready var label = $RichTextLabel
@onready var settings_label = $"RichTextLabel-L"
@onready var commands_label = $"RichTextLabel-R"
@onready var canvas = $ColorRect

# Component managers
var menu_manager: MenuManager
var input_handler: InputHandler
var ui_components: UIComponents
var parameter_manager: ParameterManager

var tween: Tween
var parameter_display_active = false  # Track if parameter display is currently running
var fade_timer: Timer  # Timer for the fade delay

func _ready():
	# Force window and control size FIRST
	print("DEBUG: Setting up window size...")
	
	# Set the window size
	get_window().size = Vector2i(1900, 1200)
	print("DEBUG: Window size set to: ", get_window().size)
	
	# Set the control node size to match
	size = Vector2(1900, 1200)
	position = Vector2.ZERO
	print("DEBUG: Control size set to: ", size)
	print("DEBUG: Control position set to: ", position)
	
	# Force the canvas (ColorRect) to match
	canvas.size = Vector2(1900, 1200)
	canvas.position = Vector2.ZERO
	print("DEBUG: Canvas size set to: ", canvas.size)
	
	# Initialize component managers
	menu_manager = MenuManager.new(settings_label, commands_label, label)
	input_handler = InputHandler.new()
	ui_components = UIComponents.new(self, settings_label, commands_label, label, canvas)
	
	# Initialize parameter manager (if not already done)
	if not parameter_manager:
		parameter_manager = ParameterManager.new()
	
	# Create fade timer
	fade_timer = Timer.new()
	fade_timer.wait_time = 1.5  # 1.5 second delay before fade
	fade_timer.one_shot = true
	fade_timer.timeout.connect(start_parameter_fade)
	add_child(fade_timer)
	
	# Connect to canvas signals
	canvas.connect("update_text", on_text_update)
	
	# Setup UI
	ui_components.setup_ui()
	ui_components.on_window_resized()  # Force UI to recalculate positions
	
	# Setup menu manager with backgrounds
	var backgrounds = ui_components.get_backgrounds()
	menu_manager.set_backgrounds(backgrounds[0], backgrounds[1], backgrounds[2])
	
	# Connect input handler signals
	connect_input_signals()

	# Show the menu by default on startup with auto-fade
	show_settings_menu()
	auto_fade_startup_menu()

func _on_window_resized():
	var viewport_size = get_viewport().get_visible_rect().size
	print("Window resized to: ", viewport_size)
	print("Canvas size: ", canvas.size)

func connect_input_signals():
	input_handler.menu_toggle_requested.connect(toggle_settings_menu)
	input_handler.menu_hide_requested.connect(hide_settings_menu)
	input_handler.parameter_increase_requested.connect(on_parameter_increase)
	input_handler.parameter_decrease_requested.connect(on_parameter_decrease)
	input_handler.parameter_next_requested.connect(on_parameter_next)
	input_handler.parameter_previous_requested.connect(on_parameter_previous)
	input_handler.reset_current_requested.connect(canvas.reset_current_setting)
	input_handler.reset_all_requested.connect(canvas.reset_all_settings)
	input_handler.randomize_parameters_requested.connect(canvas.randomize_parameters)
	input_handler.colors_randomize_requested.connect(canvas.randomize_colors)
	input_handler.colors_reset_bw_requested.connect(canvas.reset_colors_to_bw)
	input_handler.audio_toggle_requested.connect(canvas.toggle_audio_reactive)
	input_handler.audio_device_cycle_requested.connect(canvas.cycle_audio_device)
	input_handler.audio_output_cycle_requested.connect(canvas.cycle_output_device)  # New connection
	input_handler.audio_processing_toggle_requested.connect(canvas.toggle_audio_processing)  # New connection
	input_handler.pause_toggle_requested.connect(canvas.toggle_pause)
	input_handler.screenshot_requested.connect(canvas.take_screenshot)
	input_handler.save_settings_requested.connect(canvas.save_settings)
	input_handler.load_settings_requested.connect(canvas.load_settings)

func on_parameter_next():
	# Clear any existing parameter display immediately
	clear_parameter_display()
	# Navigate to next parameter (this will trigger update_parameter_display)
	canvas.next_setting()
	# Reset the fade timer since user is actively navigating
	reset_fade_timer()

func on_parameter_previous():
	# Clear any existing parameter display immediately
	clear_parameter_display()
	# Navigate to previous parameter (this will trigger update_parameter_display)
	canvas.previous_setting()
	# Reset the fade timer since user is actively navigating
	reset_fade_timer()

func on_parameter_increase():
	# Don't clear display for value changes, just reset timer
	canvas.increase_setting()
	reset_fade_timer()

func on_parameter_decrease():
	# Don't clear display for value changes, just reset timer
	canvas.decrease_setting()
	reset_fade_timer()
	
func clear_parameter_display():
	# Stop any active parameter display
	if parameter_display_active:
		if tween:
			tween.kill()
		if fade_timer:
			fade_timer.stop()
		parameter_display_active = false
		
		# Hide label immediately and reset
		label.visible = false
		label.modulate.a = 1.0
		
		# Hide background too
		var backgrounds = ui_components.get_backgrounds()
		var main_background = backgrounds[2]
		if main_background:
			main_background.visible = false

func reset_fade_timer():
	# Reset the fade timer - this keeps the popup visible while user is active
	if fade_timer and parameter_display_active:
		fade_timer.stop()
		fade_timer.start()

func start_parameter_fade():
	# This is called by the timer - start the actual fade out
	if not parameter_display_active or menu_manager.is_menu_visible():
		return
	
	# Create fade tween
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Wait for fade to complete
	await tween.finished
	
	# Hide and reset (only if menu isn't visible)
	if not menu_manager.is_menu_visible():
		label.visible = false
		label.modulate.a = 1.0
	
	parameter_display_active = false

func auto_fade_startup_menu():
	# Auto-fade the startup menu after 8 seconds using a timer
	await get_tree().create_timer(8.0).timeout
	if menu_manager.is_first_launch() and menu_manager.is_menu_visible():
		hide_settings_menu()

func _input(event):
	# Handle reset confirmation first
	if input_handler.is_awaiting_reset_confirmation():
		if input_handler.handle_input(event):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
				# Reset confirmed - no additional message needed as canvas handles it
				pass
			else:
				# Reset cancelled
				on_text_update("Reset cancelled")
		return
	
	# Handle menu visibility
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			toggle_settings_menu()
			return
		elif event.keycode == KEY_ESCAPE and menu_manager.is_menu_visible():
			hide_settings_menu()
			return
	
	# Don't process other controls if menu is visible
	if menu_manager.is_menu_visible():
		return
	
	# Handle other input
	if input_handler.handle_input(event):
		# Check for reset confirmation request
		if input_handler.is_awaiting_reset_confirmation():
			on_text_update(input_handler.get_reset_confirmation_message())

func toggle_settings_menu():
	menu_manager.set_first_launch(false)  # No longer first launch after manual toggle
	if menu_manager.is_menu_visible():
		hide_settings_menu()
	else:
		show_settings_menu()

func show_settings_menu():
	var settings_text = canvas.get_all_settings_text()
	menu_manager.show_settings_menu(settings_text)

func hide_settings_menu():
	if not menu_manager.is_menu_visible():
		return
		
	# Get elements to fade
	var fade_elements = menu_manager.start_fade_out()
	
	if fade_elements.size() == 0:
		# Nothing to fade, just hide instantly
		menu_manager.hide_settings_menu_instant()
		canvas.update_parameter_display()
		return
	
	# Create fade-out tween
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out all elements
	for element in fade_elements.values():
		tween.tween_property(element, "modulate:a", 0.0, 1.0)
	
	# Wait for fade to complete, then hide everything
	await tween.finished
	menu_manager.complete_fade_out()
	canvas.update_parameter_display()

func on_text_update(text):
	# Prevent multiple parameter displays from running simultaneously
	if parameter_display_active:
		# Kill existing tween and timer, but keep the display active
		if tween:
			tween.kill()
		if fade_timer:
			fade_timer.stop()
	else:
		# Start new parameter display
		parameter_display_active = true
	
	show_parameter_text_immediately(text)

func show_parameter_text_immediately(text: String):
	# Don't show parameter updates if menu is visible
	if menu_manager.is_menu_visible():
		parameter_display_active = false
		return
	
	# Show the label immediately (NO BACKGROUND for parameter updates)
	label.visible = true
	label.modulate = Color.WHITE
	label.text = text
	
	# Hide the background for parameter updates
	var backgrounds = ui_components.get_backgrounds()
	var main_background = backgrounds[2]
	if main_background:
		main_background.visible = false
	
	# Start the fade timer (will restart if already running)
	fade_timer.start()
