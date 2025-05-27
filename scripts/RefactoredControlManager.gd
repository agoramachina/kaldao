extends Control
# Refactored version of ControlManager using the new architecture

@onready var label = $RichTextLabel
@onready var settings_label = $"RichTextLabel-L"
@onready var commands_label = $"RichTextLabel-R"
@onready var canvas = $ColorRect

# UI Components (still needed for direct UI manipulation)
var menu_manager: MenuManager
var input_handler: InputHandler
var ui_components: UIComponents

# Core managers accessed through ServiceLocator
var parameter_manager: ParameterManager
var color_palette_manager: ColorPaletteManager
var shader_controller: ShaderController
var audio_manager: AudioManager
var screenshot_manager: ScreenshotManager
var song_settings: SongSettings

var tween: Tween
var parameter_display_active = false
var fade_timer: Timer

func _ready():
	# Initialize the application architecture
	if not ApplicationBootstrap.initialize():
		push_error("Failed to initialize application")
		return
	
	# Get services from ServiceLocator
	_get_services()
	
	# Initialize UI components (these still need direct references)
	_initialize_ui_components()
	
	# Setup event connections
	_setup_event_connections()
	
	# Register scene-specific managers
	_register_scene_managers()
	
	# Final setup
	_final_setup()

func _get_services():
	"""Get all services from ServiceLocator"""
	var managers = ApplicationBootstrap.get_core_managers()
	
	parameter_manager = managers.parameter_manager
	color_palette_manager = managers.color_palette_manager
	shader_controller = managers.shader_controller
	audio_manager = managers.audio_manager
	screenshot_manager = managers.screenshot_manager
	song_settings = managers.song_settings
	
	print("RefactoredControlManager: Retrieved services from ServiceLocator")

func _initialize_ui_components():
	"""Initialize UI components that need direct node references"""
	print("RefactoredControlManager: Initializing UI components...")
	
	# Set window size
	print("DEBUG: Window size set to: ", get_window().size)
	print("DEBUG: Canvas size set to: ", canvas.size)
	
	# Initialize UI managers
	menu_manager = MenuManager.new(settings_label, commands_label, label)
	input_handler = InputHandler.new()
	ui_components = UIComponents.new(self, settings_label, commands_label, label, canvas)
	
	# Create fade timer
	fade_timer = Timer.new()
	fade_timer.wait_time = ConfigManager.get_auto_fade_delay()
	fade_timer.one_shot = true
	fade_timer.timeout.connect(start_parameter_fade)
	add_child(fade_timer)
	
	# Setup UI
	ui_components.setup_ui()
	ui_components.on_window_resized()
	
	# Setup menu manager with backgrounds
	var backgrounds = ui_components.get_backgrounds()
	menu_manager.set_backgrounds(backgrounds[0], backgrounds[1], backgrounds[2])

func _setup_event_connections():
	"""Setup event connections using EventBus"""
	print("RefactoredControlManager: Setting up event connections...")
	
	# Connect to EventBus signals
	EventBus.connect_to_text_update_requested(on_text_update)
	EventBus.connect_to_screenshot_completed(on_screenshot_completed)
	EventBus.connect_to_checkpoint_reached(on_checkpoint_reached)
	EventBus.connect_to_menu_visibility_changed(on_menu_visibility_changed)
	
	# Connect input handler signals (these still use direct connections for UI responsiveness)
	_connect_input_signals()

func _register_scene_managers():
	"""Register managers that are created in the scene"""
	print("RefactoredControlManager: Registering scene managers...")
	
	# Register audio manager (found in scene)
	var audio_stream_player = get_node("../AudioStreamPlayer") as AudioManager
	if audio_stream_player:
		ApplicationBootstrap.register_audio_manager(audio_stream_player)
		audio_manager = audio_stream_player
	
	# Register shader controller (created with canvas material)
	if canvas and canvas.material:
		var canvas_shader_controller = ShaderController.new(canvas.material)
		ApplicationBootstrap.register_shader_controller(canvas_shader_controller)
		shader_controller = canvas_shader_controller
	
	# Setup song settings connections
	ApplicationBootstrap.setup_song_settings_connections()

