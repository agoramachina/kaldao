# ShaderDebug.gd - Mirror all shader variables for debugging
extends ColorRect
class_name ShaderDebug

# ====================
# SHADER UNIFORMS MIRROR
# ====================

# Core uniforms
var camera_position: float = 0.0
var rotation_time: float = 0.0
var plane_rotation_time: float = 0.0
var color_time: float = 0.0
var fly_speed: float = 0.25
var contrast: float = 1.0

# Pattern controls
var kaleidoscope_segments: float = 10.0
var layer_count: int = 6
var truchet_radius: float = 0.35
var center_fill_radius: float = 0.0
var rotation_speed: float = 0.025
var plane_rotation_speed: float = 0.5
var zoom_level: float = 0.3
var color_intensity: float = 1.0

# Camera movement
var camera_tilt_x: float = 0.0
var camera_tilt_y: float = 0.0
var camera_roll: float = 0.0
var path_stability: float = 1.0
var path_scale: float = 1.0

# Color system
var use_color_palette: bool = false
var invert_colors: bool = false
var color_speed: float = 0.5
var palette_a: Vector3 = Vector3(0.5, 0.5, 0.5)
var palette_b: Vector3 = Vector3(0.5, 0.5, 0.5)
var palette_c: Vector3 = Vector3(1.0, 1.0, 1.0)
var palette_d: Vector3 = Vector3(0.0, 0.33, 0.67)

# ====================
# COMPUTED VALUES (for debugging intermediate calculations)
# ====================

# Camera path values
var current_offset: Vector3 = Vector3.ZERO
var current_doffset: Vector3 = Vector3.ZERO
var current_ddoffset: Vector3 = Vector3.ZERO
var camera_forward: Vector3 = Vector3.ZERO
var camera_right: Vector3 = Vector3.ZERO
var camera_up: Vector3 = Vector3.ZERO

# Plane calculation values
var original_p: Vector2 = Vector2.ZERO
var post_rotation_p: Vector2 = Vector2.ZERO
var post_kaleidoscope_p: Vector2 = Vector2.ZERO
var post_main_rotation_p: Vector2 = Vector2.ZERO
var final_truchet_p: Vector2 = Vector2.ZERO

# Truchet pattern values
var truchet_distance: float = 0.0
var truchet_circle_distance: float = 0.0
var truchet_center_factor: float = 0.0

# Center fill debug
var center_distance: float = 0.0
var center_edge: float = 0.0
var center_fill_applied: bool = false

# ====================
# UTILITY FUNCTION MIRRORS
# ====================

func ROT(a: float) -> Array:
	"""Mirror of shader ROT function - returns 2x2 matrix as array"""
	var cos_a = cos(a)
	var sin_a = sin(a)
	return [
		[cos_a, sin_a],
		[-sin_a, cos_a]
	]

func apply_rotation_2d(p: Vector2, rotation_matrix: Array) -> Vector2:
	"""Apply 2D rotation matrix to vector"""
	return Vector2(
		rotation_matrix[0][0] * p.x + rotation_matrix[0][1] * p.y,
		rotation_matrix[1][0] * p.x + rotation_matrix[1][1] * p.y
	)

func PCOS(x: float) -> float:
	"""Mirror of shader PCOS function"""
	return 0.5 + 0.5 * cos(x)

func hashf(co: float) -> float:
	"""Mirror of shader hashf function"""
	return fmod(sin(co * 12.9898) * 13758.5453, 1.0)

func hashv(p: Vector2) -> float:
	"""Mirror of shader hashv function"""
	var a = p.dot(Vector2(127.1, 311.7))
	return fmod(sin(a) * 43758.5453123, 1.0)

func tanh_approx(x: float) -> float:
	"""Mirror of shader tanh_approx function"""
	var x2 = x * x
	return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0)

func to_polar(p: Vector2) -> Vector2:
	"""Mirror of shader toPolar function"""
	return Vector2(p.length(), atan2(p.y, p.x))

func to_rect(p: Vector2) -> Vector2:
	"""Mirror of shader toRect function"""
	return Vector2(p.x * cos(p.y), p.x * sin(p.y))

func palette(t: float) -> Vector3:
	"""Mirror of shader palette function"""
	return palette_a + palette_b * Vector3(
		cos(6.28318 * (palette_c.x * t + palette_d.x)),
		cos(6.28318 * (palette_c.y * t + palette_d.y)),
		cos(6.28318 * (palette_c.z * t + palette_d.z))
	)

