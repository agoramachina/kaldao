extends RefCounted
class_name UIComponents

# References
var control_node: Control
var settings_label: RichTextLabel
var commands_label: RichTextLabel
var main_label: RichTextLabel
var canvas: ColorRect

# Backgrounds
var settings_background: ColorRect
var commands_background: ColorRect
var main_background: ColorRect

func _init(control: Control, s_label: RichTextLabel, c_label: RichTextLabel, m_label: RichTextLabel, canvas_rect: ColorRect):
	control_node = control
	settings_label = s_label
	commands_label = c_label
	main_label = m_label
	canvas = canvas_rect

func setup_ui():
	# Ensure main Control node fills the entire window
	control_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Set up canvas sizing
	setup_canvas_sizing()
	
	# Set up labels
	setup_label_styling()
	
	# Position labels
	position_labels()
	
	# Create backgrounds
	create_backgrounds()
	
	# Connect window resize signal
	control_node.get_viewport().connect("size_changed", on_window_resized)


func setup_canvas_sizing():
	# Make canvas fill most of the window, but leave space for timeline
	canvas.anchor_left = 0.0
	canvas.anchor_top = 0.0
	canvas.anchor_right = 1.0
	canvas.anchor_bottom = 1.0
	canvas.offset_bottom = -120  # Leave 120 pixels at bottom for timeline
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup_label_styling():
	# Disable BBCode for cleaner display
	settings_label.bbcode_enabled = false
	commands_label.bbcode_enabled = false
	main_label.bbcode_enabled = false
	
	# Set up styling for all labels (NO SHADOWS)
	setup_single_label_styling(settings_label)
	setup_single_label_styling(commands_label)
	setup_single_label_styling(main_label)
	
	# Hide menu labels initially
	settings_label.visible = false
	commands_label.visible = false

func setup_single_label_styling(text_label: RichTextLabel):
	text_label.add_theme_color_override("default_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func position_labels():
	# Make sure we get the CURRENT viewport size, not cached
	var viewport_size = control_node.get_viewport().get_visible_rect().size
	print("DEBUG: Current viewport size for UI positioning: ", viewport_size)  # Add this debug line
	
	# FIXED SIZES for UI elements (no scaling)
	var column_width = 350  # Fixed width - won't scale with window
	var column_height = viewport_size.y
	
	# Position settings label (left column) - FIXED SIZE
	settings_label.position = Vector2(0, 0)
	settings_label.size = Vector2(column_width, column_height)
	
	# Position commands label (right column) - FIXED SIZE, positioned from right edge
	commands_label.position = Vector2(viewport_size.x - column_width, 0)
	commands_label.size = Vector2(column_width, viewport_size.y)
	
	# Position main label (TOP LEFT for parameter updates) - FIXED SIZE
	var main_width = 600   # Fixed width
	var main_height = viewport_size.y  
	main_label.position = Vector2(0, 10)
	main_label.size = Vector2(main_width, viewport_size.y)
	
	print("DEBUG: UI positioned with fixed sizes - Window: ", viewport_size, " UI: ", column_width, "x", column_height)
	
	var effective_height = viewport_size.y - 80  # Timeline height + margin

func create_backgrounds():
	# Create background for settings label
	settings_background = create_background_colorect("SettingsBackground")
	control_node.add_child(settings_background)
	control_node.move_child(settings_background, settings_label.get_index())
	
	# Create background for commands label
	commands_background = create_background_colorect("CommandsBackground")
	control_node.add_child(commands_background)
	control_node.move_child(commands_background, commands_label.get_index())
	
	# Create background for main label
	main_background = create_background_colorect("MainBackground")
	control_node.add_child(main_background)
	control_node.move_child(main_background, main_label.get_index())
	
	# Update background sizes and positions
	update_background_sizes()

func create_background_colorect(bg_name: String) -> ColorRect:
	var bg = ColorRect.new()
	bg.name = bg_name
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

func update_background_sizes():
	if settings_background:
		settings_background.position = settings_label.position
		settings_background.size = settings_label.size
		settings_background.visible = settings_label.visible
	
	if commands_background:
		commands_background.position = commands_label.position
		commands_background.size = commands_label.size
		commands_background.visible = commands_label.visible
	
	if main_background:
		update_main_background_to_content()

func update_main_background_to_content():
	if main_background and main_label:
		var content_height = main_label.get_content_height()
		var padding = 10
		
		main_background.position = Vector2(main_label.position.x - padding, main_label.position.y)
		main_background.size = Vector2(main_label.size.x + padding * 2, content_height)
		main_background.visible = main_label.visible

func on_window_resized():
	print("DEBUG: Window resize detected in UIComponents")
	# Force canvas to fill window on resize
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Reposition labels when window is resized
	position_labels()
	update_background_sizes()

func get_backgrounds() -> Array:
	return [settings_background, commands_background, main_background]

func show_parameter_text(text: String, tween_ref: Tween):
	# Don't show parameter updates if menu is visible
	if settings_label.visible:  # Menu is visible
		return
	
	# Kill any existing parameter text tween
	if tween_ref:
		tween_ref.kill()
	
	# Show the label (NO BACKGROUND for parameter updates)
	main_label.visible = true
	main_label.modulate = Color.WHITE
	main_label.text = text
	
	# Hide the background for parameter updates
	if main_background:
		main_background.visible = false
	
	# Wait for text processing
	await control_node.get_tree().process_frame
	
	# Wait 1.5 seconds, then fade out over 1 second
	await control_node.get_tree().create_timer(1.5).timeout
	
	# Check if label is still visible (might have been hidden by menu)
	if not main_label.visible:
		return
	
	# Create new tween from control node
	var fade_tween = control_node.create_tween()
	fade_tween.tween_property(main_label, "modulate:a", 0.0, 1.0)
	
	# Wait for fade to complete, then hide and reset
	await fade_tween.finished
	
	# Only hide if we're still showing parameter text (not menu)
	if not settings_label.visible:
		main_label.visible = false
		main_label.modulate.a = 1.0