func _final_setup():
	"""Final setup after all systems are initialized"""
	print("RefactoredControlManager: Performing final setup...")
	
	# Make ColorRect fill the entire window
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add timeline component
	var timeline_component = TimelineComponent.new()
	add_child(timeline_component)
	timeline_component.connect_managers(audio_manager, song_settings)
	timeline_component.z_index = 1000
	
	# Connect timeline signals
	timeline_component.seek_requested.connect(_on_timeline_seek)
	timeline_component.play_pause_requested.connect(_on_timeline_play_pause)
	
	# Import labels
	if song_settings:
		song_settings.import_audacity_labels("res://assets/Lyrics.txt")
	
	# Initial parameter update
	if shader_controller and parameter_manager:
		shader_controller.update_all_parameters(parameter_manager.get_all_parameters())
	
	if color_palette_manager:
		color_palette_manager.emit_current_palette()
	
	# Show startup menu
	show_settings_menu()
	auto_fade_startup_menu()

func _connect_input_signals():
	"""Connect input handler signals"""
	input_handler.menu_toggle_requested.connect(toggle_settings_menu)
	input_handler.parameter_increase_requested.connect(_on_parameter_increase)
	input_handler.parameter_decrease_requested.connect(_on_parameter_decrease)
	input_handler.parameter_next_requested.connect(_on_parameter_next)
	input_handler.parameter_previous_requested.connect(_on_parameter_previous)
	input_handler.reset_current_requested.connect(_on_reset_current)
	input_handler.reset_all_requested.connect(_on_reset_all)
	input_handler.randomize_parameters_requested.connect(_on_randomize_parameters)
	input_handler.colors_randomize_requested.connect(_on_randomize_colors)
	input_handler.colors_reset_bw_requested.connect(_on_reset_colors_bw)
	input_handler.audio_playback_toggle_requested.connect(_on_audio_playback_toggle)
	input_handler.audio_reactive_toggle_requested.connect(_on_audio_reactive_toggle)
	input_handler.pause_toggle_requested.connect(_on_pause_toggle)
	input_handler.screenshot_requested.connect(_on_screenshot_requested)
	input_handler.save_settings_requested.connect(_on_save_settings)
	input_handler.load_settings_requested.connect(_on_load_settings)
	input_handler.import_labels_requested.connect(_on_import_labels)
	input_handler.jump_to_previous_checkpoint_requested.connect(_on_jump_previous_checkpoint)
	input_handler.jump_to_next_checkpoint_requested.connect(_on_jump_next_checkpoint)

# Event handlers using the new architecture
func _on_parameter_increase():
	if not parameter_manager:
		return
	
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_forward()
	else:
		parameter_manager.increase_current_parameter()
	_emit_current_parameter_info()
	reset_fade_timer()

func _on_parameter_decrease():
	if not parameter_manager:
		return
	
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.cycle_palette_backward()
	else:
		parameter_manager.decrease_current_parameter()
	_emit_current_parameter_info()
	reset_fade_timer()

func _on_parameter_next():
	clear_parameter_display()
	if parameter_manager:
		parameter_manager.next_parameter()
		_emit_current_parameter_info()
	reset_fade_timer()

func _on_parameter_previous():
	clear_parameter_display()
	if parameter_manager:
		parameter_manager.previous_parameter()
		_emit_current_parameter_info()
	reset_fade_timer()

func _on_reset_current():
	if not parameter_manager:
		return
	
	var param_name = parameter_manager.get_current_parameter_name()
	if param_name == "color_palette":
		color_palette_manager.reset_to_bw()
		EventBus.emit_text_update_requested("Reset Color Palette to default: B&W")
	else:
		parameter_manager.reset_current_parameter()
		var param_value = parameter_manager.get_parameter_value(param_name)
		EventBus.emit_text_update_requested("Reset %s to default: %.2f" % [param_name, param_value])

func _on_reset_all():
	if parameter_manager:
		parameter_manager.reset_all_parameters()
	if color_palette_manager:
		color_palette_manager.reset_to_bw()
	EventBus.emit_text_update_requested("All settings reset to defaults")

func _on_randomize_parameters():
	if parameter_manager:
		parameter_manager.randomize_non_color_parameters()
		EventBus.emit_text_update_requested("Randomized all parameters!\n[C] for colors  [.] for parameters again")

func _on_randomize_colors():
	if color_palette_manager:
		color_palette_manager.randomize_colors()
		EventBus.emit_text_update_requested("Colors randomized! Use Shift+C to reset to B&W")

func _on_reset_colors_bw():
	if color_palette_manager:
		color_palette_manager.reset_to_bw()
		EventBus.emit_text_update_requested("Colors reset to Black & White")

