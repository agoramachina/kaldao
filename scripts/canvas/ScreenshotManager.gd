extends RefCounted
class_name ScreenshotManager

# Signals
signal screenshot_taken(file_path: String)
signal screenshot_failed(error_message: String)

func capture_screenshot(viewport: Viewport):
	_take_screenshot(viewport)

func _take_screenshot(viewport: Viewport):
	# Wait one frame to ensure everything is rendered
	await viewport.get_tree().process_frame
	
	# Get the viewport texture
	var img = viewport.get_texture().get_image()
	
	# Generate filename with timestamp
	var time_dict = Time.get_datetime_dict_from_system()
	var filename = "fractal_screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
		time_dict.year, time_dict.month, time_dict.day,
		time_dict.hour, time_dict.minute, time_dict.second
	]
	
	# Save to project screenshots directory
	var file_path = "res://data/screenshots/" + filename
	var error = img.save_png(file_path)
	
	if error == OK:
		print("Screenshot saved: ", file_path)
		# Convert to absolute path for user info
		var absolute_path = ProjectSettings.globalize_path(file_path)
		screenshot_taken.emit(absolute_path)
	else:
		print("Failed to save screenshot, error: ", error)
		screenshot_failed.emit("Failed to save screenshot")
