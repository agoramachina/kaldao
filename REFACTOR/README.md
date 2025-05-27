# Kaldao Refactored Architecture

This is a complete refactoring of the Kaldao audio-reactive visual application with a clean, modular architecture.

## Architecture Overview

### Core Principles
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Dependency Injection**: Services managed through ServiceLocator
- **Event-Driven**: Decoupled communication via EventBus
- **Configuration-Driven**: All settings externalized and configurable
- **Component-Based**: Reusable, testable components

### Folder Structure

```
REFACTOR/
├── scenes/                     # Godot scene files (.tscn)
│   ├── main/                   # Main application scenes
│   ├── components/             # Reusable UI components
│   └── resources/              # Custom resource scenes
├── scripts/                    # All GDScript files
│   ├── core/                   # Core architecture (ServiceLocator, EventBus, etc.)
│   ├── managers/               # Business logic managers
│   ├── components/             # UI and functional components
│   ├── data/                   # Data models and structures
│   └── utils/                  # Utility functions and helpers
├── resources/                  # Custom Godot resources (.tres)
│   ├── audio/                  # Audio-related resources
│   ├── visual/                 # Visual/shader resources
│   └── config/                 # Configuration resources
└── config/                     # JSON configuration files
```

## Key Components

### Core Architecture
- **ServiceLocator**: Centralized dependency injection
- **EventBus**: Global event communication system
- **ConfigManager**: Configuration management with JSON persistence
- **ApplicationBootstrap**: Proper initialization sequence

### Managers (Business Logic)
- **AudioManager**: Audio playback and analysis
- **ParameterManager**: Visual parameter management
- **ColorPaletteManager**: Color palette system
- **ShaderManager**: Shader parameter control
- **ScreenshotManager**: Screenshot functionality
- **TimelineManager**: Audio timeline and scrubbing

### Components (UI & Functional)
- **TimelineComponent**: Audio timeline scrubber (as Godot scene)
- **MenuComponent**: Settings and help menus
- **ParameterDisplayComponent**: Parameter value display
- **AudioVisualizerComponent**: Audio level visualization

### Data Models
- **ParameterData**: Parameter definitions and constraints
- **AudioSettings**: Audio configuration data
- **VisualSettings**: Visual effect settings
- **SongData**: Song metadata and checkpoints

## Migration Strategy

1. **Phase 1**: Set up core architecture (ServiceLocator, EventBus, ConfigManager)
2. **Phase 2**: Create new managers with clean interfaces
3. **Phase 3**: Build reusable components as Godot scenes
4. **Phase 4**: Create main application scene using new components
5. **Phase 5**: Migrate existing functionality to new architecture
6. **Phase 6**: Testing and optimization

## Benefits of Refactored Architecture

- **Maintainability**: Clear separation makes code easier to understand and modify
- **Testability**: Decoupled components can be tested independently
- **Reusability**: Components can be reused across different scenes
- **Extensibility**: Easy to add new features without breaking existing code
- **Performance**: Better resource management and initialization order
- **Configuration**: All settings externalized for easy tweaking
