# Kaldao Refactored User Guide

## Table of Contents

- [Getting Started](#getting-started)
- [Architecture Overview](#architecture-overview)
- [Setting Up Your First Project](#setting-up-your-first-project)
- [Working with Audio](#working-with-audio)
- [Managing Parameters](#managing-parameters)
- [Customizing Visuals](#customizing-visuals)
- [Configuration System](#configuration-system)
- [Component System](#component-system)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Migration from Old System](#migration-from-old-system)

---

## Getting Started

### What is Kaldao Refactored?

Kaldao Refactored is a complete rewrite of the Kaldao audio visualizer using modern software architecture principles. The new system provides:

- **Modular Design**: Clean separation between audio processing, visual rendering, and user interface
- **Configuration-Driven**: All behavior and appearance controlled through JSON configuration files
- **Event-Driven Communication**: Components communicate through a centralized event system
- **Type-Safe Parameters**: Robust parameter system with validation and constraints
- **Real-Time Audio Visualization**: Multiple visualization modes with beat detection

### Key Benefits

1. **Easier to Customize**: Change colors, layouts, and behavior through configuration files
2. **More Stable**: Robust error handling and graceful degradation
3. **Better Performance**: Optimized audio processing and rendering pipeline
4. **Extensible**: Easy to add new features and components
5. **Well-Documented**: Comprehensive documentation and examples

### System Requirements

- Godot 4.2 or later
- Audio files in supported formats (OGG, WAV, MP3)
- Minimum 4GB RAM for complex visualizations
- Graphics card with shader support

---

## Architecture Overview

### Core Components

The refactored system consists of four main layers:

#### 1. Core Architecture
- **ServiceLocator**: Manages all system services and dependencies
- **EventBus**: Handles communication between components
- **ConfigManager**: Manages all configuration settings
- **ApplicationBootstrap**: Initializes the entire system

#### 2. Managers
- **AudioManager**: Handles audio playback and analysis
- **ParameterManager**: Manages visual parameters
- **ShaderManager**: Controls visual shaders and effects
- **ColorPaletteManager**: Manages color schemes
- **InputManager**: Handles user input
- **MenuManager**: Controls menu system

#### 3. Components
- **AudioAnalyzer**: Performs frequency analysis
- **BeatDetector**: Detects beats in audio
- **TimelineComponent**: Audio timeline scrubber
- **ParameterDisplayComponent**: Shows parameter values
- **AudioVisualizerComponent**: Real-time audio visualization

#### 4. Data Models
- **ParameterData**: Type-safe parameter definitions

### Communication Flow

```
User Input → InputManager → EventBus → Managers → Components → Visual Output
                                    ↓
                            ConfigManager ← → JSON Files
```

---

## Setting Up Your First Project

### Step 1: Project Setup

1. Copy the `REFACTOR` folder to your Godot project
2. Set `REFACTOR/scripts/scenes/KaldaoMain.gd` as your main scene script
3. Ensure all shader files are in the `shaders/` directory
4. Place audio files in the `audio/` directory

### Step 2: Basic Configuration

Create or modify `REFACTOR/config/app_config.json`:

```json
{
  "app": {
    "window": {
      "title": "My Kaldao Visualizer",
      "fullscreen_mode": false
    },
    "default_audio_file": "res://audio/my_song.ogg"
  },
  "audio": {
    "volume": 0.8,
    "amplifiers": {
      "bass": 2.0,
      "mid": 1.5,
      "treble": 1.2
    }
  },
  "visual": {
    "default_shader": "kaldao",
    "default_palette": "rainbow"
  }
}
```

### Step 3: Running the Application

1. Set the main scene to use `KaldaoMain.gd`
2. Run the project
3. The system will automatically initialize all components
4. Load an audio file and start visualizing!

### Step 4: Basic Controls

Default keyboard controls:
- **Space**: Play/Pause audio
- **M**: Toggle menu
- **V**: Toggle audio visualizer
- **Arrow Keys**: Navigate parameters
- **+/-**: Adjust parameter values
- **R**: Randomize current parameter category

---

## Working with Audio

### Loading Audio Files

#### Programmatically
```gdscript
var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
audio_manager.load_audio_file("res://audio/my_song.ogg")
```

#### Through Configuration
Set the default audio file in your configuration:
```json
{
  "app": {
    "default_audio_file": "res://audio/default_song.ogg"
  }
}
```

### Audio Analysis Settings

Configure audio analysis in your config file:

```json
{
  "audio": {
    "analysis": {
      "fft_size": 2048,
      "frequency_bands": {
        "bass": [20, 250],
        "mid": [250, 4000],
        "treble": [4000, 20000]
      },
      "smoothing_factor": 0.8,
      "amplification": 2.0
    },
    "beat_detection": {
      "sensitivity": 0.7,
      "threshold": 0.3,
      "algorithm": "adaptive"
    }
  }
}
```

### Beat Detection

The system includes advanced beat detection with multiple algorithms:

- **Threshold**: Simple amplitude threshold
- **Variance**: Variance-based detection
- **Intensity**: Frequency intensity analysis
- **Adaptive**: Dynamic threshold adjustment

Configure beat detection:
```json
{
  "audio": {
    "beat_detection": {
      "algorithm": "adaptive",
      "sensitivity": 0.7,
      "min_interval": 0.1,
      "max_interval": 2.0
    }
  }
}
```

### Audio Events

Listen to audio events in your code:

```gdscript
func _ready():
    EventBus.connect_to_audio_file_loaded(_on_audio_loaded)
    EventBus.connect_to_beat_detected(_on_beat_detected)
    EventBus.connect_to_audio_level_changed(_on_audio_level_changed)

func _on_audio_loaded(file_path: String):
    print("Audio loaded: " + file_path)

func _on_beat_detected(intensity: float):
    print("Beat detected with intensity: " + str(intensity))

func _on_audio_level_changed(level: float):
    # React to audio level changes
    pass
```

---

## Managing Parameters

### Understanding Parameters

Parameters control visual aspects of the visualization. Each parameter has:

- **Name**: Unique identifier
- **Display Name**: Human-readable name
- **Description**: What the parameter does
- **Range**: Minimum and maximum values
- **Default Value**: Starting value
- **Category**: Grouping for organization
- **Step Size**: Increment/decrement amount

### Creating Custom Parameters

```gdscript
# Create a new parameter
var zoom_param = ParameterData.create_parameter(
    "zoom_level",           # name
    0.1,                    # min_value
    5.0,                    # max_value
    1.0,                    # default_value
    "camera"                # category
)

# Set additional properties
zoom_param.display_name = "Zoom Level"
zoom_param.description = "Controls camera zoom factor"
zoom_param.step_size = 0.1

# Add to parameter manager
var param_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
param_manager.add_parameter(zoom_param)
```

### Parameter Categories

Organize parameters into categories:

- **Movement**: Speed, direction, rotation parameters
- **Visual**: Color, brightness, contrast parameters
- **Camera**: Zoom, position, angle parameters
- **Effects**: Special effect parameters

### Working with Parameter Values

```gdscript
var param_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)

# Get parameter value
var zoom = param_manager.get_parameter_value("zoom_level")

# Set parameter value
param_manager.set_parameter_value("zoom_level", 1.5)

# Get all parameters in a category
var camera_params = param_manager.get_parameters_in_category("camera")

# Randomize a category
param_manager.randomize_category("visual")

# Reset a parameter
param_manager.reset_parameter("zoom_level")
```

### Parameter Events

React to parameter changes:

```gdscript
func _ready():
    EventBus.connect_to_parameter_changed(_on_parameter_changed)
    EventBus.connect_to_parameter_reset(_on_parameter_reset)

func _on_parameter_changed(param_name: String, value: float):
    match param_name:
        "zoom_level":
            update_camera_zoom(value)
        "rotation_speed":
            update_rotation_speed(value)

func _on_parameter_reset(param_name: String, value: float):
    print("Parameter %s reset to %f" % [param_name, value])
```

---

## Customizing Visuals

### Shader System

The system supports multiple shaders:

- **kaldao**: Main kaleidoscope shader
- **kaleidoscope**: Alternative kaleidoscope effect
- **koch**: Koch snowflake fractal

#### Switching Shaders

```gdscript
var shader_manager = ServiceLocator.get_service(ServiceLocator.SHADER_MANAGER)
shader_manager.set_current_shader("kaleidoscope")
```

#### Shader Parameters

Each shader has different parameters. Configure them in your config file:

```json
{
  "visual": {
    "shaders": {
      "kaldao": {
        "parameter_mappings": {
          "zoom_level": "zoom",
          "rotation_speed": "rotation",
          "color_intensity": "intensity"
        }
      },
      "kaleidoscope": {
        "parameter_mappings": {
          "segments": "segments",
          "mirror_angle": "angle"
        }
      }
    }
  }
}
```

### Color Palettes

#### Built-in Palettes

The system includes several built-in color palettes:

- **rainbow**: Full spectrum colors
- **sunset**: Warm orange/red tones
- **ocean**: Blue/green tones
- **monochrome**: Black and white
- **neon**: Bright neon colors

#### Using Palettes

```gdscript
var palette_manager = ServiceLocator.get_service(ServiceLocator.COLOR_PALETTE_MANAGER)

# Switch to a palette
palette_manager.set_current_palette("sunset")

# Get current palette colors
var colors = palette_manager.get_current_palette()

# Generate random palette
var random_colors = palette_manager.generate_random_palette()
```

#### Creating Custom Palettes

```gdscript
var custom_colors = [
    Color.RED,
    Color.ORANGE,
    Color.YELLOW,
    Color.GREEN,
    Color.BLUE
]

palette_manager.add_custom_palette("my_palette", custom_colors)
palette_manager.set_current_palette("my_palette")
```

#### Palette Configuration

Configure palette generation in your config file:

```json
{
  "visual": {
    "color_palettes": {
      "random_generation": {
        "min_colors": 3,
        "max_colors": 8,
        "saturation_range": [0.7, 1.0],
        "brightness_range": [0.8, 1.0],
        "hue_shift_max": 60
      }
    }
  }
}
```

---

## Configuration System

### Configuration Files

The system uses two types of configuration files:

1. **App Config** (`REFACTOR/config/app_config.json`): Default settings
2. **User Config** (`user://kaldao_config.json`): User customizations

### Configuration Structure

```json
{
  "app": {
    "window": { "title": "Kaldao", "fullscreen_mode": false },
    "performance": { "target_fps": 60, "vsync_enabled": true }
  },
  "audio": {
    "volume": 0.8,
    "amplifiers": { "bass": 2.0, "mid": 1.5, "treble": 1.2 },
    "beat_detection": { "sensitivity": 0.7, "algorithm": "adaptive" }
  },
  "visual": {
    "default_shader": "kaldao",
    "default_palette": "rainbow",
    "effects": { "bloom": true, "motion_blur": false }
  },
  "ui": {
    "timeline": { "height": 60, "show_time_markers": true },
    "parameter_display": { "position": "center", "fade_duration": 1.0 },
    "menu": { "fade_duration": 0.5, "show_startup_menu": true }
  },
  "input": {
    "key_bindings": {
      "play_pause": "KEY_SPACE",
      "toggle_menu": "KEY_M",
      "next_parameter": "KEY_RIGHT"
    }
  }
}
```

### Accessing Configuration

```gdscript
# Get configuration values
var volume = ConfigManager.get_config_value("audio.volume", 0.8)
var shader = ConfigManager.get_config_value("visual.default_shader", "kaldao")

# Set configuration values
ConfigManager.set_config_value("audio.volume", 0.9)
ConfigManager.set_config_value("ui.timeline.height", 80)

# Save user configuration
ConfigManager.save_user_config()

# Load user configuration
ConfigManager.load_user_config()
```

### Configuration Categories

#### App Settings
- Window properties (title, fullscreen, size)
- Performance settings (FPS, VSync)
- Default file paths

#### Audio Settings
- Volume and amplifiers
- Beat detection parameters
- Analysis settings (FFT size, frequency bands)

#### Visual Settings
- Default shader and palette
- Effect settings
- Rendering options

#### UI Settings
- Component positions and sizes
- Animation durations
- Menu settings

#### Input Settings
- Key bindings
- Mouse sensitivity
- Gesture recognition

---

## Component System

### Timeline Component

The timeline component provides audio scrubbing and visualization.

#### Features
- Drag-and-drop scrubbing
- Checkpoint markers
- Time display
- Progress visualization

#### Configuration
```json
{
  "ui": {
    "timeline": {
      "height": 60,
      "margin": 20,
      "show_time_markers": true,
      "time_marker_interval": 10.0,
      "colors": {
        "background": [0.1, 0.1, 0.1, 0.8],
        "progress": [0.502, 0.0, 0.502, 1.0],
        "playhead": [1.0, 1.0, 1.0, 1.0]
      }
    }
  }
}
```

#### Usage
```gdscript
var timeline = TimelineComponent.new()
add_child(timeline)
timeline.initialize()

# Connect to events
timeline.seek_requested.connect(_on_seek_requested)
timeline.play_pause_requested.connect(_on_play_pause_requested)

func _on_seek_requested(timestamp: float):
    var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
    audio_manager.seek_to_position(timestamp)
```

### Parameter Display Component

Shows parameter values with animations and validation feedback.

#### Display Modes
- **Overlay**: Centered overlay
- **Sidebar**: Fixed sidebar
- **Bottom Bar**: Bottom status bar
- **Floating**: Floating window
- **Minimal**: Text-only display

#### Configuration
```json
{
  "ui": {
    "parameter_display": {
      "position": "center",
      "show_duration": 3.0,
      "fade_duration": 1.0,
      "show_progress_bar": true,
      "show_validation": true
    }
  }
}
```

#### Usage
```gdscript
var param_display = ParameterDisplayComponent.new()
add_child(param_display)
param_display.initialize()

# Show parameter
param_display.show_parameter("zoom_level", 1.5)

# Set display mode
param_display.set_display_mode(ParameterDisplayComponent.DisplayMode.SIDEBAR)
```

### Audio Visualizer Component

Real-time audio visualization with multiple modes.

#### Visualization Modes
- **Spectrum**: Frequency spectrum bars
- **Waveform**: Audio waveform
- **Circular**: Circular spectrum
- **Bars**: Traditional bar graph
- **Particles**: Particle effects
- **Minimal**: Simple level indicator

#### Configuration
```json
{
  "ui": {
    "audio_visualizer": {
      "mode": "spectrum",
      "update_rate": 60.0,
      "smoothing_factor": 0.8,
      "show_beat_flash": true,
      "spectrum": {
        "bar_count": 64,
        "logarithmic_scale": true,
        "frequency_range": [20.0, 20000.0]
      }
    }
  }
}
```

#### Usage
```gdscript
var visualizer = AudioVisualizerComponent.new()
add_child(visualizer)
visualizer.initialize()

# Change visualization mode
visualizer.set_visualization_mode(AudioVisualizerComponent.VisualizationMode.CIRCULAR)

# Toggle visualizer
visualizer.toggle_visualizer()
```

---

## Advanced Features

### Custom Event Handling

Create custom event handlers for specific needs:

```gdscript
class_name CustomEventHandler
extends RefCounted

func _init():
    # Connect to multiple events
    EventBus.connect_to_beat_detected(_on_beat_detected)
    EventBus.connect_to_parameter_changed(_on_parameter_changed)
    EventBus.connect_to_audio_spectrum_updated(_on_spectrum_updated)

func _on_beat_detected(intensity: float):
    if intensity > 0.8:
        # Trigger special effect for strong beats
        trigger_beat_effect()

func _on_parameter_changed(param_name: String, value: float):
    # Custom parameter handling
    match param_name:
        "custom_effect":
            apply_custom_effect(value)

func _on_spectrum_updated(spectrum: PackedFloat32Array):
    # Custom spectrum analysis
    analyze_custom_frequencies(spectrum)
```

### Performance Optimization

#### Configuration for Performance
```json
{
  "app": {
    "performance": {
      "target_fps": 60,
      "adaptive_quality": true,
      "low_power_mode": false
    }
  },
  "audio": {
    "analysis": {
      "fft_size": 1024,
      "update_frequency": 30.0
    }
  },
  "ui": {
    "audio_visualizer": {
      "performance": {
        "max_fps": 60.0,
        "adaptive_quality": true
      }
    }
  }
}
```

#### Performance Monitoring
```gdscript
func _ready():
    # Monitor performance
    var timer = Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(_check_performance)
    add_child(timer)
    timer.start()

func _check_performance():
    var fps = Engine.get_frames_per_second()
    var memory = OS.get_static_memory_usage_by_type()
    
    if fps < 30:
        # Reduce quality
        reduce_visualization_quality()
    
    print("FPS: %d, Memory: %d" % [fps, memory])
```

### Custom Shaders

Add your own shaders to the system:

1. Create your shader file in the `shaders/` directory
2. Add shader configuration:

```json
{
  "visual": {
    "shaders": {
      "my_custom_shader": {
        "file_path": "res://shaders/my_shader.gdshader",
        "parameter_mappings": {
          "my_param": "shader_uniform_name"
        },
        "supports_color_palette": true
      }
    }
  }
}
```

3. Register the shader:

```gdscript
var shader_manager = ServiceLocator.get_service(ServiceLocator.SHADER_MANAGER)
shader_manager.register_shader("my_custom_shader")
```

### Plugin System

Create plugins for extended functionality:

```gdscript
class_name KaldaoPlugin
extends RefCounted

var plugin_name: String = "MyPlugin"
var plugin_version: String = "1.0.0"

func initialize() -> bool:
    # Plugin initialization
    print("Initializing plugin: " + plugin_name)
    
    # Register custom parameters
    register_custom_parameters()
    
    # Connect to events
    setup_event_connections()
    
    return true

func register_custom_parameters():
    var param_manager = ServiceLocator.get_service(ServiceLocator.PARAMETER_MANAGER)
    
    var custom_param = ParameterData.create_parameter(
        "plugin_effect",
        0.0, 1.0, 0.5,
        "plugin"
    )
    
    param_manager.add_parameter(custom_param)

func setup_event_connections():
    EventBus.connect_to_parameter_changed(_on_parameter_changed)

func _on_parameter_changed(param_name: String, value: float):
    if param_name == "plugin_effect":
        apply_plugin_effect(value)

func apply_plugin_effect(value: float):
    # Custom effect implementation
    pass
```

---

## Troubleshooting

### Common Issues

#### 1. Audio Not Loading
**Problem**: Audio files won't load or play
**Solutions**:
- Check file format (OGG, WAV, MP3 supported)
- Verify file path in configuration
- Check console for error messages
- Ensure audio files are imported correctly in Godot

#### 2. Shaders Not Working
**Problem**: Visual effects not displaying
**Solutions**:
- Check shader file paths in configuration
- Verify graphics card supports required shader features
- Check console for shader compilation errors
- Try different shader modes

#### 3. Parameters Not Updating
**Problem**: Parameter changes don't affect visuals
**Solutions**:
- Verify parameter mappings in configuration
- Check EventBus connections
- Ensure managers are properly initialized
- Check parameter validation constraints

#### 4. Performance Issues
**Problem**: Low frame rate or stuttering
**Solutions**:
- Reduce FFT size in audio analysis
- Lower visualization update rate
- Enable adaptive quality
- Reduce number of spectrum bars

#### 5. Configuration Not Loading
**Problem**: Settings not being applied
**Solutions**:
- Check JSON syntax in configuration files
- Verify file paths and permissions
- Check console for configuration errors
- Reset to default configuration

### Debug Information

Enable debug output for troubleshooting:

```gdscript
# Enable debug mode in configuration
ConfigManager.set_config_value("app.debug_mode", true)

# Get system information
var app_info = get_application_info()
print("Application Info: ", app_info)

var audio_info = audio_manager.get_audio_info()
print("Audio Info: ", audio_info)

var param_info = param_manager.get_parameter_info("zoom_level")
print("Parameter Info: ", param_info)
```

### Log Files

Check log files for detailed error information:
- Godot console output
- User directory: `user://kaldao_debug.log`
- System logs in OS-specific locations

### Performance Profiling

Use Godot's built-in profiler:
1. Run project in debug mode
2. Open Godot debugger
3. Enable profiler
4. Monitor CPU, memory, and rendering performance

---

## Migration from Old System

### Compatibility

The refactored system maintains backward compatibility for:
- Audio files
- Basic shader files
- Parameter concepts

### Migration Steps

#### 1. Backup Current Project
```bash
# Create backup of current project
cp -r old_kaldao_project kaldao_backup
```

#### 2. Copy Refactored System
```bash
# Copy refactored files to project
cp -r REFACTOR/* your_project/
```

#### 3. Update Configuration
Convert old settings to new configuration format:

**Old System** (hardcoded values):
```gdscript
var volume = 0.8
var beat_sensitivity = 0.7
```

**New System** (configuration):
```json
{
  "audio": {
    "volume": 0.8,
    "beat_detection": {
      "sensitivity": 0.7
    }
  }
}
```

#### 4. Update Parameter Definitions
Convert old parameter dictionaries to ParameterData:

**Old System**:
```gdscript
var parameters = {
    "zoom": {"min": 0.1, "max": 5.0, "default": 1.0}
}
```

**New System**:
```gdscript
var zoom_param = ParameterData.create_parameter("zoom", 0.1, 5.0, 1.0)
param_manager.add_parameter(zoom_param)
```

#### 5. Update Event Handling
Replace direct signal connections with EventBus:

**Old System**:
```gdscript
audio_manager.connect("beat_detected", _on_beat_detected)
```

**New System**:
```gdscript
EventBus.connect_to_beat_detected(_on_beat_detected)
```

#### 6. Test Migration
1. Run the refactored system
2. Load your audio files
3. Test parameter changes
4. Verify visual effects work
5. Check performance

### Migration Checklist

- [ ] Backup original project
- [ ] Copy refactored files
- [ ] Create configuration file
- [ ] Convert parameter definitions
- [ ] Update event handling
- [ ] Test audio loading
- [ ] Test parameter system
- [ ] Test visual effects
- [ ] Verify performance
- [ ] Update documentation

---

## Conclusion

The refactored Kaldao system provides a robust, extensible foundation for audio visualization. With its modular architecture, configuration-driven approach, and comprehensive component system, you can create stunning audio-reactive visuals while maintaining clean, maintainable code.

For additional help:
- Check the [API Reference](API_REFERENCE.md) for detailed technical documentation
- Review example projects in the `examples/` directory
- Join the community forums for support and tips
- Report issues on the project repository

Happy visualizing!
