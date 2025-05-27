# Kaldao Refactored API Reference

## Overview

This document provides a comprehensive API reference for the refactored Kaldao architecture. The new system is built around four core principles:

1. **Dependency Injection** via ServiceLocator
2. **Event-Driven Communication** via EventBus
3. **Configuration Management** via ConfigManager
4. **Type Safety** via structured data classes

## Table of Contents

- [Core Architecture](#core-architecture)
- [Data Models](#data-models)
- [Managers](#managers)
- [Components](#components)
- [Configuration](#configuration)
- [Events](#events)
- [Usage Examples](#usage-examples)

---

## Core Architecture

### ServiceLocator

**Purpose**: Centralized dependency injection system for managing service instances.

#### Constants
```gdscript
const AUDIO_MANAGER = "AudioManager"
const PARAMETER_MANAGER = "ParameterManager"
const SHADER_MANAGER = "ShaderManager"
const COLOR_PALETTE_MANAGER = "ColorPaletteManager"
const INPUT_MANAGER = "InputManager"
const MENU_MANAGER = "MenuManager"
const AUDIO_ANALYZER = "AudioAnalyzer"
const BEAT_DETECTOR = "BeatDetector"
```

#### Methods

##### `register_service(service_name: String, service_instance: Object) -> bool`
Register a service instance with the locator.
- **Parameters**: 
  - `service_name`: Unique identifier for the service
  - `service_instance`: The service object instance
- **Returns**: `true` if registration successful
- **Example**:
```gdscript
var audio_manager = AudioManager.new()
ServiceLocator.register_service(ServiceLocator.AUDIO_MANAGER, audio_manager)
```

##### `get_service(service_name: String) -> Object`
Retrieve a registered service instance.
- **Parameters**: `service_name`: The service identifier
- **Returns**: Service instance or `null` if not found
- **Example**:
```gdscript
var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
```

##### `is_service_registered(service_name: String) -> bool`
Check if a service is registered.
- **Parameters**: `service_name`: The service identifier
- **Returns**: `true` if service is registered

##### `unregister_service(service_name: String) -> bool`
Remove a service from the locator.
- **Parameters**: `service_name`: The service identifier
- **Returns**: `true` if service was removed

##### `cleanup() -> void`
Clean up all registered services and clear the locator.

---

### EventBus

**Purpose**: Global event communication system for decoupled component interaction.

#### Audio Events

##### `emit_audio_file_loaded(file_path: String) -> void`
Emitted when an audio file is successfully loaded.

##### `emit_audio_playback_started() -> void`
Emitted when audio playback begins.

##### `emit_audio_playback_stopped() -> void`
Emitted when audio playback stops.

##### `emit_audio_position_changed(position: float) -> void`
Emitted when audio playback position changes.

##### `emit_audio_level_changed(level: float) -> void`
Emitted when audio level changes.

##### `emit_audio_spectrum_updated(spectrum: PackedFloat32Array) -> void`
Emitted when audio spectrum data is updated.

##### `emit_beat_detected(intensity: float) -> void`
Emitted when a beat is detected.

#### Parameter Events

##### `emit_parameter_changed(param_name: String, value: float) -> void`
Emitted when a parameter value changes.

##### `emit_parameter_reset(param_name: String, value: float) -> void`
Emitted when a parameter is reset to default.

##### `emit_parameter_randomized(category: String) -> void`
Emitted when parameters in a category are randomized.

#### UI Events

##### `emit_menu_show_requested() -> void`
Request to show the menu system.

##### `emit_menu_hide_requested() -> void`
Request to hide the menu system.

##### `emit_parameter_display_requested(param_name: String, value: float) -> void`
Request to display a parameter value.

#### Connection Methods

##### `connect_to_audio_file_loaded(callable: Callable) -> void`
Connect to audio file loaded events.

##### `connect_to_parameter_changed(callable: Callable) -> void`
Connect to parameter change events.

**Example**:
```gdscript
EventBus.connect_to_parameter_changed(_on_parameter_changed)

func _on_parameter_changed(param_name: String, value: float) -> void:
    print("Parameter %s changed to %f" % [param_name, value])
```

---

### ConfigManager

**Purpose**: Centralized configuration management with JSON persistence.

#### Methods

##### `get_config_value(key: String, default_value: Variant) -> Variant`
Get a configuration value with fallback to default.
- **Parameters**:
  - `key`: Dot-notation configuration key (e.g., "audio.volume")
  - `default_value`: Value to return if key not found
- **Returns**: Configuration value or default
- **Example**:
```gdscript
var volume = ConfigManager.get_config_value("audio.volume", 0.8)
```

##### `set_config_value(key: String, value: Variant) -> void`
Set a configuration value.
- **Parameters**:
  - `key`: Dot-notation configuration key
  - `value`: Value to set

##### `save_user_config(additional_data: Dictionary = {}) -> bool`
Save current configuration to user directory.
- **Parameters**: `additional_data`: Additional data to include
- **Returns**: `true` if save successful

##### `load_user_config() -> bool`
Load configuration from user directory.
- **Returns**: `true` if load successful

##### `get_audio_amplifier(frequency_type: String) -> float`
Get audio amplifier for frequency type.
- **Parameters**: `frequency_type`: "bass", "mid", or "treble"
- **Returns**: Amplifier value

##### `get_beat_detection_sensitivity() -> float`
Get beat detection sensitivity setting.

##### `get_startup_menu_duration() -> float`
Get startup menu display duration.

---

### ApplicationBootstrap

**Purpose**: Application initialization and lifecycle management.

#### Methods

##### `initialize(scene_root: Node) -> bool`
Initialize the entire application system.
- **Parameters**: `scene_root`: Root node of the scene
- **Returns**: `true` if initialization successful
- **Example**:
```gdscript
func _ready():
    var bootstrap = ApplicationBootstrap.new()
    var success = await bootstrap.initialize(self)
    if success:
        print("Application initialized successfully")
```

##### `cleanup() -> void`
Clean up all systems and prepare for shutdown.

---

## Data Models

### ParameterData

**Purpose**: Type-safe parameter definition with validation and constraints.

#### Properties

##### `name: String`
Parameter identifier name.

##### `display_name: String`
Human-readable parameter name.

##### `description: String`
Parameter description for UI display.

##### `min_value: float`
Minimum allowed value.

##### `max_value: float`
Maximum allowed value.

##### `default_value: float`
Default parameter value.

##### `step_size: float`
Increment/decrement step size.

##### `category: String`
Parameter category for organization.

##### `is_integer: bool`
Whether parameter should be treated as integer.

##### `is_even_integer: bool`
Whether parameter should be even integers only.

#### Methods

##### `create_parameter(name: String, min_val: float, max_val: float, default_val: float, category: String = "general") -> ParameterData`
Static method to create a new parameter.
- **Example**:
```gdscript
var zoom_param = ParameterData.create_parameter("zoom_level", 0.1, 5.0, 1.0, "camera")
```

##### `validate_value(value: float) -> float`
Validate and clamp a value to parameter constraints.

##### `increase_value(current_value: float) -> float`
Increase value by step size within constraints.

##### `decrease_value(current_value: float) -> float`
Decrease value by step size within constraints.

##### `randomize_value() -> float`
Generate a random value within parameter constraints.

##### `to_dictionary() -> Dictionary`
Convert parameter to dictionary for serialization.

##### `from_dictionary(data: Dictionary) -> void`
Load parameter from dictionary data.

---

## Managers

### AudioManager

**Purpose**: Centralized audio system management with component integration.

#### Methods

##### `initialize() -> bool`
Initialize the audio manager and components.

##### `load_audio_file(file_path: String) -> bool`
Load an audio file for playback.
- **Parameters**: `file_path`: Path to audio file
- **Returns**: `true` if load successful

##### `play_audio() -> void`
Start audio playback.

##### `pause_audio() -> void`
Pause audio playback.

##### `stop_audio() -> void`
Stop audio playback.

##### `seek_to_position(position: float) -> void`
Seek to specific position in audio.
- **Parameters**: `position`: Time position in seconds

##### `get_playback_position() -> float`
Get current playback position.
- **Returns**: Current position in seconds

##### `get_audio_level() -> float`
Get current audio level.
- **Returns**: Audio level (0.0 to 1.0)

##### `is_playing() -> bool`
Check if audio is currently playing.

##### `set_audio_stream_player(player: AudioStreamPlayer) -> void`
Set the audio stream player instance.

---

### ParameterManager

**Purpose**: Centralized visual parameter management with type safety.

#### Methods

##### `initialize() -> bool`
Initialize the parameter manager with default parameters.

##### `add_parameter(param_data: ParameterData) -> bool`
Add a new parameter to the manager.
- **Parameters**: `param_data`: ParameterData instance
- **Returns**: `true` if parameter added successfully

##### `get_parameter_value(param_name: String) -> float`
Get current value of a parameter.
- **Parameters**: `param_name`: Parameter identifier
- **Returns**: Current parameter value

##### `set_parameter_value(param_name: String, value: float) -> bool`
Set parameter value with validation.
- **Parameters**:
  - `param_name`: Parameter identifier
  - `value`: New parameter value
- **Returns**: `true` if value set successfully

##### `get_parameter_info(param_name: String) -> Dictionary`
Get parameter metadata and current value.
- **Returns**: Dictionary with parameter information

##### `get_parameters_in_category(category: String) -> Array[String]`
Get all parameter names in a category.
- **Parameters**: `category`: Category name
- **Returns**: Array of parameter names

##### `randomize_category(category: String) -> void`
Randomize all parameters in a category.

##### `reset_parameter(param_name: String) -> void`
Reset parameter to default value.

##### `save_parameter_data() -> Dictionary`
Save all parameter data for persistence.

##### `load_parameter_data(data: Dictionary) -> bool`
Load parameter data from saved state.

---

### ShaderManager

**Purpose**: Centralized shader parameter management with multi-shader support.

#### Methods

##### `initialize() -> bool`
Initialize the shader manager.

##### `set_current_shader(shader_name: String) -> bool`
Switch to a different shader.
- **Parameters**: `shader_name`: "kaldao", "kaleidoscope", or "koch"
- **Returns**: `true` if shader switched successfully

##### `update_shader_parameter(param_name: String, value: float) -> void`
Update a shader parameter value.
- **Parameters**:
  - `param_name`: Parameter name
  - `value`: Parameter value

##### `set_target_material(target: Node) -> void`
Set the target node for shader rendering.
- **Parameters**: `target`: Node with material property

##### `apply_color_palette(colors: Array[Color]) -> void`
Apply a color palette to the current shader.

---

### ColorPaletteManager

**Purpose**: Advanced color palette management with dynamic generation.

#### Methods

##### `initialize() -> bool`
Initialize the palette manager.

##### `get_current_palette() -> Array[Color]`
Get the currently active color palette.

##### `set_current_palette(palette_name: String) -> bool`
Switch to a different palette.
- **Parameters**: `palette_name`: Name of the palette
- **Returns**: `true` if palette switched successfully

##### `generate_random_palette() -> Array[Color]`
Generate a random color palette.

##### `add_custom_palette(name: String, colors: Array[Color]) -> bool`
Add a custom color palette.
- **Parameters**:
  - `name`: Palette name
  - `colors`: Array of Color objects

##### `get_available_palettes() -> Array[String]`
Get list of available palette names.

---

### InputManager

**Purpose**: Context-aware input handling with gesture recognition.

#### Methods

##### `initialize() -> bool`
Initialize the input manager.

##### `handle_input(event: InputEvent) -> bool`
Process an input event.
- **Parameters**: `event`: Input event to process
- **Returns**: `true` if event was handled

##### `push_input_context(context_name: String) -> void`
Push a new input context onto the stack.

##### `pop_input_context() -> void`
Pop the current input context from the stack.

##### `set_key_binding(action: String, key: Key) -> void`
Set a key binding for an action.

---

### MenuManager

**Purpose**: State-based menu system with smooth animations.

#### Methods

##### `initialize(ui_elements: Dictionary) -> bool`
Initialize the menu manager with UI elements.
- **Parameters**: `ui_elements`: Dictionary of UI element references

##### `show_menu() -> void`
Show the menu system with animations.

##### `hide_menu() -> void`
Hide the menu system with animations.

##### `toggle_menu() -> void`
Toggle menu visibility.

##### `is_menu_visible() -> bool`
Check if menu is currently visible.

##### `set_first_launch(is_first: bool) -> void`
Set whether this is the first application launch.

---

## Components

### TimelineComponent

**Purpose**: Audio timeline scrubber and visualizer.

#### Methods

##### `initialize() -> bool`
Initialize the timeline component.

##### `set_song_duration(duration: float) -> void`
Set the total song duration.

##### `update_checkpoint_markers(checkpoints: Array) -> void`
Update checkpoint markers on the timeline.

#### Signals

##### `seek_requested(timestamp: float)`
Emitted when user requests to seek to a position.

##### `play_pause_requested()`
Emitted when user requests play/pause toggle.

---

### ParameterDisplayComponent

**Purpose**: Reusable parameter value display with animations.

#### Enums

##### `DisplayMode`
- `OVERLAY`: Overlay on top of content
- `SIDEBAR`: Fixed sidebar display
- `BOTTOM_BAR`: Bottom status bar
- `FLOATING`: Floating window
- `MINIMAL`: Minimal text-only display

#### Methods

##### `initialize() -> bool`
Initialize the parameter display component.

##### `show_parameter(param_name: String, value: float, force_show: bool = false) -> void`
Display a parameter value.

##### `hide_parameter(animate: bool = true) -> void`
Hide the parameter display.

##### `set_display_mode(mode: DisplayMode) -> void`
Change the display mode.

#### Signals

##### `parameter_display_shown(param_name: String, value: float)`
Emitted when parameter display is shown.

##### `parameter_validation_failed(param_name: String, error: String)`
Emitted when parameter validation fails.

---

### AudioVisualizerComponent

**Purpose**: Real-time audio visualization with multiple modes.

#### Enums

##### `VisualizationMode`
- `SPECTRUM`: Frequency spectrum bars
- `WAVEFORM`: Audio waveform
- `CIRCULAR`: Circular spectrum
- `BARS`: Traditional bar graph
- `PARTICLES`: Particle-based visualization
- `MINIMAL`: Minimal level indicators

#### Methods

##### `initialize() -> bool`
Initialize the audio visualizer component.

##### `set_visualization_mode(mode: VisualizationMode) -> void`
Change the visualization mode.

##### `toggle_visualizer() -> void`
Toggle visualizer active state.

##### `set_active(active: bool) -> void`
Set visualizer active state.

#### Signals

##### `visualization_mode_changed(mode: VisualizationMode)`
Emitted when visualization mode changes.

##### `beat_detected(intensity: float)`
Emitted when a beat is detected.

---

## Configuration

### Configuration Structure

The configuration system uses JSON files with dot-notation keys:

```json
{
  "app": {
    "window": {
      "title": "Kaldao",
      "fullscreen_mode": false
    },
    "performance": {
      "target_fps": 60,
      "vsync_enabled": true
    }
  },
  "audio": {
    "volume": 0.8,
    "amplifiers": {
      "bass": 2.0,
      "mid": 1.5,
      "treble": 1.2
    },
    "beat_detection": {
      "sensitivity": 0.7,
      "threshold": 0.3
    }
  },
  "ui": {
    "timeline": {
      "height": 60,
      "show_time_markers": true
    },
    "parameter_display": {
      "show_duration": 3.0,
      "fade_duration": 1.0
    }
  }
}
```

### Common Configuration Keys

#### Audio Settings
- `audio.volume`: Master volume (0.0 - 1.0)
- `audio.amplifiers.bass`: Bass frequency amplifier
- `audio.beat_detection.sensitivity`: Beat detection sensitivity

#### UI Settings
- `ui.timeline.height`: Timeline component height
- `ui.parameter_display.position`: Parameter display position
- `ui.menu.fade_duration`: Menu animation duration

#### Performance Settings
- `app.performance.target_fps`: Target frame rate
- `app.performance.vsync_enabled`: VSync setting

---

## Usage Examples

### Basic Application Setup

```gdscript
extends Control

func _ready():
    # Initialize the application
    var bootstrap = ApplicationBootstrap.new()
    var success = await bootstrap.initialize(self)
    
    if success:
        # Get managers
        var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
        var param_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
        
        # Load audio file
        audio_manager.load_audio_file("res://audio/song.ogg")
        
        # Set up parameter change listener
        EventBus.connect_to_parameter_changed(_on_parameter_changed)
        
        print("Application ready!")

func _on_parameter_changed(param_name: String, value: float):
    print("Parameter %s changed to %f" % [param_name, value])
```

### Creating Custom Parameters

```gdscript
# Create a custom parameter
var zoom_param = ParameterData.create_parameter(
    "zoom_level",     # name
    0.1,              # min_value
    5.0,              # max_value
    1.0,              # default_value
    "camera"          # category
)

zoom_param.display_name = "Zoom Level"
zoom_param.description = "Camera zoom factor"
zoom_param.step_size = 0.1

# Add to parameter manager
var param_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
param_manager.add_parameter(zoom_param)
```

### Using Components

```gdscript
# Create and initialize timeline component
var timeline = TimelineComponent.new()
add_child(timeline)
timeline.initialize()

# Connect to timeline events
timeline.seek_requested.connect(_on_seek_requested)
timeline.play_pause_requested.connect(_on_play_pause_requested)

func _on_seek_requested(timestamp: float):
    var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
    audio_manager.seek_to_position(timestamp)

func _on_play_pause_requested():
    var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
    if audio_manager.is_playing():
        audio_manager.pause_audio()
    else:
        audio_manager.play_audio()
```

### Configuration Management

```gdscript
# Get configuration values
var volume = ConfigManager.get_config_value("audio.volume", 0.8)
var timeline_height = ConfigManager.get_config_value("ui.timeline.height", 60)

# Set configuration values
ConfigManager.set_config_value("audio.volume", 0.9)
ConfigManager.set_config_value("ui.theme", "dark")

# Save configuration
ConfigManager.save_user_config()
```

### Event-Driven Communication

```gdscript
# Emit events
EventBus.emit_parameter_changed("zoom_level", 1.5)
EventBus.emit_audio_playback_started()

# Connect to events
EventBus.connect_to_beat_detected(_on_beat_detected)
EventBus.connect_to_menu_show_requested(_on_menu_show_requested)

func _on_beat_detected(intensity: float):
    # React to beat detection
    if intensity > 0.8:
        # Trigger visual effect
        pass

func _on_menu_show_requested():
    var menu_manager = ServiceLocator.get_service(ServiceLocator.MENU_MANAGER)
    menu_manager.show_menu()
```

---

## Best Practices

### 1. Service Registration
Always register services through ApplicationBootstrap or in proper initialization order:

```gdscript
# Good
var bootstrap = ApplicationBootstrap.new()
await bootstrap.initialize(self)

# Avoid manual registration unless necessary
```

### 2. Event Connections
Connect to events early in initialization and clean up properly:

```gdscript
func _ready():
    EventBus.connect_to_parameter_changed(_on_parameter_changed)

func cleanup():
    # EventBus automatically handles cleanup, but you can disconnect manually if needed
    pass
```

### 3. Configuration Access
Use ConfigManager for all settings instead of hardcoded values:

```gdscript
# Good
var sensitivity = ConfigManager.get_config_value("audio.beat_detection.sensitivity", 0.7)

# Avoid
var sensitivity = 0.7  # Hardcoded value
```

### 4. Parameter Management
Use ParameterData for type-safe parameter handling:

```gdscript
# Good
var param_data = ParameterData.create_parameter("speed", 0.0, 10.0, 5.0)
param_manager.add_parameter(param_data)

# Avoid direct dictionary manipulation
```

### 5. Component Initialization
Always call initialize() on components and check return value:

```gdscript
var component = TimelineComponent.new()
add_child(component)
if not component.initialize():
    push_error("Failed to initialize component")
```

---

This API reference provides comprehensive documentation for the refactored Kaldao architecture. For implementation examples and tutorials, see the accompanying documentation files.
