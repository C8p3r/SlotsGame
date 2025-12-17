# SlotsGame Project Structure

## Overview
The project has been reorganized into logical system folders to improve maintainability and reduce file clutter.

## Directory Structure

```
SlotsGame/
├── conf.lua                          # Configuration (colors, dimensions, etc.)
├── main.lua                          # Game loop and state management
├── splashfont.otf                    # Font asset
├── 
├── assets/                           # Image and sprite assets
│   ├── default_lootbox.aseprite
│   ├── UI_assets.aseprite
│   ├── upgrade_units_UI.aseprite
│   └── keepsakes/
│
├── shaders/                          # GLSL shader files
│   ├── background_shader.glsl
│   ├── flame_shader.glsl
│   ├── greyscale_shader.glsl
│   ├── invert_rgb_shader.glsl
│   ├── neon_glow_shader.glsl
│   └── pixelate_shader.glsl
│
├── game_mechanics/                   # Slot machine & interaction logic
│   ├── slot_machine.lua              # Main slot machine state & logic
│   ├── slot_logic.lua                # Win checking & payout logic
│   ├── slot_update.lua               # State updates & animations
│   ├── slot_draw.lua                 # Slot rendering & text effects
│   ├── slot_QTE.lua                  # Quick-time event system
│   ├── slot_borders.lua              # Border rendering
│   └── lever.lua                     # Lever interaction & particles
│
├── systems/                          # Core game systems
│   ├── upgrade_node.lua              # Upgrade definitions & selection
│   ├── difficulty.lua                # Difficulty scaling
│   ├── keepsakes.lua                 # Keepsake effects
│   ├── background_renderer.lua       # Background & visual effects
│   ├── base_flame.lua                # Flame effect system
│   ├── particle_system.lua           # Particle effects
│   └── slot_smoke.lua                # Smoke effects
│
├── ui/                               # Core UI system
│   ├── ui.lua                        # Main UI drawing & management
│   ├── ui_config.lua                 # UI configuration & constants
│   ├── shop.lua                      # Shop menu & upgrade selection
│   ├── buttons.lua                   # Button rendering & interaction
│   ├── display_boxes.lua             # Display box rendering
│   ├── settings.lua                  # Settings menu
│   └── failstate.lua                 # Failure screen
│
├── ui_screens/                       # Individual screen/feature UIs
│   ├── start_screen.lua              # Game start screen
│   ├── home_menu.lua                 # Main menu
│   ├── dialogue.lua                  # Dialogue system
│   └── keepsake_splashs.lua          # Keepsake activation effects
│
└── .git/                             # Git repository
```

## Key Changes

### Files Moved to `game_mechanics/`
- `slot_logic.lua` - Slot winning logic
- `slot_machine.lua` - Core slot machine
- `slot_update.lua` - Animation & state updates
- `slot_draw.lua` - Rendering
- `slot_QTE.lua` - Quick-time events
- `slot_borders.lua` - Border graphics
- `lever.lua` - Lever interaction

### Files Moved to `systems/`
- `upgrade_node.lua` - Upgrade system
- `keepsakes.lua` - Keepsake modifiers
- `difficulty.lua` - Difficulty settings
- `background_renderer.lua` - Background effects
- `base_flame.lua` - Flame effects
- `particle_system.lua` - Particle effects
- `slot_smoke.lua` - Smoke effects

### Files Moved to `ui_screens/`
- `start_screen.lua` - Game start UI
- `home_menu.lua` - Main menu
- `dialogue.lua` - Dialogue display
- `keepsake_splashs.lua` - Effect triggers

### Files Staying in `ui/`
- `ui.lua` - Core UI system
- `ui_config.lua` - UI configuration
- `shop.lua` - Shop interface
- `buttons.lua` - Button system
- `display_boxes.lua` - Display rendering
- `settings.lua` - Settings menu
- `failstate.lua` - Failure UI

### Files Staying at Root
- `conf.lua` - Configuration
- `main.lua` - Game loop & state management

## Dependency Resolution

All `require()` statements have been updated to use the new folder paths:

- Game mechanics: `require("game_mechanics/slot_machine")`
- Systems: `require("systems/upgrade_node")`
- UI screens: `require("ui_screens/start_screen")`
- UI: `require("ui/shop")`
- Root/Config: `require("conf")`

## Benefits

1. **Better Organization** - Related files grouped by system
2. **Reduced Clutter** - Root directory now only has config and game loop
3. **Easier Navigation** - Clear separation of concerns
4. **Maintainability** - Easier to locate and modify specific systems
5. **Scalability** - Easier to add new features to existing systems