# ====================
# CAMERA PATH SYSTEM MIRROR
# ====================

func offset(z: float) -> Vector3:
	"""Mirror of shader offset function"""
	var a = z
	
	var curved_path = -0.075 * path_scale * (
		Vector2(cos(a), sin(a * sqrt(2.0))) +
		Vector2(cos(a * sqrt(0.75)), sin(a * sqrt(0.5)))
	)
	
	var straight_path = Vector2.ZERO
	
	var p: Vector2
	if path_stability >= 0.0:
		p = curved_path.lerp(straight_path, path_stability)
	else:
		p = curved_path * (1.0 + abs(path_stability) * 2.0)
	
	p += Vector2(camera_tilt_x, camera_tilt_y) * z * 0.1 * path_scale
	
	return Vector3(p.x, p.y, z)

func doffset(z: float) -> Vector3:
	"""Mirror of shader doffset function"""
	var eps = 0.1
	return 0.5 * (offset(z + eps) - offset(z - eps)) / eps

func ddoffset(z: float) -> Vector3:
	"""Mirror of shader ddoffset function"""
	var eps = 0.1
	return 0.125 * (doffset(z + eps) - doffset(z - eps)) / eps

# ====================
# KALEIDOSCOPE SYSTEM MIRROR
# ====================

func mod_mirror_1(p_value: float, size: float) -> Dictionary:
	"""Mirror of shader modMirror1 function - returns both result and modified p"""
	var halfsize = size * 0.5
	var c = floor((p_value + halfsize) / size)
	var new_p = fmod(p_value + halfsize, size) - halfsize
	new_p *= fmod(c, 2.0) * 2.0 - 1.0
	return {"p": new_p, "c": c}

func smooth_kaleidoscope(p: Vector2, sm: float, rep: float) -> Dictionary:
	"""Mirror of shader smoothKaleidoscope - returns modified p and debug info"""
	var hp = p
	var hpp = to_polar(hp)
	
	var mirror_result = mod_mirror_1(hpp.y, 2.0 * PI / rep)
	var rn = mirror_result.c
	hpp.y = mirror_result.p
	
	# Smooth the sharp edges between segments
	var sa = PI / rep - abs(PI / rep - abs(hpp.y))  # Simplified pabs for now
	hpp.y = sign(hpp.y) * sa
	
	hp = to_rect(hpp)
	
	return {
		"p": hp,
		"original_polar": to_polar(p),
		"mirrored_polar": hpp,
		"segment_number": rn
	}

# ====================
# TRUCHET PATTERN SYSTEM MIRROR
# ====================

func cell_df(r: float, np: Vector2, mp: Vector2, off: Vector2) -> Dictionary:
	"""Mirror of shader cell_df function with debug info"""
	var n0 = Vector2(1.0, 1.0).normalized()
	var n1 = Vector2(1.0, -1.0).normalized()
	
	np += off
	mp -= off
	
	var hh = hashv(np)
	var h0 = hh
	
	# Calculate distance to cell center
	var p0 = mp
	p0 = Vector2(abs(p0.x), abs(p0.y))
	p0 -= Vector2(0.5, 0.5)
	var d0 = p0.length()
	var d1 = abs(d0 - r)
	
	# Calculate distances to diagonal lines
	var dot0 = n0.dot(mp)
	var dot1 = n1.dot(mp)
	
	# Create the truchet pattern shapes
	var d2 = abs(dot0)
	var t2 = dot1
	d2 = d0 if abs(t2) > sqrt(0.5) else d2
	
	var d3 = abs(dot1)
	var t3 = dot0
	d3 = d0 if abs(t3) > sqrt(0.5) else d3
	
	# Combine patterns based on hash
	var d = d0
	d = min(d, d1)
	
	var pattern_type = "circle_only"
	if h0 > 0.85:
		d = min(d, d2)
		d = min(d, d3)
		pattern_type = "full_truchet"
	elif h0 > 0.5:
		d = min(d, d2)
		pattern_type = "circle_plus_diagonal1"
	elif h0 > 0.15:
		d = min(d, d3)
		pattern_type = "circle_plus_diagonal2"
	
	var center_circle_factor = 1.0 if mp.length() < r else 0.0
	
	return {
		"distance": d,
		"circle_distance": d0 - r,
		"center_factor": center_circle_factor,
		"hash": h0,
		"pattern_type": pattern_type,
		"cell_position": np,
		"local_position": mp
	}

