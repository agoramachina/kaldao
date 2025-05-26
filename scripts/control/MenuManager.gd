extends RefCounted
class_name MenuManager

# References to UI elements
var settings_label: RichTextLabel
var commands_label: RichTextLabel
var main_label: RichTextLabel
var settings_background: ColorRect
var commands_background: ColorRect
var main_background: ColorRect

var menu_visible = false
var first_launch = true

func _init(s_label: RichTextLabel, c_label: RichTextLabel, m_label: RichTextLabel):
	settings_label = s_label
	commands_label = c_label
	main_label = m_label

func set_backgrounds(s_bg: ColorRect, c_bg: ColorRect, m_bg: ColorRect):
	settings_background = s_bg
	commands_background = c_bg
	main_background = m_bg

func show_settings_menu(settings_text: String):
	menu_visible = true
	
	# Create commands text with TABS for better alignment
	var commands_text = """=== COMMANDS ===

NAVIGATION:
↑/↓\tAdjust parameter
←/→\tSwitch parameter
r\tReset current
R\tReset all (confirm)

RANDOMIZATION:
C\tRandomize colors
.\tRandomize parameters
Shift+C\tReset to B&W

AUDIO:
A\tToggle audio reactive
I\tCycle audio device

CAPTURE:
Space\tPause animation
P\tTake screenshot

FILES:
Ctrl+S\tSave settings
Ctrl+L\tLoad settings

MENU:
F1\tToggle this menu
ESC\tHide this menu"""
	
	# Update text content
	settings_label.text = settings_text
	commands_label.text = commands_text
	
	# Show the menu labels and their backgrounds
	settings_label.visible = true
	commands_label.visible = true
	if settings_background:
		settings_background.visible = true
	if commands_background:
		commands_background.visible = true
	
	# Hide main label when menu is up
	main_label.visible = false
	if main_background:
		main_background.visible = false

func hide_settings_menu_instant():
	menu_visible = false
	first_launch = false
	
	# Instantly hide the labels and backgrounds
	if settings_label:
		settings_label.visible = false
		settings_label.modulate.a = 1.0
	if commands_label:
		commands_label.visible = false
		commands_label.modulate.a = 1.0
	if settings_background:
		settings_background.visible = false
		settings_background.modulate.a = 1.0
	if commands_background:
		commands_background.visible = false
		commands_background.modulate.a = 1.0
	
	# Show main label
	main_label.visible = true
	if main_background:
		main_background.visible = true

func start_fade_out() -> Dictionary:
	# Return the elements that need to be faded out
	var fade_elements = {}
	
	if settings_label and settings_label.visible:
		fade_elements["settings_label"] = settings_label
	if settings_background and settings_background.visible:
		fade_elements["settings_background"] = settings_background
	if commands_label and commands_label.visible:
		fade_elements["commands_label"] = commands_label
	if commands_background and commands_background.visible:
		fade_elements["commands_background"] = commands_background
	
	return fade_elements

func complete_fade_out():
	# Called after fade animation completes
	hide_settings_menu_instant()

func toggle_settings_menu(settings_text: String) -> bool:
	first_launch = false  # No longer first launch after manual toggle
	if menu_visible:
		hide_settings_menu_instant()
		return false
	else:
		show_settings_menu(settings_text)
		return true

func is_menu_visible() -> bool:
	return menu_visible

func is_first_launch() -> bool:
	return first_launch

func set_first_launch(value: bool):
	first_launch = value
