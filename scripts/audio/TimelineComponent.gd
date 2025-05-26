# TimelineComponent.gd - Song timeline scrubber and visualizer
extends Control
class_name TimelineComponent

# Signals
signal seek_requested(timestamp: float)
signal play_pause_requested()

# References
var audio_manager: AudioManager
var song_settings: SongSettings

# Timeline properties
var song_duration: float = 0.0
var current_time: float = 0.0
var is_dragging: bool = false
var timeline_height: int = 60
var margin: int = 20

# Visual elements
var timeline_rect: Rect2
var playhead_position: Vector2
var checkpoint_markers: Array = []

# Colors and styling
var bg_color = Color(0.1, 0.1, 0.1, 0.8)
var timeline_color = Color(0.3, 0.3, 0.3, 1.0)
var progress_color = Color(0.502, 0.0, 0.502, 1.0)
var playhead_color = Color(1.0, 1.0, 1.0, 1.0)
var checkpoint_color = Color(1.0, 0.8, 0.2, 1.0)
var time_marker_color = Color(0.1, 0.1, 0.1, 1.0)
var text_color = Color(0.9, 0.9, 0.9, 1.0)

# Fonts
var font: Font
var font_size: int = 12

func _ready():
	# Set up the control
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	size.y = timeline_height + margin * 2
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Load default font
	font = ThemeDB.fallback_font
	
	# Connect mouse events
	gui_input.connect(_on_gui_input)
	
	# Force visibility and size
	visible = true
	modulate = Color.WHITE
	z_index = 100  # Make sure it's on top
	
	print("DEBUG: Timeline _ready() called")
	print("DEBUG: Timeline size: ", size)
	print("DEBUG: Timeline position: ", position)
	print("DEBUG: Timeline visible: ", visible)

func connect_managers(audio_mgr: AudioManager, song_mgr: SongSettings):
	"""Connect to audio and song settings managers"""
	audio_manager = audio_mgr
	song_settings = song_mgr
	
	if audio_manager and audio_manager.stream:
		song_duration = audio_manager.stream.get_length()
		print("TimelineComponent: Connected to audio, duration: %.1fs" % song_duration)
	
	if song_settings:
		update_checkpoint_markers()
		print("TimelineComponent: Connected to song settings")

func _draw():
	"""Custom drawing for the timeline"""
	if song_duration <= 0:
		return
	
	var rect = get_rect()
	timeline_rect = Rect2(
		margin, 
		margin-25, 
		rect.size.x - margin * 2, 
		timeline_height
	)
	
	# Draw background
	draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), bg_color)
	
	# Draw main timeline bar
	draw_rect(timeline_rect, timeline_color)
	
	# Draw progress bar
	var progress_width = (current_time / song_duration) * timeline_rect.size.x
	var progress_rect = Rect2(
		timeline_rect.position.x,
		timeline_rect.position.y,
		progress_width,
		timeline_rect.size.y
	)
	draw_rect(progress_rect, progress_color)
	
	# Draw time markers
	draw_time_markers()
	
	# Draw checkpoint markers
	draw_checkpoint_markers()
	
	# Draw playhead
	draw_playhead()
	
	# Draw time text
	draw_time_text()

func draw_time_markers():
	"""Draw time markers every 10 seconds - SIMPLIFIED"""
	if song_duration <= 0:
		return
		
	var marker_interval = 10.0
	var timeline_width = timeline_rect.size.x
	
	for i in range(int(song_duration / marker_interval) + 1):
		var marker_time = i * marker_interval
		if marker_time > song_duration:
			break
		
		var x_pos = timeline_rect.position.x + (marker_time / song_duration) * timeline_width
		
		# Draw marker line - SAME PATTERN AS CHECKPOINTS
		draw_line(
			Vector2(x_pos, timeline_rect.position.y - 5),
			Vector2(x_pos, timeline_rect.position.y + timeline_rect.size.y),
			Color.WHITE,  # Simple white color
			2.0
		)

func draw_checkpoint_markers():
	"""Draw markers for imported checkpoints"""
	if not song_settings or song_settings.checkpoints.size() == 0:
		return
	
	var timeline_width = timeline_rect.size.x
	
	for checkpoint in song_settings.checkpoints:
		var timestamp = checkpoint.timestamp
		if timestamp > song_duration:
			continue
		
		var x_pos = timeline_rect.position.x + (timestamp / song_duration) * timeline_width
		var marker_y = timeline_rect.position.y - 15
		
		# Draw checkpoint diamond/triangle
		var points = PackedVector2Array([
			Vector2(x_pos, marker_y),
			Vector2(x_pos - 5, marker_y - 8),
			Vector2(x_pos + 5, marker_y - 8)
		])
		draw_colored_polygon(points, checkpoint_color)
		
		# Draw checkpoint name on hover (we'll implement hover detection later)
		# For now, just draw a small dot
		draw_circle(Vector2(x_pos, marker_y - 12), 2, checkpoint_color)