func truchet_df(r: float, p: Vector2) -> Dictionary:
	"""Mirror of shader truchet_df function"""
	var np = Vector2(floor(p.x + 0.5), floor(p.y + 0.5))
	var mp = Vector2(fmod(p.x + 0.5, 1.0), fmod(p.y + 0.5, 1.0)) - Vector2(0.5, 0.5)
	return cell_df(r, np, mp, Vector2.ZERO)

# ====================
# MAIN SIMULATION FUNCTIONS
# ====================

func simulate_plane_calculation(plane_position: Vector3, camera_ro: Vector3, plane_number: float):
	"""Simulate the plane() function calculation for debugging"""
	print("\n=== SIMULATING PLANE CALCULATION ===")
	print("Plane Position: ", plane_position)
	print("Camera Position: ", camera_ro)
	print("Plane Number: ", plane_number)
	
	# Generate hash values for this plane
	var h_ = hashf(plane_number)
	var h0 = fmod(1777.0 * h_, 1.0)
	var h1 = fmod(2087.0 * h_, 1.0)
	var h4 = fmod(3499.0 * h_, 1.0)
	
	print("Hash Values: h_=%.3f, h0=%.3f, h1=%.3f, h4=%.3f" % [h_, h0, h1, h4])
	
	var l = (plane_position - camera_ro).length()
	print("Distance to Camera: ", l)
	
	# Get 2D coordinates on this plane
	var plane_offset = offset(plane_position.z)
	var p = Vector2(plane_position.x - plane_offset.x, plane_position.y - plane_offset.y)
	original_p = p
	print("Original Plane Coordinates: ", original_p)
	
	# Apply per-plane rotation
	var plane_rot_matrix = ROT(plane_rotation_time * (h4 - 0.5))
	p = apply_rotation_2d(p, plane_rot_matrix)
	post_rotation_p = p
	print("After Per-Plane Rotation: ", post_rotation_p)
	
	# Apply kaleidoscope effect
	var rep = kaleidoscope_segments
	var sm = 0.05 * 20.0 / rep
	var kaleidoscope_result = smooth_kaleidoscope(p, sm, rep)
	p = kaleidoscope_result.p
	post_kaleidoscope_p = p
	print("After Kaleidoscope: ", post_kaleidoscope_p)
	print("Kaleidoscope Debug: ", kaleidoscope_result)
	
	# Apply main rotation
	var main_rot_matrix = ROT(2.0 * PI * h0 + rotation_time)
	p = apply_rotation_2d(p, main_rot_matrix)
	post_main_rotation_p = p
	print("After Main Rotation: ", post_main_rotation_p)
	
	# Apply zoom and offset
	var z = zoom_level
	p /= z
	p += Vector2(0.5, 0.5) + Vector2(floor(h1 * 1000.0), floor(h1 * 1000.0))
	final_truchet_p = p
	print("Final Truchet Coordinates: ", final_truchet_p)
	
	# Calculate truchet pattern
	var truchet_result = truchet_df(truchet_radius, p)
	truchet_distance = truchet_result.distance * z
	truchet_circle_distance = truchet_result.circle_distance
	truchet_center_factor = truchet_result.center_factor
	
	print("Truchet Results: ", truchet_result)
	print("Scaled Distance: ", truchet_distance)
	
	# Calculate center fill
	center_distance = original_p.length()
	center_edge = smoothstep(center_fill_radius + 0.01, center_fill_radius - 0.01, center_distance)
	center_fill_applied = center_fill_radius > 0.01 and center_edge > 0.0
	
	print("Center Fill Debug:")
	print("  Distance from Origin: ", center_distance)
	print("  Fill Radius: ", center_fill_radius)
	print("  Edge Factor: ", center_edge)
	print("  Fill Applied: ", center_fill_applied)

func update_camera_values():
	"""Update computed camera values"""
	current_offset = offset(camera_position)
	current_doffset = doffset(camera_position)
	current_ddoffset = ddoffset(camera_position)
	
	camera_forward = current_doffset.normalized()
	var up_with_banking = (Vector3(0, 1, 0) + current_ddoffset).normalized()
	camera_right = camera_forward.cross(up_with_banking).normalized()
	camera_up = camera_right.cross(camera_forward).normalized()

# ====================
# MAIN DEBUG FUNCTIONS
# ====================

