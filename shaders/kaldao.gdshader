shader_type canvas_item;

// CC0: Truchet + Kaleidoscope FTW
// Heavily commented version to understand the math

// ====================
// SHADER UNIFORMS - These control the visual appearance
// ====================

uniform float camera_position = 0.0;		// Where we are along the tunnel path (managed by GDScript)
uniform float rotation_time = 0.0;			// How much the patterns have rotated (accumulated time)
uniform float plane_rotation_time = 0.0;	// Per-plane rotation amount
uniform float color_time = 0.0;			// Color cycling time
uniform float fly_speed = 0.25;			// How fast we move forward (used by GDScript only)
uniform float contrast = 1.0;				// Sharpness of edges and details

// Pattern controls
uniform float kaleidoscope_segments = 10.0;	// How many mirror segments (creates the star pattern)
uniform int layer_count = 6;
uniform float truchet_radius = 0.35;			// Size of the circular patterns in each cell
uniform float center_fill_radius = 0.0;		// Size of the center fill (0.0 for no fill)
uniform float rotation_speed = 0.025;			// How fast patterns rotate
uniform float plane_rotation_speed = 0.5;		// Per-layer rotation speed
uniform float zoom_level = 0.3;				// How zoomed in we are (smaller = more zoomed in)
uniform float color_intensity = 1.0;			// Brightness multiplier

// Camera movement controls
uniform float camera_tilt_x = 0.0;		// Tilt camera left/right
uniform float camera_tilt_y = 0.0;		// Tilt camera up/down  
uniform float camera_roll = 0.0;		// Roll camera around forward axis
uniform float path_stability = 1.0;	// 1.0=curved path, 0.0=straight, negative=more curved
uniform float path_scale = 1.0;		// Overall scale of path curvature

// Color system
uniform bool use_color_palette = false;	// Enable colorful palettes vs black & white
uniform bool invert_colors = false;		// Invert final colors (negative effect)
uniform float color_speed = 0.5;			// How fast colors cycle
uniform vec3 palette_a = vec3(0.5, 0.5, 0.5);		// Color palette math coefficients
uniform vec3 palette_b = vec3(0.5, 0.5, 0.5);		// (these create different color schemes)
uniform vec3 palette_c = vec3(1.0, 1.0, 1.0);		
uniform vec3 palette_d = vec3(0.0, 0.33, 0.67);

// ====================
// UTILITY FUNCTIONS - Basic math helpers
// ====================

// Alpha blending: combines two colors with transparency
vec4 alphaBlend(vec4 back, vec4 front) {
	float w = front.w + back.w * (1.0 - front.w);
	vec3 xyz = (front.xyz * front.w + back.xyz * back.w * (1.0 - front.w)) / w;
	return w > 0.0 ? vec4(xyz, w) : vec4(0.0);
}

// Create a 2D rotation matrix - rotates points around origin
mat2 ROT(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

// "Positive cosine" - converts -1 to 1 range into 0 to 1 range
float PCOS(float x) {
	return 0.5 + 0.5 * cos(x);
}

// Blend a color with transparency onto an opaque background
vec3 alphaBlend34(vec3 back, vec4 front) {
	return mix(back, front.xyz, front.w);
}

// Hash function: converts a number into a pseudo-random number (0 to 1)
float hashf(float co) {
	return fract(sin(co * 12.9898) * 13758.5453);
}

// Hash function for 2D points: converts coordinates into pseudo-random number
float hashv(vec2 p) {
	float a = dot(p, vec2(127.1, 311.7));
	return fract(sin(a) * 43758.5453123);
}

// Fast approximation of hyperbolic tangent (smooth S-curve from -1 to 1)
float tanh_approx(float x) {
	float x2 = x * x;
	return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0);
}

// "Polynomial minimum" - smooth minimum function (creates rounded corners)
// Instead of sharp min(a,b), this creates a smooth transition between a and b
float pmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// "Polynomial maximum" - smooth maximum (opposite of pmin)
float pmax(float a, float b, float k) {
	return -pmin(-a, -b, k);
}