func _on_audio_playback_toggle():
	if audio_manager:
		var is_playing = audio_manager.toggle_audio_playback()
		EventBus.emit_audio_playback_toggled(is_playing)
		EventBus.emit_text_update_requested("Audio Playback: %s" % ("ON" if is_playing else "OFF"))

func _on_audio_reactive_toggle():
	if audio_manager:
		var is_reactive = audio_manager.toggle_audio_reactive()
		EventBus.emit_audio_reactive_toggled(is_reactive)
		var status = "ON" if is_reactive else "OFF"
		if is_reactive:
			EventBus.emit_text_update_requested("Audio Reactive: %s\nVisuals now respond to the music!" % status)
		else:
			EventBus.emit_text_update_requested("Audio Reactive: %s" % status)

func _on_pause_toggle():
	if parameter_manager:
		parameter_manager.toggle_pause()
		var status = "PAUSED" if parameter_manager.get_is_paused() else "RESUMED"
		EventBus.emit_text_update_requested("Animation: %s" % status)

func _on_screenshot_requested():
	EventBus.emit_screenshot_requested()
	if screenshot_manager:
		screenshot_manager.capture_screenshot(get_viewport())

func _on_save_settings():
	# Use the existing save logic but emit events
	_save_settings_with_events()

func _on_load_settings():
	# Use the existing load logic but emit events
	_load_settings_with_events()

func _on_import_labels():
	if song_settings:
		var success = song_settings.import_audacity_labels("res://assets/Lyrics.txt")
		if success:
			EventBus.emit_text_update_requested("Imported %d checkpoints from labels" % song_settings.checkpoints.size())
		else:
			EventBus.emit_text_update_requested("Failed to import labels")

func _on_jump_previous_checkpoint():
	if not song_settings or not audio_manager:
		EventBus.emit_text_update_requested("Song settings or audio not available")
		return
	
	var current_time = audio_manager.get_playback_position()
	var target_checkpoint = null
	
	for i in range(song_settings.checkpoints.size() - 1, -1, -1):
		var checkpoint = song_settings.checkpoints[i]
		if checkpoint.timestamp < current_time - 0.5:
			target_checkpoint = checkpoint
			break
	
	if target_checkpoint:
		audio_manager.seek(target_checkpoint.timestamp)
		EventBus.emit_checkpoint_reached(target_checkpoint.timestamp, target_checkpoint.name)
		EventBus.emit_text_update_requested("◀ %.1fs - %s" % [target_checkpoint.timestamp, target_checkpoint.name])
	else:
		audio_manager.seek(0.0)
		EventBus.emit_text_update_requested("◀ Jumped to beginning")

func _on_jump_next_checkpoint():
	if not song_settings or not audio_manager:
		EventBus.emit_text_update_requested("Song settings or audio not available")
		return
	
	var current_time = audio_manager.get_playback_position()
	var target_checkpoint = null
	
	for checkpoint in song_settings.checkpoints:
		if checkpoint.timestamp > current_time + 0.5:
			target_checkpoint = checkpoint
			break
	
	if target_checkpoint:
		audio_manager.seek(target_checkpoint.timestamp)
		EventBus.emit_checkpoint_reached(target_checkpoint.timestamp, target_checkpoint.name)
		EventBus.emit_text_update_requested("▶ %.1fs - %s" % [target_checkpoint.timestamp, target_checkpoint.name])
	else:
		EventBus.emit_text_update_requested("▶ No more checkpoints ahead")

func _on_timeline_seek(timestamp: float):
	if audio_manager:
		audio_manager.seek(timestamp)
		EventBus.emit_text_update_requested("Seeked to: %s" % _format_timeline_time(timestamp))

func _on_timeline_play_pause():
	_on_audio_playback_toggle()

# EventBus event handlers
func on_text_update(text: String):
	if parameter_display_active:
		if tween:
			tween.kill()
		if fade_timer:
			fade_timer.stop()
	else:
		parameter_display_active = true
	
	show_parameter_text_immediately(text)

func on_screenshot_completed(file_path: String):
	EventBus.emit_text_update_requested("Screenshot saved to:\n%s" % file_path)

func on_checkpoint_reached(timestamp: float, name: String):
	# Show checkpoint popup (existing logic)
	pass

func on_menu_visibility_changed(is_visible: bool):
	# Handle menu visibility changes
	pass

