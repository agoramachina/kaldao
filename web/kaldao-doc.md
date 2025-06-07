# Kaldao Fractal Visualizer Documentation

**Version:** 0.3.2  
**Author:** @agoramachina  
**License:** MIT License  
**Year:** 2025

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Global Variables](#global-variables)
4. [Parameters System](#parameters-system)
5. [Rendering Pipeline](#rendering-pipeline)
6. [Mobile Controls](#mobile-controls)
7. [Desktop Controls](#desktop-controls)
8. [Audio System](#audio-system)
9. [Color System](#color-system)
10. [UI Management](#ui-management)
11. [Shader System](#shader-system)
12. [File I/O](#file-io)
13. [Function Reference](#function-reference)

---

## Overview

Kaldao is an interactive WebGL fractal visualizer that renders complex, animated geometric patterns in real-time. It features extensive parameter control, multi-platform support, audio reactivity, and device-responsive design.

### Key Features
- Real-time WebGL fractal rendering
- 16 adjustable parameters controlling pattern behavior
- Multi-platform support (desktop keyboard, mobile touch/gestures)
- Audio reactivity with microphone and file input
- Device orientation control (mobile tilt)
- Color palette system with randomization
- Parameter saving/loading system
- Undo/redo functionality
- Responsive UI design

---

## Architecture

### Core Components

1. **WebGL Rendering Engine**: Manages shaders, uniforms, and rendering pipeline
2. **Parameter System**: Centralized control of all visual parameters
3. **Input Management**: Handles keyboard, touch, and gesture inputs
4. **Audio Processing**: Real-time audio analysis and parameter modulation
5. **UI System**: Responsive interface with auto-hide functionality
6. **Color Management**: Dynamic palette system with multiple presets

### File Structure
```
kaldao.html
├── HTML Structure
│   ├── Canvas element
│   ├── UI overlay
│   └── Menu system (desktop/mobile)
├── CSS Styling
│   ├── Base styles
│   ├── Mobile responsive design
│   └── Menu layouts
└── JavaScript
    ├── Global variables
    ├── Parameter definitions
    ├── Shader code
    ├── Input handlers
    ├── Audio system
    ├── Rendering loop
    └── Utility functions
```

---

## Global Variables

### Version Control
```javascript
const VERSION = "0.3.2"  // Centralized version management
```

### Core WebGL Variables
```javascript
let gl, canvas, program     // WebGL context and shader program
let uniforms = {}          // Shader uniform locations
```

### Application State
```javascript
let animationPaused = false        // Animation state
let currentParameterIndex = 0      // Currently selected parameter
let currentPaletteIndex = 0        // Current color palette
let useColorPalette = false        // Color mode toggle
let invertColors = false           // Color inversion state
let menuVisible = false            // UI menu visibility
```

### Mobile Touch System
```javascript
let isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
let touchStartX = 0, touchStartY = 0    // Touch coordinates
let touchStartTime = 0                  // Touch timing
let isSwipeInProgress = false           // Gesture state
let gestureType = null                  // Current gesture type
let userIsCurrentlyTouching = false     // Touch state tracking
```

### Device Features
```javascript
// Orientation control
let deviceTiltEnabled = false
let baseOrientation = { beta: 0, gamma: 0 }
let orientationCalibrated = false

// Pinch/zoom gestures
let isPinching = false
let initialPinchDistance = 0
let initialZoomValue = 0

// Shake detection
let shakeThreshold = 25
let lastAcceleration = { x: 0, y: 0, z: 0 }
```

### Audio System
```javascript
let audioContext = null       // Web Audio API context
let audioSource = null        // Audio source node
let analyser = null          // Audio analyzer node
let audioReactive = false    // Audio reactivity state
let microphoneActive = false // Microphone state
```

### UI Management
```javascript
let controlsVisible = true
let controlsFadeTimeout = null
const CONTROLS_FADE_DELAY = 3000  // 3 second auto-hide
```

---

## Parameters System

### Parameter Structure
Each parameter follows this structure:
```javascript
{
    value: <current_value>,    // Current parameter value
    min: <minimum_value>,      // Minimum allowed value
    max: <maximum_value>,      // Maximum allowed value
    step: <step_size>,         // Increment/decrement step
    name: <display_name>       // Human-readable name
}
```

### Parameter Categories

#### Movement & Animation
- **fly_speed**: Camera movement speed (-3.0 to 3.0)
- **rotation_speed**: Pattern rotation speed (-6.0 to 6.0)
- **plane_rotation_speed**: Layer rotation speed (-5.0 to 5.0)
- **zoom_level**: View zoom level (-5.0 to 5.0)

#### Pattern & Visual
- **kaleidoscope_segments**: Mirror segments (4 to 80, even numbers)
- **truchet_radius**: Pattern curvature (-1.0 to 1.0)
- **center_fill_radius**: Center circle size (-2.0 to 2.0)
- **layer_count**: Rendering layers (1 to 10)
- **contrast**: Visual contrast (0.1 to 5.0)
- **color_intensity**: Color saturation (0.1 to 2.0)

#### Camera & Path
- **camera_tilt_x**: Camera X-axis tilt (-10.0 to 10.0)
- **camera_tilt_y**: Camera Y-axis tilt (-10.0 to 10.0)
- **camera_roll**: Camera rotation (-3.14 to 3.14)
- **path_stability**: Movement smoothness (-1.0 to 1.0)
- **path_scale**: Path scaling (-3.0 to 3.0)

#### Color & Speed
- **color_speed**: Color animation speed (0.0 to 2.0)

### Parameter Order
```javascript
const parameterKeys = [
    'fly_speed', 'rotation_speed', 'plane_rotation_speed', 'zoom_level',
    'kaleidoscope_segments', 'truchet_radius', 'center_fill_radius', 
    'layer_count', 'contrast', 'color_intensity',
    'camera_tilt_x', 'camera_tilt_y', 'camera_roll', 
    'path_stability', 'path_scale', 'color_speed'
]
```

---

## Rendering Pipeline

### WebGL Setup
1. **Context Creation**: Acquire WebGL2 or WebGL context
2. **Shader Compilation**: Compile vertex and fragment shaders
3. **Program Linking**: Link shaders into program
4. **Uniform Setup**: Cache uniform locations
5. **Geometry Setup**: Create full-screen quad

### Render Loop
```javascript
function render() {
    // 1. Update time accumulation
    timeAccumulation.camera_position += parameters.fly_speed.value * deltaTime
    timeAccumulation.rotation_time += parameters.rotation_speed.value * deltaTime
    timeAccumulation.plane_rotation_time += parameters.plane_rotation_speed.value * deltaTime
    timeAccumulation.color_time += parameters.color_speed.value * deltaTime
    
    // 2. Apply audio reactivity
    applyAudioReactivity()
    
    // 3. Set uniforms
    gl.uniform2f(uniforms.u_resolution, canvas.width, canvas.height)
    gl.uniform1f(uniforms.u_time, performance.now() * 0.001)
    // ... set all parameter uniforms
    
    // 4. Draw full-screen quad
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    
    // 5. Request next frame
    requestAnimationFrame(render)
}
```

### Time Accumulation
Time-based parameters accumulate over time for smooth animation:
- **camera_position**: Controls movement through fractal space
- **rotation_time**: Controls pattern rotation
- **plane_rotation_time**: Controls layer rotation
- **color_time**: Controls color cycling

---

## Mobile Controls

### Touch Gestures

#### Single Touch
- **Tap**: Toggle menu visibility
- **Long Press (2s)**: Reset all parameters to defaults
- **Horizontal Swipe**: Switch parameters
- **Vertical Swipe**: Adjust parameter values (fader-style)

#### Multi-Touch
- **Two-Finger Tap**: Randomize colors
- **Pinch**: Control zoom level
- **Shake**: Randomize all parameters

### Device Features
- **Device Tilt**: Controls camera tilt X/Y axes
- **Audio Input**: Microphone support for audio reactivity

### Touch Handler Implementation
```javascript
function handleTouchStart(e) {
    // Menu handling
    if (e.target.closest('.menu') && menuVisible) {
        toggleMenu()
        return
    }
    
    // Single touch
    if (e.touches.length === 1) {
        // Store initial state
        touchStartX = touch.clientX
        touchStartY = touch.clientY
        touchStartTime = Date.now()
        initialParameterValue = parameters[currentParam].value
        
        // Start long press timer
        longPressTimeout = setTimeout(resetAllParameters, 2000)
    }
    
    // Two-finger touch
    else if (e.touches.length === 2) {
        // Setup for pinch or two-finger tap
        initialPinchDistance = calculateDistance(touches)
        initialZoomValue = parameters.zoom_level.value
    }
}
```

### Gesture Detection
- **Movement Threshold**: 10px to cancel long press
- **Swipe Threshold**: 30px for horizontal, 15px for vertical
- **Pinch Threshold**: 30px distance change to activate zoom
- **Tap Duration**: <300ms for quick taps

---

## Desktop Controls

### Keyboard Layout (Context-Aware)

#### Menu Closed (Intuitive Mode)
- **←/→**: Cycle through parameters
- **↑/↓**: Increase/decrease parameter values

#### Menu Open (Navigation Mode)
- **↑/↓**: Cycle through parameters
- **←/→**: Increase/decrease parameter values

#### Universal Controls
- **ESC**: Toggle menu
- **Space**: Pause/resume animation
- **C**: Randomize colors
- **Shift+C**: Reset to black & white
- **R**: Reset current parameter
- **Shift+R**: Reset all parameters
- **Period (.)**: Randomize all parameters
- **I**: Invert colors
- **S**: Save parameters to file
- **L**: Load parameters from file
- **A**: Toggle audio file/upload
- **M**: Toggle microphone
- **Ctrl+Z**: Undo
- **Ctrl+Y**: Redo

---

## Audio System

### Components
1. **Web Audio API**: Core audio processing
2. **Real-time Analysis**: FFT analysis of audio input
3. **Parameter Modulation**: Audio-reactive parameter scaling
4. **Multiple Sources**: File upload and microphone support

### Audio Processing Pipeline
```javascript
function analyzeAudio() {
    analyser.getByteFrequencyData(audioData)
    
    // Frequency ranges (44.1kHz sample rate)
    const bassRange = { start: 0, end: 32 }      // ~20-250Hz
    const midRange = { start: 32, end: 128 }     // ~250-2000Hz  
    const trebleRange = { start: 128, end: 256 } // ~2000-8000Hz
    
    // Calculate average volumes
    const bass = getAverageVolume(bassRange)
    const mid = getAverageVolume(midRange)
    const treble = getAverageVolume(trebleRange)
    
    return { bass, mid, treble, overall: (bass + mid + treble) / 3 }
}
```

### Audio Modifiers
Audio doesn't directly change parameters but applies multipliers:
```javascript
const audioModifiers = {
    // Bass effects (center pulsing, zoom)
    center_fill_radius: bassMultiplier * 1.5,
    truchet_radius: bassMultiplier,
    zoom_level: 1.0 + (audioLevels.bass * 0.3),
    
    // Mid frequencies (rotation, movement)
    rotation_speed: midMultiplier,
    plane_rotation_speed: midMultiplier,
    fly_speed: 1.0 + (audioLevels.mid * 0.6),
    
    // Treble (complexity, color)
    kaleidoscope_segments: trebleMultiplier,
    color_intensity: trebleMultiplier,
    color_speed: trebleMultiplier,
    
    // Overall (contrast, layers)
    contrast: overallMultiplier,
    layer_count: 1.0 + (audioLevels.overall * 0.3)
}
```

---

## Color System

### Palette Structure
Each palette contains four vec3 components for the cosine palette formula:
```javascript
{
    name: "Palette Name",
    a: [r, g, b],    // Offset
    b: [r, g, b],    // Amplitude
    c: [r, g, b],    // Frequency
    d: [r, g, b]     // Phase
}
```

### Shader Color Function
```glsl
vec3 palette(float t) {
    return u_palette_a + u_palette_b * cos(6.28318 * (u_palette_c * t + u_palette_d));
}
```

### Built-in Palettes
1. **B&W**: Monochrome default
2. **Rainbow**: Full spectrum colors
3. **Fire**: Warm orange/red tones
4. **Ocean**: Cool blue/cyan tones
5. **Purple**: Purple/magenta hues
6. **Neon**: High-contrast bright colors
7. **Sunset**: Warm gradient colors

### Color Operations
- **Randomization**: Generates new random palette values
- **Inversion**: `vec3(1.0) - color`
- **Reset**: Return to B&W palette
- **Intensity**: Multiplier for color saturation

---

## UI Management

### Responsive Design
The UI adapts to different screen sizes and input methods:

#### Desktop Layout
- **Left Panel**: Current parameter and status
- **Right Panel**: Keyboard controls reference
- **Center Menu**: Full parameter list + color/audio status

#### Mobile Layout
- **Top Panel**: Current parameter and status (auto-hide)
- **Center Menu**: Compact parameter list only
- **Touch Hints**: Gesture instructions

### Auto-Hide System
```javascript
function resetMobileUITimer() {
    if (isMobile && !menuVisible && !userIsCurrentlyTouching) {
        ui.classList.remove('hidden')
        
        controlsFadeTimeout = setTimeout(() => {
            if (!menuVisible && !userIsCurrentlyTouching) {
                ui.classList.add('hidden')
                clearStatusMessage()
            }
        }, CONTROLS_FADE_DELAY)
    }
}
```

### Menu System
- **Toggle**: ESC (desktop), Tap (mobile)
- **Context-Aware**: Different layouts for desktop/mobile
- **Auto-Update**: Real-time parameter value display
- **Status Messages**: User feedback for actions

---

## Shader System

### Vertex Shader
Simple full-screen quad setup:
```glsl
attribute vec2 a_position;
void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
}
```

### Fragment Shader Structure
1. **Uniforms**: All parameters and system values
2. **Helper Functions**: Mathematical utilities
3. **Geometry Functions**: Fractal pattern generation
4. **Rendering Pipeline**: Layer composition and effects
5. **Post-Processing**: Color and visual enhancements

### Key Shader Functions

#### Camera System
```glsl
vec3 offset(float z) {
    // Generate curved camera path
    vec2 curved_path = -0.075 * u_path_scale * (
        vec2(cos(z), sin(z * sqrt(2.0))) +
        vec2(cos(z * sqrt(0.75)), sin(z * sqrt(0.5)))
    );
    
    vec2 straight_path = vec2(0.0);
    vec2 p = mix(curved_path, straight_path, u_path_stability);
    
    return vec3(p, z);
}
```

#### Kaleidoscope Effect
```glsl
float smoothKaleidoscope(inout vec2 p, float sm, float rep) {
    vec2 hpp = toPolar(p);
    float evenRep = floor(rep * 0.5) * 2.0;  // Ensure even segments
    float rn = modMirror1(hpp.y, 2.0 * PI / evenRep);
    
    float sa = PI / evenRep - pabs(PI / evenRep - abs(hpp.y), sm);
    hpp.y = sign(hpp.y) * sa;
    
    p = toRect(hpp);
    return rn;
}
```

#### Truchet Patterns
```glsl
vec3 truchet_df(float r, vec2 p) {
    vec2 np = floor(p + 0.5);
    vec2 mp = fract(p + 0.5) - 0.5;
    return cell_df(r, np, mp, vec2(0.0));
}
```

---

## File I/O

### Save Format
Parameters are saved as JSON with metadata:
```json
{
    "parameters": {
        "fly_speed": 0.25,
        "contrast": 1.0,
        // ... all parameter values
    },
    "palette": {
        "currentPaletteIndex": 0,
        "useColorPalette": false,
        "invertColors": false,
        "palettes": [/* palette data */]
    },
    "timeAccumulation": {
        "camera_position": 0.0,
        "rotation_time": 0.0,
        "plane_rotation_time": 0.0,
        "color_time": 0.0
    },
    "version": "0.3.2",
    "timestamp": "2025-01-06T12:00:00.000Z",
    "description": "Kaldao Fractal Visualizer Parameters"
}
```

### File Operations
- **Save**: Downloads JSON file with timestamp
- **Load**: Uploads and validates JSON file
- **Validation**: Checks file format and parameter bounds
- **Error Handling**: User feedback for invalid files

---

## Function Reference

### Core Functions

#### `init()`
Initialize the application:
- Setup WebGL context
- Compile shaders
- Setup input handlers
- Start render loop

#### `render()`
Main rendering loop:
- Update time accumulation
- Apply audio reactivity
- Set shader uniforms
- Draw frame
- Request next frame

#### `updateDisplay()`
Update UI with current parameter values:
- Format parameter display
- Update menu if visible
- Show current palette info

### Parameter Control

#### `switchParameter(delta)`
Navigate through parameters:
- Update `currentParameterIndex`
- Wrap around array bounds
- Update display

#### `adjustParameter(delta)`
Modify current parameter value:
- Apply step increment/decrement
- Clamp to min/max bounds
- Handle special cases (even numbers for kaleidoscope_segments)
- Save undo state

#### `resetAllParameters()`
Reset all parameters to defaults:
- Restore default values
- Reset color system
- Clear time accumulation
- Update display

### Audio System

#### `initAudioContext()`
Initialize Web Audio API:
- Create audio context
- Setup analyzer node
- Configure audio processing

#### `analyzeAudio()`
Process audio input:
- Get frequency data
- Calculate frequency bands
- Return audio levels object

#### `applyAudioReactivity()`
Apply audio to parameters:
- Calculate multipliers from audio levels
- Apply to audio modifier system
- Map frequency ranges to parameter effects

### Mobile Controls

#### `handleTouchStart(e)`
Process touch start events:
- Detect gesture type
- Store initial values
- Setup timers for long press

#### `handleTouchMove(e)`
Process touch movement:
- Determine gesture type
- Handle fader adjustments
- Manage pinch gestures

#### `handleTouchEnd(e)`
Process touch end events:
- Complete gestures
- Handle tap detection
- Reset touch state

#### `handleDeviceOrientation(e)`
Process device orientation:
- Calibrate initial position
- Map tilt to camera parameters
- Apply smooth sensitivity scaling

### Color Management

#### `randomizeColors()`
Generate new random palette:
- Create random RGB values
- Activate color palette mode
- Save undo state

#### `toggleInvertColors()`
Toggle color inversion:
- Flip inversion state
- Update shader uniform
- Update display

### UI Management

#### `toggleMenu()`
Show/hide parameter menu:
- Toggle menu visibility
- Update UI elements
- Handle mobile/desktop differences

#### `resetMobileUITimer()`
Manage mobile UI auto-hide:
- Show UI elements
- Setup fade timer
- Clear previous timers

#### `updateStatus(message, type)`
Display status messages:
- Set message text
- Apply styling class
- Handle auto-clear on fade

---

## Performance Considerations

### Optimization Strategies
1. **Uniform Caching**: Store uniform locations to avoid lookups
2. **Conditional Updates**: Only update display when values change
3. **Audio Throttling**: Limit audio analysis frequency
4. **Touch Debouncing**: Prevent excessive gesture processing
5. **Menu Updates**: Only update when visible

### Memory Management
- **Event Listeners**: Properly cleanup on page unload
- **Audio Streams**: Close microphone streams when not needed
- **Timeouts**: Clear all timeouts on state changes

### Browser Compatibility
- **WebGL Fallback**: WebGL2 with WebGL1 fallback
- **Audio Permissions**: iOS 13+ permission handling
- **Touch Events**: Cross-platform touch normalization

---

## Development Notes

### Code Organization
- **Global Variables**: Centralized at top of script
- **Function Grouping**: Related functions organized together
- **Commenting**: Key algorithms and complex logic documented
- **Error Handling**: Try-catch blocks for WebGL and audio operations

### Maintenance
- **Version Control**: Centralized VERSION constant
- **Parameter Addition**: Add to parameters object and parameterKeys array
- **Shader Updates**: Modify fragment shader and update uniforms
- **Mobile Features**: Add to setupMobileControls() function

### Testing Considerations
- **Multiple Devices**: Test on various screen sizes and orientations
- **Audio Sources**: Test with different audio files and microphone quality
- **Performance**: Monitor frame rate on lower-end devices
- **Gestures**: Ensure gesture recognition works across touch devices

---

*Documentation last updated: January 2025*  
*For the complete source code, see: kaldao.html*