// "Polynomial absolute value" - smooth abs() function (rounded V-shape instead of sharp)
float pabs(float a, float k) {
	return pmax(a, -a, k);
}

// Convert from rectangular (x,y) to polar coordinates (radius, angle)
vec2 toPolar(vec2 p) {
	return vec2(length(p), atan(p.y, p.x));
}

// Convert from polar (radius, angle) back to rectangular (x,y)
vec2 toRect(vec2 p) {
	return vec2(p.x * cos(p.y), p.x * sin(p.y));
}

// Color palette function: creates smooth color gradients from 4 coefficient vectors
// This is based on Inigo Quilez's palette technique - very powerful for procedural colors
vec3 palette(float t) {
	return palette_a + palette_b * cos(6.28318 * (palette_c * t + palette_d));
}

// Post-processing: applies colors, gamma correction, vignette, and effects
vec3 postProcess(vec3 col, vec2 q, vec2 aspect) {
	// Apply color palette if enabled
	if (use_color_palette) {
		float t = length(col) + color_time;	// Use brightness + time as palette input
		col = palette(t) * length(col);		// Apply palette while preserving relative brightness
	}

	col = clamp(col, 0.0, 1.0);									// Ensure colors stay in valid range
	col = pow(col, vec3(1.0 / 2.2));							// Gamma correction (makes it look right on screen)
	col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);		// Contrast enhancement
	col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);			// Slight desaturation for more natural look
	
	// Vignette effect: darker at edges, brighter in center
	col *= 0.5 + 0.5 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);
	col *= color_intensity;	// Apply overall brightness control
	
	// Color inversion: flip all colors (like a photo negative)
	if (invert_colors) {
		col = vec3(1.0) - col;
	}
	return col;
}

// ====================
// KALEIDOSCOPE SYSTEM - Creates the radial mirror symmetry
// ====================

// Modular mirror: reflects coordinate back and forth in a repeating pattern
// This is what creates the "fold" effect in kaleidoscopes
float modMirror1(inout float p, float size) {
	float halfsize = size * 0.5;
	float c = floor((p + halfsize) / size);		// Which "cell" are we in?
	p = mod(p + halfsize, size) - halfsize;		// Wrap coordinate to cell
	p *= mod(c, 2.0) * 2.0 - 1.0;				// Flip every other cell (creates mirror effect)
	return c;
}

// Smooth kaleidoscope: creates the radial mirror segments you see in the image
// This takes any point and reflects it into one "slice" of the kaleidoscope
float smoothKaleidoscope(inout vec2 p, float sm, float rep) {
	vec2 hp = p;
	vec2 hpp = toPolar(hp);		// Convert to polar coordinates
	
	// Apply mirroring to the angle coordinate
	float rn = modMirror1(hpp.y, 2.0 * PI / rep);	// rep = number of mirror segments
	
	// Smooth the sharp edges between segments
	float sa = PI / rep - pabs(PI / rep - abs(hpp.y), sm);
	hpp.y = sign(hpp.y) * sa;
	
	hp = toRect(hpp);			// Convert back to rectangular coordinates
	p = hp;
	
	return rn;
}

// ====================
// CAMERA PATH SYSTEM - Creates the tunnel movement
// ====================

// Generate the camera path: creates the curved tunnel we're flying through
vec3 offset(float z) {
	float a = z;	// Use z-position as parameter for path
	
	// Create a complex curved path using sine and cosine waves
	// The sqrt(2.0), sqrt(0.75), etc. create non-repeating, organic curves
	vec2 curved_path = -0.075 * path_scale * (
		vec2(cos(a), sin(a * sqrt(2.0))) +				// Primary curve
		vec2(cos(a * sqrt(0.75)), sin(a * sqrt(0.5)))	// Secondary curve for complexity
	);
	
	vec2 straight_path = vec2(0.0, 0.0);	// No curve = straight tunnel
	
	// Interpolate between curved and straight based on path_stability
	vec2 p;
	if (path_stability >= 0.0) {
		p = mix(curved_path, straight_path, path_stability);	// 1.0=straight, 0.0=curved
	} else {
		p = curved_path * (1.0 + abs(path_stability) * 2.0);	// Negative = more curved
	}
	
	// Add camera tilt effects
	p += vec2(camera_tilt_x, camera_tilt_y) * z * 0.1 * path_scale;
	
	return vec3(p, z);	// Return 3D position
}