func draw_playhead():
	"""Draw the current playback position"""
	if song_duration <= 0:
		return
	
	var timeline_width = timeline_rect.size.x
	var x_pos = timeline_rect.position.x + (current_time / song_duration) * timeline_width
	
	playhead_position = Vector2(x_pos, timeline_rect.position.y)
	
	# Draw playhead line
	draw_line(
		Vector2(x_pos, timeline_rect.position.y - 10),
		Vector2(x_pos, timeline_rect.position.y + timeline_rect.size.y),
		playhead_color,
		3.0
	)
	
	# Draw playhead handle (circle at top)
	draw_circle(Vector2(x_pos, timeline_rect.position.y - 5), 6, playhead_color)
	draw_circle(Vector2(x_pos, timeline_rect.position.y - 5), 4, Color.BLACK)

func draw_time_text():
	"""Draw current time and duration - IMPROVED"""
	var current_text = format_time(current_time)
	var duration_text = format_time(song_duration)
	var time_display = "%s / %s" % [current_text, duration_text]
	
	# ADDED: Progress percentage
	var progress_percent = (current_time / song_duration) * 100.0 if song_duration > 0 else 0.0
	var progress_display = "%.1f%%" % progress_percent
	
	var text_size = font.get_string_size(time_display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = Vector2(
		timeline_rect.position.x + timeline_rect.size.x - text_size.x - 5,
		timeline_rect.position.y + timeline_rect.size.y - 55
	)
	
	# Draw time
	draw_string(
		font,
		text_pos,
		time_display,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		text_color
	)
	
	# ADDED: Draw progress percentage
	draw_string(
		font,
		Vector2(text_pos.x, text_pos.y + 15),
		progress_display,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		progress_color
	)
	
	# Draw play/pause indicator - IMPROVED
	var play_status = "▶️" if (audio_manager and audio_manager.playing) else "■"
	draw_string(
		font,
		Vector2(timeline_rect.position.x - 15, timeline_rect.position.y + 4),
		play_status,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		text_color
	)

func format_time(seconds: float) -> String:
	"""Format time as MM:SS"""
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func _on_gui_input(event: InputEvent):
	"""Handle mouse input for scrubbing and play/pause"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Check if click is within timeline area
				if timeline_rect.has_point(mouse_event.position):
					is_dragging = true
					seek_to_mouse_position(mouse_event.position)
				else:
					# Click outside timeline - toggle play/pause
					play_pause_requested.emit()
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_event = event as InputEventMouseMotion
		seek_to_mouse_position(mouse_event.position)

func seek_to_mouse_position(mouse_pos: Vector2):
	"""Calculate time from mouse position and request seek"""
	if song_duration <= 0:
		return
	
	var relative_x = mouse_pos.x - timeline_rect.position.x
	var timeline_width = timeline_rect.size.x
	
	# Clamp to timeline bounds
	relative_x = clamp(relative_x, 0, timeline_width)
	
	# Calculate timestamp
	var target_time = (relative_x / timeline_width) * song_duration
	target_time = clamp(target_time, 0, song_duration)
	
	# Request seek
	seek_requested.emit(target_time)

func update_time(new_time: float):
	"""Update current time and redraw"""
	current_time = clamp(new_time, 0, song_duration)
	queue_redraw()

func update_checkpoint_markers():
	"""Refresh checkpoint markers when checkpoints change"""
	queue_redraw()

func set_song_duration(duration: float):
	"""Set the song duration"""
	song_duration = duration
	queue_redraw()

# Helper function to get closest checkpoint for tooltip display
func get_checkpoint_at_position(mouse_pos: Vector2) -> Dictionary:
	"""Get checkpoint near mouse position for hover tooltips"""
	if not song_settings or song_settings.checkpoints.size() == 0:
		return {}
	
	var timeline_width = timeline_rect.size.x
	var hover_threshold = 10  # pixels
	
	for checkpoint in song_settings.checkpoints:
		var timestamp = checkpoint.timestamp
		if timestamp > song_duration:
			continue
		
		var x_pos = timeline_rect.position.x + (timestamp / song_duration) * timeline_width
		
		if abs(mouse_pos.x - x_pos) < hover_threshold:
			return checkpoint
	
	return {}

func _process(_delta):
	"""Update timeline every frame"""
	if audio_manager:
		var new_time = audio_manager.get_playback_position()
		if abs(new_time - current_time) > 0.1:  # Only redraw if significant change
			update_time(new_time)
