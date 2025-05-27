# New simplified approach - separate invert control from palettes
extends RefCounted
class_name ColorPaletteManager

# Signals
signal palette_changed(palette_data: Dictionary, use_palette: bool)
signal invert_changed(should_invert: bool)  # NEW: Separate invert signal

# Color palette definitions - BACK TO ORIGINAL, NO INVERT FLAGS
var color_palettes = [
	# B&W (default/off)
	{"name": "B&W", "a": Vector3(0.5, 0.5, 0.5), "b": Vector3(0.5, 0.5, 0.5), "c": Vector3(1.0, 1.0, 1.0), "d": Vector3(0.0, 0.0, 0.0)},
	# Rainbow
	{"name": "Rainbow", "a": Vector3(0.5, 0.5, 0.5), "b": Vector3(0.5, 0.5, 0.5), "c": Vector3(1.0, 1.0, 1.0), "d": Vector3(0.0, 0.33, 0.67)},
	# Fire
	{"name": "Fire", "a": Vector3(0.5, 0.2, 0.1), "b": Vector3(0.5, 0.3, 0.2), "c": Vector3(2.0, 1.0, 0.5), "d": Vector3(0.0, 0.25, 0.5)},
	# Ocean
	{"name": "Ocean", "a": Vector3(0.2, 0.5, 0.8), "b": Vector3(0.2, 0.3, 0.5), "c": Vector3(1.0, 1.5, 2.0), "d": Vector3(0.0, 0.2, 0.5)},
	# Purple Dreams
	{"name": "Purple Dreams", "a": Vector3(0.8, 0.5, 0.4), "b": Vector3(0.2, 0.4, 0.2), "c": Vector3(2.0, 1.0, 1.0), "d": Vector3(0.0, 0.25, 0.25)},
	# Neon
	{"name": "Neon", "a": Vector3(0.2, 0.2, 0.2), "b": Vector3(0.8, 0.8, 0.8), "c": Vector3(1.0, 2.0, 1.5), "d": Vector3(0.0, 0.5, 0.8)},
	# Sunset
	{"name": "Sunset", "a": Vector3(0.7, 0.3, 0.2), "b": Vector3(0.3, 0.2, 0.1), "c": Vector3(1.5, 1.0, 0.8), "d": Vector3(0.0, 0.1, 0.3)}
]

# Custom random color for C key
var custom_random_palette = {"name": "Random", "a": Vector3.ZERO, "b": Vector3.ZERO, "c": Vector3.ZERO, "d": Vector3.ZERO}

var current_palette_index = 0
var using_random_color = false
var is_inverted = false  # NEW: Simple boolean for inversion

func cycle_palette_forward():
	using_random_color = false
	current_palette_index = (current_palette_index + 1) % color_palettes.size()
	emit_current_palette()

func cycle_palette_backward():
	using_random_color = false
	current_palette_index = (current_palette_index - 1) % color_palettes.size()
	if current_palette_index < 0:
		current_palette_index = color_palettes.size() - 1
	emit_current_palette()

func toggle_invert():
	"""Toggle inversion on/off for any palette"""
	is_inverted = !is_inverted
	invert_changed.emit(is_inverted)
	print("ColorPaletteManager: Invert toggled to: ", is_inverted)

func randomize_colors():
	# Generate completely random color palette values
	custom_random_palette["a"] = Vector3(randf(), randf(), randf())
	custom_random_palette["b"] = Vector3(randf(), randf(), randf())
	custom_random_palette["c"] = Vector3(randf() * 2.0, randf() * 2.0, randf() * 2.0)
	custom_random_palette["d"] = Vector3(randf(), randf(), randf())
	
	using_random_color = true
	emit_current_palette()

func reset_to_bw():
	using_random_color = false
	current_palette_index = 0  # B&W is index 0
	is_inverted = false  # Also reset inversion
	emit_current_palette()
	invert_changed.emit(is_inverted)

func get_current_palette_name() -> String:
	var base_name = ""
	if using_random_color:
		base_name = "Random"
	else:
		base_name = color_palettes[current_palette_index]["name"]
	
	if is_inverted:
		return base_name + " (Inverted)"
	else:
		return base_name

func get_current_palette_display() -> String:
	var palette_name = get_current_palette_name()
	return "Color Palette: %s\n[↑/↓] cycle palettes  [I] toggle invert\n[←/→] change parameter [r] reset [R] reset all" % palette_name

func emit_current_palette():
	var palette
	if using_random_color:
		palette = custom_random_palette
	else:
		palette = color_palettes[current_palette_index]
	
	# B&W palette (index 0) and not using random means no color palette
	var use_palette = current_palette_index > 0 or using_random_color
	
	palette_changed.emit(palette, use_palette)
	invert_changed.emit(is_inverted)  # Always emit current invert state

func save_palette_data() -> Dictionary:
	return {
		"current_palette_index": current_palette_index,
		"using_random_color": using_random_color,
		"custom_random_palette": custom_random_palette,
		"is_inverted": is_inverted  # Save invert state
	}

func load_palette_data(data: Dictionary):
	if "current_palette_index" in data:
		current_palette_index = data["current_palette_index"]
	if "using_random_color" in data:
		using_random_color = data["using_random_color"]
	if "custom_random_palette" in data:
		custom_random_palette = data["custom_random_palette"]
	if "is_inverted" in data:
		is_inverted = data["is_inverted"]
	
	emit_current_palette()