// Calculate the derivative (direction) of the path - which way we're heading
vec3 doffset(float z) {
	float eps = 0.1;
	return 0.5 * (offset(z + eps) - offset(z - eps)) / eps;	// Numerical derivative
}

// Calculate the second derivative (acceleration) of the path - how the direction changes
vec3 ddoffset(float z) {
	float eps = 0.1;
	return 0.125 * (doffset(z + eps) - doffset(z - eps)) / eps;	// Second derivative
}

// ====================
// TRUCHET PATTERN SYSTEM - Creates the curved patterns in each cell
// ====================

// Distance field for a single truchet cell - this defines the pattern shapes
// Returns: x = distance to nearest pattern edge, y = distance to cell center, z = center circle info
vec3 cell_df(float r, vec2 np, vec2 mp, vec2 off) {
	// These are the two diagonal directions that define truchet patterns
	vec2 n0 = normalize(vec2(1.0, 1.0));	// Northeast diagonal
	vec2 n1 = normalize(vec2(1.0, -1.0));	// Southeast diagonal
	
	np += off;	// Apply offset to cell coordinate
	mp -= off;	// Apply offset to local position
	
	float hh = hashv(np);	// Get random value for this cell
	float h0 = hh;
	
	// Calculate distance to cell center
	vec2 p0 = mp;
	p0 = abs(p0);			// Fold into first quadrant
	p0 -= 0.5;				// Center the cell
	float d0 = length(p0);	// Distance to center
	float d1 = abs(d0 - r);	// Distance to circle of radius r
	
	// Calculate distances to diagonal lines (these create the curved connections)
	float dot0 = dot(n0, mp);	// Distance to northeast diagonal
	float dot1 = dot(n1, mp);	// Distance to southeast diagonal
	
	// Create the truchet pattern shapes based on the diagonals
	float d2 = abs(dot0);
	float t2 = dot1;
	d2 = abs(t2) > sqrt(0.5) ? d0 : d2;	// Use center distance outside main area
	
	float d3 = abs(dot1);
	float t3 = dot0;
	d3 = abs(t3) > sqrt(0.5) ? d0 : d3;	// Use center distance outside main area
	
	// Combine patterns based on the random hash value
	float d = d0;			// Start with center distance
	d = min(d, d1);			// Always include the center circle
	
	// Add different pattern elements based on hash (creates variety)
	if (h0 > 0.85) {		// 15% chance: full truchet (circle + both diagonals)
		d = min(d, d2);
		d = min(d, d3);
	} else if (h0 > 0.5) {	// 35% chance: circle + one diagonal
		d = min(d, d2);
	} else if (h0 > 0.15) {	// 35% chance: circle + other diagonal
		d = min(d, d3);
	}
	// 15% chance: just the circle (h0 <= 0.15)
	
	// Check if we're inside the center circle
	float center_circle_factor = step(length(mp), r);	// 1.0 if inside center circle, 0.0 if outside
	return vec3(d, (d0 - r), center_circle_factor);		// Return pattern distance, circle distance, and center info
}

// Main truchet distance function: calculates pattern for any world position
vec3 truchet_df(float r, vec2 p) {
	vec2 np = floor(p + 0.5);		// Which cell are we in?
	vec2 mp = fract(p + 0.5) - 0.5;	// Position within that cell (-0.5 to 0.5)
	return cell_df(r, np, mp, vec2(0.0));
}

// ====================
// MAIN RENDERING FUNCTIONS - Puts it all together
// ====================

