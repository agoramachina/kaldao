shader_type canvas_item;

// Koch Snowflake Fractal Shader
// Uses same parameter names as Kaldao but with Koch-specific interpretations

// ====================
// SHADER UNIFORMS (Same names as Kaldao for compatibility)
// ====================

uniform float camera_position = 0.0;       // Managed camera position
uniform float rotation_time = 0.0;         // Accumulated rotation time
uniform float plane_rotation_time = 0.0;   // Accumulated plane rotation time
uniform float color_time = 0.0;            // Accumulated color time
uniform float fly_speed = 0.25;            // Speed of camera movement
uniform float contrast = 1.0;              // Visual contrast

// Koch-specific parameter interpretations:
uniform float kaleidoscope_segments = 6.0;     // Symmetry segments (6=snowflake, 3=triangle)
uniform float truchet_radius = 0.4;            // Base scale of snowflake
uniform float rotation_speed = 0.025;          // Speed of rotation
uniform float plane_rotation_speed = 0.5;      // Speed of layer rotation
uniform float zoom_level = 1.0;                // Iteration depth (higher=more detail)
uniform float color_intensity = 1.0;           // Color brightness

// Camera path controls
uniform float camera_tilt_x = 0.0;
uniform float camera_tilt_y = 0.0;
uniform float camera_roll = 0.0;
uniform float path_stability = 1.0;
uniform float path_scale = 1.0;

// Color palette controls
uniform bool use_color_palette = false;
uniform float color_speed = 0.5;
uniform vec3 palette_a = vec3(0.5, 0.5, 0.5);
uniform vec3 palette_b = vec3(0.5, 0.5, 0.5);
uniform vec3 palette_c = vec3(1.0, 1.0, 1.0);
uniform vec3 palette_d = vec3(0.0, 0.33, 0.67);

// ====================
// UTILITY FUNCTIONS
// ====================