func sync_from_parameter_manager(param_manager: ParameterManager):
	"""Sync all values from ParameterManager"""
	if not param_manager:
		return
	
	var params = param_manager.get_all_parameters()
	
	# Sync all matching parameter names
	for param_name in params:
		var param_data = params[param_name]
		var value = param_data["current"]
		
		match param_name:
			"fly_speed": fly_speed = value
			"contrast": contrast = value
			"kaleidoscope_segments": kaleidoscope_segments = value
			"truchet_radius": truchet_radius = value
			"rotation_speed": rotation_speed = value
			"zoom_level": zoom_level = value
			"color_intensity": color_intensity = value
			"plane_rotation_speed": plane_rotation_speed = value
			"camera_tilt_x": camera_tilt_x = value
			"camera_tilt_y": camera_tilt_y = value
			"camera_roll": camera_roll = value
			"path_stability": path_stability = value
			"path_skew": path_scale = value  # Note: path_skew maps to path_scale
			"color_speed": color_speed = value
			"center_fill_radius": center_fill_radius = value
			"invert_colors": invert_colors = bool(value)

func sync_time_values(audio_manager):
	"""Sync time-based values from AudioManager or CanvasManager"""
	if audio_manager:
		# These would need to be exposed from your canvas manager
		# camera_position += fly_speed * delta
		# rotation_time += rotation_speed * delta
		# etc.
		pass

func print_all_uniforms():
	"""Print all uniform values in organized format"""
	print("\n" + "===================================================")
	print("SHADER DEBUG - ALL UNIFORM VALUES")
	print("===================================================")
	
	print("\n--- CORE UNIFORMS ---")
	print("camera_position: %.3f" % camera_position)
	print("rotation_time: %.3f" % rotation_time)
	print("plane_rotation_time: %.3f" % plane_rotation_time)
	print("color_time: %.3f" % color_time)
	print("fly_speed: %.3f" % fly_speed)
	print("contrast: %.3f" % contrast)
	
	print("\n--- PATTERN CONTROLS ---")
	print("kaleidoscope_segments: %.1f" % kaleidoscope_segments)
	print("layer_count: %d" % layer_count)
	print("truchet_radius: %.3f" % truchet_radius)
	print("center_fill_radius: %.3f" % center_fill_radius)
	print("rotation_speed: %.3f" % rotation_speed)
	print("plane_rotation_speed: %.3f" % plane_rotation_speed)
	print("zoom_level: %.3f" % zoom_level)
	print("color_intensity: %.3f" % color_intensity)
	
	print("\n--- CAMERA MOVEMENT ---")
	print("camera_tilt_x: %.3f" % camera_tilt_x)
	print("camera_tilt_y: %.3f" % camera_tilt_y)
	print("camera_roll: %.3f" % camera_roll)
	print("path_stability: %.3f" % path_stability)
	print("path_scale: %.3f" % path_scale)
	
	print("\n--- COLOR SYSTEM ---")
	print("use_color_palette: %s" % str(use_color_palette))
	print("invert_colors: %s" % str(invert_colors))
	print("color_speed: %.3f" % color_speed)
	print("palette_a: %s" % str(palette_a))
	print("palette_b: %s" % str(palette_b))
	print("palette_c: %s" % str(palette_c))
	print("palette_d: %s" % str(palette_d))

func print_computed_values():
	"""Print all computed/intermediate values"""
	print("\n--- COMPUTED CAMERA VALUES ---")
	print("current_offset: %s" % str(current_offset))
	print("current_doffset: %s" % str(current_doffset))
	print("current_ddoffset: %s" % str(current_ddoffset))
	print("camera_forward: %s" % str(camera_forward))
	print("camera_right: %s" % str(camera_right))
	print("camera_up: %s" % str(camera_up))
	
	print("\n--- PLANE CALCULATION CHAIN ---")
	print("original_p: %s" % str(original_p))
	print("post_rotation_p: %s" % str(post_rotation_p))
	print("post_kaleidoscope_p: %s" % str(post_kaleidoscope_p))
	print("post_main_rotation_p: %s" % str(post_main_rotation_p))
	print("final_truchet_p: %s" % str(final_truchet_p))
	
	print("\n--- TRUCHET & CENTER FILL ---")
	print("truchet_distance: %.3f" % truchet_distance)
	print("truchet_circle_distance: %.3f" % truchet_circle_distance)
	print("truchet_center_factor: %.3f" % truchet_center_factor)
	print("center_distance: %.3f" % center_distance)
	print("center_edge: %.3f" % center_edge)
	print("center_fill_applied: %s" % str(center_fill_applied))

func print_full_debug():
	"""Print everything in one organized dump"""
	print_all_uniforms()
	print_computed_values()
	print("\n" + "===================================================")

# Helper function for smoothstep
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