// Render a single plane/layer of the fractal
vec4 plane(vec3 ro, vec3 rd, vec3 pp, vec3 off, float aa, float n) {
	// Generate hash values for this plane (makes each layer different)
	float h_ = hashf(n);
	float h0 = fract(1777.0 * h_);	// Random rotation
	float h1 = fract(2087.0 * h_);	// Random offset
	float h2 = fract(2687.0 * h_);	// (unused)
	float h3 = fract(3167.0 * h_);	// (unused)
	float h4 = fract(3499.0 * h_);	// Random rotation speed
	
	float l = length(pp - ro);	// Distance from camera to this plane
	
	// Get 2D coordinates on this plane
	vec2 p = (pp - off * vec3(1.0, 1.0, 0.0)).xy;
	
	// Store the original plane coordinates for center detection
	vec2 original_p = p;
	
	// Apply per-plane rotation (each layer rotates at different speed)
	p *= ROT(plane_rotation_time * (h4 - 0.5));
	
	// Apply kaleidoscope effect
	float rep = kaleidoscope_segments;	// Number of mirror segments
	float sm = 0.05 * 20.0 / rep;		// Smoothing amount (less for more segments)
	float sn = smoothKaleidoscope(p, sm, rep);	// Apply the mirroring
	
	// Apply main rotation
	p *= ROT(2.0 * PI * h0 + rotation_time);
	
	// Apply zoom and offset
	float z = zoom_level;
	p /= z;								// Zoom in (smaller z = more zoomed)
	p += 0.5 + floor(h1 * 1000.0);		// Random offset for variety
	
	// Calculate truchet pattern
	float tl = tanh_approx(0.33 * l);		// Distance-based effect
	float r = truchet_radius;				// Size of circular elements
	vec3 d3 = truchet_df(r, p);				// Get distance to pattern + center circle info
	d3.xy *= z;								// Scale distance by zoom
	float d = d3.x;							// Distance to nearest pattern edge
	float lw = 0.025 * z;					// Line width
	d -= lw;								// Expand the pattern slightly
	
	// Convert distance to color (black and white pattern)
	vec3 col = mix(vec3(1.0), vec3(0.0), smoothstep(aa, -aa, d));	// White outside, black inside
	
	// Add fine detail lines
	col = mix(col, vec3(0.0), smoothstep(mix(1.0, -0.5, tl), 1.0, sin(PI * 100.0 * d)));
	
	// Center fill - using original plane coordinates (before all transformations)
	float center_distance = length(original_p);
	float center_edge = smoothstep(center_fill_radius + aa, center_fill_radius - aa, center_distance);
	float transparency = 0.99;	// Adjust this for transparency level (0.0 = invisible, 1.0 = opaque)
	col = mix(col, vec3(0.0), center_edge * step(0.01, center_fill_radius) * transparency);
   
	// Calculate transparency (alpha) for this layer (try switching around -aa and aa for neat effects!)
	float t = smoothstep(aa, -aa, -d3.y - 3.0 * lw) *		
			  mix(0.5, 1.0, smoothstep(aa, -aa, -d3.y - lw));

	// Cut out areas outside the main circle
	col = mix(col, vec3(0.01), step(d3.y, 0.0));		
	
	return vec4(col, t);	// Return color with transparency
}

// Sky color: what we see in the distance/background
vec3 skyColor(vec3 ro, vec3 rd) {
	// Simple gradient based on looking up or down
	float d = pow(max(dot(rd, vec3(0.0, 0.0, 1.0)), 0.0), 20.0);
	return vec3(d);	// Dark sky with bright spot in forward direction
}