mat2 ROT(float a) {
    return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 palette(float t) {
    return palette_a + palette_b * cos(6.28318 * (palette_c * t + palette_d));
}

// ====================
// KOCH SNOWFLAKE FUNCTIONS
// ====================

// Distance to a line segment
float line_segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Simple Koch approximation using mathematical formulation
float koch_edge_approximation(vec2 p, vec2 a, vec2 b, float detail_level) {
    vec2 edge = b - a;
    float edge_length = length(edge);
    vec2 edge_dir = edge / edge_length;
    vec2 edge_normal = vec2(-edge_dir.y, edge_dir.x);
    
    // Project point onto edge line
    vec2 ap = p - a;
    float t = dot(ap, edge_dir) / edge_length;
    vec2 closest_on_line = a + edge_dir * (t * edge_length);
    
    float base_dist = length(p - closest_on_line);
    
    // Add Koch-like bumps based on position along edge
    float freq = detail_level * 6.28318;
    float bump_height = edge_length * 0.1 * detail_level;
    
    // Create multiple frequency components for fractal-like appearance
    float koch_factor = 0.0;
    for (int i = 1; i <= 4; i++) {
        float scale = pow(1.0/3.0, float(i-1));
        float frequency = freq * pow(3.0, float(i-1));
        koch_factor += sin(t * frequency) * scale;
    }
    
    // Distance to Koch-like curve
    float koch_offset = koch_factor * bump_height;
    vec2 koch_point = closest_on_line + edge_normal * koch_offset;
    float koch_dist = length(p - koch_point);
    
    // Return minimum distance to either base line or Koch approximation
    return min(base_dist, koch_dist);
}

// Generate Koch snowflake
float koch_snowflake(vec2 p, float detail_level) {
    // Apply scale based on truchet_radius
    float scale = truchet_radius * 2.0;
    p /= scale;
    
    // Apply rotation
    p *= ROT(rotation_time);
    
    // Equilateral triangle vertices  
    float size = 0.6;
    vec2 v1 = vec2(0.0, size * 2.0/3.0);           // Top
    vec2 v2 = vec2(-size * sqrt(3.0)/2.0, -size/3.0);   // Bottom left
    vec2 v3 = vec2(size * sqrt(3.0)/2.0, -size/3.0);    // Bottom right
    
    // Use the passed detail level parameter
    float koch_detail = detail_level;
    
    // Generate Koch edges for triangle
    float d1 = koch_edge_approximation(p, v1, v2, koch_detail);
    float d2 = koch_edge_approximation(p, v2, v3, koch_detail);
    float d3 = koch_edge_approximation(p, v3, v1, koch_detail);
    
    float dist = min(min(d1, d2), d3);
    return dist * scale;
}

// Apply kaleidoscope symmetry
vec2 kaleidoscope(vec2 p, float segments) {
    if (segments < 1.0) segments = 6.0;
    
    float angle = atan(p.y, p.x);
    float radius = length(p);
    
    // Mirror kaleidoscope effect
    float seg_angle = 6.28318 / segments;
    angle = mod(angle + seg_angle/2.0, seg_angle) - seg_angle/2.0;
    angle = abs(angle);
    
    return vec2(cos(angle), sin(angle)) * radius;
}

// Multiple snowflake layers with variation
float multi_layer_snowflakes(vec2 p) {
    float min_dist = 1e10;
    
    // Apply camera movement
    p += vec2(camera_position * 0.05, sin(camera_position * 0.3) * 0.02);
    
    // Apply camera tilts
    p += vec2(camera_tilt_x, camera_tilt_y) * 0.01;
    
    // Base zoom
    p /= max(zoom_level, 0.1);
    
    // Generate multiple layers
    int max_layers = 3;
    for (int layer = 0; layer < max_layers; layer++) {
        float layer_scale = 1.0 + float(layer) * 0.4;
        float layer_rotation = float(layer) * 0.8 + plane_rotation_time * (0.5 + float(layer) * 0.3);
        
        vec2 layer_p = p;
        layer_p *= ROT(layer_rotation);
        layer_p /= layer_scale;
        
        // Add slight offset for each layer
        layer_p += vec2(
            sin(float(layer) * 2.1 + camera_position * 0.1),
            cos(float(layer) * 1.7 + camera_position * 0.1)
        ) * 0.1;
        
        // Use zoom level and layer for detail
        float layer_detail = clamp(zoom_level * 0.8 + float(layer) * 0.2, 0.1, 2.0);
        
        float layer_dist = koch_snowflake(layer_p, layer_detail);
        min_dist = min(min_dist, layer_dist);
    }
    
    return min_dist;
}

// ====================
// CAMERA PATH SYSTEM (Simplified)
// ====================

vec3 offset(float z) {
    float a = z;
    vec2 curved_path = -0.075 * path_scale * (
        vec2(cos(a), sin(a * sqrt(2.0))) +
        vec2(cos(a * sqrt(0.75)), sin(a * sqrt(0.5)))
    );
    
    vec2 straight_path = vec2(0.0, 0.0);
    vec2 p = mix(curved_path, straight_path, clamp(path_stability, 0.0, 1.0));
    p += vec2(camera_tilt_x, camera_tilt_y) * z * 0.1 * path_scale;
    
    return vec3(p, z);
}

// ====================
// MAIN EFFECT
// ====================

vec3 effect(vec2 p, vec2 q) {
    // Apply camera roll
    if (abs(camera_roll) > 0.001) {
        p *= ROT(camera_roll);
    }
    
    // Apply camera offset from path
    vec3 cam_offset = offset(camera_position);
    p += cam_offset.xy;
    
    // Apply kaleidoscope symmetry
    p = kaleidoscope(p, kaleidoscope_segments);
    
    // Calculate distance to Koch snowflakes
    float d = multi_layer_snowflakes(p);
    
    // Create snowflake visualization
    float line_width = 0.008 / max(zoom_level, 0.1);
    float edge_softness = line_width * 0.5;
    
    // Main snowflake pattern
    float snowflake = smoothstep(line_width + edge_softness, line_width - edge_softness, d);
    
    // Add glow effect
    float glow_intensity = 0.3;
    float glow = exp(-d * 15.0) * glow_intensity;
    
    // Combine effects
    float intensity = snowflake + glow;
    
    // Create base color
    vec3 col = vec3(intensity);
    
    // Add subtle variation based on position and time
    float variation = sin(d * 30.0 + color_time * 2.0) * 0.1 + 0.9;
    col *= variation;
    
    // Apply color palette if enabled
    if (use_color_palette) {
        float t = intensity * 0.8 + color_time + length(p) * 0.3;
        vec3 pal_color = palette(t);
        col = pal_color * intensity;
    }
    
    // Apply contrast
    col = pow(col, vec3(contrast));
    
    // Apply color intensity
    col *= color_intensity;
    
    return col;
}

vec3 postProcess(vec3 col, vec2 q) {
    // Tone mapping and gamma correction
    col = clamp(col, 0.0, 1.0);
    col = pow(col, vec3(1.0 / 2.2));
    
    // Subtle vignette effect
    float vignette = 0.3 + 0.7 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.3);
    col *= vignette;
    
    return col;
}

void fragment() {
    vec2 q = FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= (1.0 / SCREEN_PIXEL_SIZE).x / (1.0 / SCREEN_PIXEL_SIZE).y;
    
    vec3 col = effect(p, q);
    col = postProcess(col, q);
    
    COLOR = vec4(col, 1.0);
}