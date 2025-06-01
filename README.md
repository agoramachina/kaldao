Kaldao is a fractal animation program written in Godot, based off of doa's [Kaleidoscope Godot shader](https://godotshaders.com/shader/kaleidoscope/) which is based off of mrange's [Truchet + Kaleidoscope FTW shadertoy shader](https://www.shadertoy.com/view/7lKSWW). 

# Kaldao Project Technical Overview

## Architecture Summary

Kaldao uses a component-based architecture with signal-driven communication between modular managers. The system is built around a central fractal shader with real-time parameter control and audio reactivity.

### Core Design Principles

1. **Separation of Concerns**: Each manager handles a specific domain (audio, parameters, colors, etc.)
2. **Signal-Based Communication**: Loose coupling through Godot's signal system
3. **Real-Time Performance**: Direct GPU parameter updates without frame drops
4. **Extensibility**: New features can be added without major refactoring

## System Components

### Main Controllers
- **ControlManager.gd**: Root controller, handles input routing and UI coordination
- **CanvasManager.gd**: Fractal coordinator, manages shader material and time accumulation
- **AudioManager.gd**: Audio system coordinator with spectrum analysis

### Core Managers
- **ParameterManager.gd**: 15+ parameter definitions with bounds, steps, and descriptions
- **ColorPaletteManager.gd**: 7 color palettes plus randomization and inversion
- **ShaderController.gd**: GDScript ↔ shader interface with debug filtering
- **ScreenshotManager.gd**: Viewport capture with timestamped file saving

### UI Components
- **InputHandler.gd**: Comprehensive keyboard control mapping
- **MenuManager.gd**: Settings menu display with fade transitions
- **UIComponents.gd**: Dynamic positioning and window resize handling

### Audio System
- **AudioReactivityManager.gd**: Maps frequency analysis to visual parameters
- **SpectrumAnalyzerComponent.gd**: Real-time FFT analysis with beat detection
- **SongSettings.gd**: Music video production with checkpoint system
- **TimelineComponent.gd**: Visual timeline with scrubbing capabilities

### Debug Tools
- **ShaderDebug.gd**: Mirrors all shader variables for debugging (500+ lines)
- **ControlDebug.gd**: Debug scene controller for shader development

## Key Technical Insights

### Accumulated Time System
**Critical Pattern**: Separates speed parameters from position calculations to prevent animation jumps.

```gdscript
# CORRECT: Accumulated time approach
camera_position += fly_speed * delta
shader_material.set_shader_parameter("camera_position", camera_position)

# WRONG: Direct multiplication causes jumps
shader_material.set_shader_parameter("camera_position", TIME * fly_speed)
```

### Signal Flow Architecture
```
Input → ParameterManager → ShaderController → Shader
     ↘ ColorPaletteManager ↗
SongSettings → TimelineComponent → AudioManager
```

### Kaleidoscope Segment Protection
Special handling ensures kaleidoscope segments remain even integers (4, 6, 8, etc.) to prevent visual artifacts.

## File Organization

### Scene Hierarchy
```
Control (ControlManager.gd) - Main controller
├── ColorRect (CanvasManager.gd) - Fractal rendering surface
├── RichTextLabel - Parameter display popup
├── RichTextLabel-L - Settings menu panel  
├── RichTextLabel-R - Commands help panel
├── TimelineComponent - Music timeline scrubber
└── AudioStreamPlayer (AudioManager.gd) - Audio analysis
```

### Script Organization
```
scripts/
├── audio/           # Audio analysis and reactivity
├── canvas/          # Rendering and parameter management
├── control/         # Input handling and UI
└── components/      # Reusable system components
```

## Shader Architecture (kaldao.gdshader)

### Uniform Categories
- **Time Accumulation**: camera_position, rotation_time, plane_rotation_time, color_time
- **Speed Controls**: fly_speed, rotation_speed, plane_rotation_speed, color_speed
- **Pattern Controls**: kaleidoscope_segments, truchet_radius, zoom_level
- **Camera Controls**: camera_tilt_x/y, camera_roll, path_stability
- **Visual Effects**: contrast, color_intensity, center_fill_radius

### Rendering Pipeline
1. **Camera Path Calculation**: Curved tunnel navigation with banking
2. **Layer Rendering**: Multiple transparent layers with depth fading
3. **Kaleidoscope Transform**: Radial mirror symmetry with smoothing
4. **Truchet Patterns**: Procedural curved patterns in grid cells
5. **Color Processing**: Palette application with gamma correction

### Mathematical Foundation
- **Truchet Tiles**: Curved patterns connecting diagonal corners
- **Kaleidoscope Mathematics**: Polar coordinate folding and mirroring
- **Procedural Generation**: Hash-based randomization for pattern variation
- **Color Theory**: Mathematical palette generation using cosine curves

## Audio System Design

### Frequency Analysis
- **Bass**: 20-200 Hz → Truchet radius and color intensity
- **Mid**: 200-3000 Hz → Rotation speed modulation
- **Treble**: 3000-20000 Hz → Zoom level effects
- **Beat Detection**: Bass history analysis with configurable sensitivity

### Amplification Chain
```
Raw Audio → FFT Analysis → Frequency Isolation → Amplification → Smoothing → Parameter Mapping
```

### Music Video Production
- **Audacity Integration**: Import label tracks as checkpoints
- **Timeline Scrubbing**: Interactive seeking with visual feedback
- **Checkpoint Navigation**: Jump between song sections
- **Parameter Automation**: Smooth transitions between visual states

## Performance Considerations

### Optimization Strategies
- **Debug Output Filtering**: Prevents console spam from high-frequency updates
- **Selective Redrawing**: Timeline only redraws on significant time changes
- **Parameter Bounds Checking**: Prevents invalid shader values
- **Memory Management**: Limited audio history for beat detection

### Known Performance Issues
- Timeline positioning calculations could be optimized
- Complex kaleidoscope segments (80+) may impact framerate
- Audio analysis creates some overhead during playback

## Development Status and Refactoring Needs

### Current Code Issues
1. **Scale**: 1000+ lines across dozen files, some redundancy
2. **Hardcoded Values**: Some UI elements use magic numbers
3. **Comment Accuracy**: Development comments may be outdated
4. **Optimization**: Some kludgy solutions need refinement

### Recommended Refactoring Priority
1. **Code Audit**: Review all files for redundancy and optimization
2. **Documentation Update**: Ensure all comments reflect current implementation
3. **Magic Number Elimination**: Replace hardcoded values with constants
4. **Function Optimization**: Identify and improve inefficient algorithms
5. **Test Coverage**: Add validation for critical functions

### Debug Mode Completion
The debug system (ShaderDebug.gd + ControlDebug.gd) provides:
- Mirror of all shader variables for real-time inspection
- Simulation of shader calculations on CPU
- Direct parameter manipulation for development
- Performance profiling capabilities

## Future Architecture Considerations

### Undo/Redo System
Implement parameter history with temporary file storage:
```gdscript
# On each parameter change
save_temp_state(parameter_history)
# Ctrl+Z
restore_state(parameter_history.pop_back())
```

### Non-Destructive Audio Reactivity
Instead of overriding parameters, use multipliers:
```gdscript
final_value = base_value * audio_multiplier * user_adjustment
```

### Microphone Integration
Extend audio system to support real-time input:
- Virtual audio cable detection
- Microphone level monitoring
- Input device selection UI

## Testing and Validation

### Critical Test Cases
1. **Parameter Bounds**: Ensure all values stay within valid ranges
2. **Audio Sync**: Verify timeline accuracy with various audio formats
3. **Save/Load**: Test parameter persistence across sessions
4. **Performance**: Monitor framerate under various loads
5. **Platform Compatibility**: Test on different operating systems

### Known Edge Cases
- Timeline positioning on ultra-wide monitors
- Audio file loading with special characters in paths
- Parameter randomization with extreme values
- Color palette transitions during audio reactivity

---

This technical overview should serve as a reference for development decisions and future refactoring efforts. The modular architecture provides a solid foundation for continued enhancement while maintaining performance and extensibility.