// Main color calculation: renders multiple layers and combines them
vec3 color(vec3 ww, vec3 uu, vec3 vv, vec3 ro, vec2 p) {
	float lp = length(p);	// Distance from center of screen
	
	// Calculate slightly offset ray for anti-aliasing
	vec2 np = p + 1.0 / vec2(1920.0 * contrast, 1080.0 * contrast);
	
	// Field of view effect: wider angle at edges
	float rdd = (2.0 + 1.0 * tanh_approx(lp));
	
	// Calculate ray direction in 3D space
	vec3 rd = normalize(p.x * uu + p.y * vv + rdd * ww);	// Main ray
	vec3 nrd = normalize(np.x * uu + np.y * vv + rdd * ww);	// Offset ray for AA
	
	// Layer rendering parameters
	float planeDist = 1.0 - 0.25;		// Distance between layers
	int furthest = layer_count;			// How many layers to render
	int fadeFrom = max(furthest - 5, 0);	// When to start fading
	
	float nz = floor(ro.z / planeDist);	// Which layer are we starting from?
	
	vec3 skyCol = skyColor(ro, rd);		// Background color
	
	vec4 acol = vec4(0.0);				// Accumulated color
	float cutOff = 0.95;				// Stop rendering when mostly opaque
	
	// Render each layer from far to near
	for (int i = 1; i <= furthest; ++i) {
		float pz = planeDist * nz + planeDist * float(i);	// Z position of this layer
		float pd = (pz - ro.z) / rd.z;						// Distance along ray to layer
		
		if (pd > 0.0 && acol.w < cutOff) {	// Only render if in front and not fully opaque
			vec3 pp = ro + rd * pd;			// 3D position on layer
			vec3 npp = ro + nrd * pd;		// Offset position for anti-aliasing
			
			float aa = 3.0 * length(pp - npp);	// Anti-aliasing amount
			vec3 off = offset(pp.z);			// Camera path offset for this layer
			
			// Render this layer
			vec4 pcol = plane(ro, rd, pp, off, aa, nz + float(i));
			
			// Apply distance-based fading
			float nz1 = pp.z - ro.z;
			float fadeIn = smoothstep(planeDist * float(furthest), planeDist * float(fadeFrom), nz1);
			float fadeOut = smoothstep(0.0, planeDist * 0.1, nz1);
			
			pcol.xyz = mix(skyCol, pcol.xyz, fadeIn);	// Fade to sky color in distance
			pcol.w *= fadeOut;							// Fade out very close layers
			pcol = clamp(pcol, 0.0, 1.0);				// Keep in valid range
			
			// Blend this layer with accumulated color
			acol = alphaBlend(pcol, acol);
		}
	}
	
	// Combine with sky color
	vec3 col = alphaBlend34(skyCol, acol);
	return col;
}

// ====================
// MAIN EFFECT - Camera setup and final rendering
// ====================

vec3 effect(vec2 p, vec2 q) {
	// Calculate camera position and orientation along the path
	vec3 ro = offset(camera_position);		// Camera position
	vec3 dro = doffset(camera_position);	// Camera forward direction
	vec3 ddro = ddoffset(camera_position);	// Camera acceleration (for banking)
	
	// Create camera coordinate system
	vec3 ww = normalize(dro);				// Forward direction
	vec3 uu = normalize(cross(				// Right direction
		normalize(vec3(0.0, 1.0, 0.0) + ddro),	// Up + banking
		ww
	));
	vec3 vv = normalize(cross(ww, uu));		// True up direction
	
	// Apply camera roll if enabled
	if (abs(camera_roll) > 0.001) {
		mat2 roll_rot = ROT(camera_roll);
		vec2 rotated = roll_rot * vec2(
			dot(p, uu.xy),		// Project screen coordinate onto camera right
			dot(p, vv.xy)		// Project screen coordinate onto camera up
		);
		p = rotated.x * uu.xy + rotated.y * vv.xy;	// Apply rotation
	}
	
	// Render the scene
	vec3 col = color(ww, uu, vv, ro, p);
	
	return col;
}

// ====================
// FRAGMENT SHADER ENTRY POINT
// ====================

void fragment() {
	// Convert screen coordinates to normalized coordinates
	vec2 q = FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;	// 0 to 1
	vec2 p = -1.0 + 2.0 * q;								// -1 to 1
	p.x *= (1.0 / SCREEN_PIXEL_SIZE).x / (1.0 / SCREEN_PIXEL_SIZE).y;	// Correct aspect ratio
	
	// Store aspect ratio for postProcess
	vec2 aspect = vec2((1.0 / SCREEN_PIXEL_SIZE).x, (1.0 / SCREEN_PIXEL_SIZE).y);
	
	// Render the effect and apply post-processing
	vec3 col = effect(p, q);
	col = postProcess(col, q, aspect);
	
	// Output final color
	COLOR = vec4(col, 1.0);
}