# Helper methods
func _emit_current_parameter_info():
	if not parameter_manager:
		return
	
	var param_name = parameter_manager.get_current_parameter_name()
	var display_text = ""
	
	if param_name == "color_palette":
		display_text = color_palette_manager.get_current_palette_display()
	else:
		display_text = parameter_manager.get_current_parameter_display()
	
	if display_text != "":
		EventBus.emit_text_update_requested(display_text)

func _save_settings_with_events():
	# Implement save logic with event emission
	if parameter_manager and color_palette_manager:
		var settings_data = {
			"parameters": parameter_manager.get_all_parameters(),
			"palette": color_palette_manager.save_palette_data(),
			"version": "1.0",
			"timestamp": Time.get_datetime_string_from_system()
		}
		
		# Save logic here...
		EventBus.emit_settings_saved("settings_file_path")

func _load_settings_with_events():
	# Implement load logic with event emission
	# Load logic here...
	EventBus.emit_settings_loaded("settings_file_path")

func _format_timeline_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

# Existing UI methods (unchanged)
func clear_parameter_display():
	if parameter_display_active:
		if tween:
			tween.kill()
		if fade_timer:
			fade_timer.stop()
		parameter_display_active = false
		
		label.visible = false
		label.modulate.a = 1.0
		
		var backgrounds = ui_components.get_backgrounds()
		var main_background = backgrounds[2]
		if main_background:
			main_background.visible = false

func reset_fade_timer():
	if fade_timer and parameter_display_active:
		fade_timer.stop()
		fade_timer.start()

func start_parameter_fade():
	if not parameter_display_active or menu_manager.is_menu_visible():
		return
	
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	
	if not menu_manager.is_menu_visible():
		label.visible = false
		label.modulate.a = 1.0
	
	parameter_display_active = false

func auto_fade_startup_menu():
	await get_tree().create_timer(ConfigManager.get_startup_menu_duration()).timeout
	if menu_manager.is_first_launch() and menu_manager.is_menu_visible():
		hide_settings_menu()

func show_parameter_text_immediately(text: String):
	if menu_manager.is_menu_visible():
		parameter_display_active = false
		return
	
	label.visible = true
	label.modulate = Color.WHITE
	label.text = text
	
	var backgrounds = ui_components.get_backgrounds()
	var main_background = backgrounds[2]
	if main_background:
		main_background.visible = false
	
	fade_timer.start()

func toggle_settings_menu():
	menu_manager.set_first_launch(false)
	if menu_manager.is_menu_visible():
		hide_settings_menu()
	else:
		show_settings_menu()

func show_settings_menu():
	var settings_text = get_all_settings_text()
	menu_manager.show_settings_menu(settings_text)
	EventBus.emit_menu_visibility_changed(true)

func hide_settings_menu():
	if not menu_manager.is_menu_visible():
		return
	
	var fade_elements = menu_manager.start_fade_out()
	
	if fade_elements.size() == 0:
		menu_manager.hide_settings_menu_instant()
		EventBus.emit_menu_visibility_changed(false)
		return
	
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	
	for element in fade_elements.values():
		tween.tween_property(element, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	menu_manager.complete_fade_out()
	EventBus.emit_menu_visibility_changed(false)

func get_all_settings_text() -> String:
	var audio_info = ""
	if audio_manager:
		var status_info = audio_manager.get_status_info()
		audio_info = "Audio File: KOCH5.wav\nPlayback: %s\nReactive: %s\nPosition: %.1fs / %.1fs\nLevels - Bass: %.2f Mid: %.2f Treble: %.2f" % [
			"ON" if status_info.enabled else "OFF",
			"ON" if status_info.reactive else "OFF",
			status_info.position,
			status_info.duration,
			status_info.levels.bass, 
			status_info.levels.mid, 
			status_info.levels.treble
		]
	
	var base_text = parameter_manager.get_formatted_settings_text(audio_info) if parameter_manager else ""
	var palette_text = "Color Palette: %s\n" % color_palette_manager.get_current_palette_name() if color_palette_manager else ""
	
	return base_text + palette_text

func _input(event):
	# Handle reset confirmation first
	if input_handler.is_awaiting_reset_confirmation():
		if input_handler.handle_input(event):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
				pass
			else:
				EventBus.emit_text_update_requested("Reset cancelled")
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
		if input_handler.is_awaiting_reset_confirmation():
			EventBus.emit_text_update_requested(input_handler.get_reset_confirmation_message())

func _on_window_resized():
	var viewport_size = get_viewport().get_visible_rect().size
	print("Window resized to: ", viewport_size)
	print("Canvas size: ", canvas.size)
