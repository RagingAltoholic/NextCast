# Changelog

All notable changes to NextCast will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Improved Assisted Combat Detection**
  - Upgraded from child frame [14] polling to modern event-driven architecture
  - Primary method: C_AssistedCombat API (`GetAssistedHighlightSpellIDs`)
  - Secondary method: SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events for proc detection
  - Added EventRegistry callbacks for AssistedCombatManager state changes
  - Retained child frame [14] as fallback for compatibility
  - More responsive and accurate spell detection with better performance

## [1.0.0] - 2026-01-28

### 🎉 Initial Release - MVP

This is the first stable release of NextCast (formerly NextKey during development).

### Added
- **Core Functionality**
  - Assisted Combat spell detection using ActionButton child frame [14]
  - 50x50px floating button with spell icon, keybind, and cooldown display
  - Real-time cooldown tracking with swipe animation and countdown text
  - Automatic keybind detection and formatting (removes hyphens, uppercase)
  
- **User Interface**
  - Clean button design with black border and semi-transparent background
  - Outline text for keybind and cooldown (improved readability)
  - Yellow selection border in Edit Mode
  - Test mode with question mark icon for configuration preview
  
- **Configuration**
  - InterfaceOptions panel with live preview
  - Edit Mode integration with click-to-configure dialog
  - Settings sync between both panels
  - Drag-and-drop positioning via Edit Mode
  - BOTTOMLEFT anchor prevents position drift when scaling
  
- **Settings Options**
  - Enable/disable toggle
  - Show out of combat toggle
  - Show/hide cooldown swipe animation
  - Show/hide cooldown text
  - Show/hide keybind text
  - Scale adjustment (0.5x to 2.0x)
  - Opacity adjustment (20% to 100%)
  - Cooldown font size (10-32px)
  - Keybind font size (8-20px)
  - Cooldown warning system (customizable threshold 1-5 seconds)
  - Color pickers for cooldown text, keybind text, and warning text
  
- **Edit Mode Integration**
  - Full Blizzard Edit Mode support
  - Movable button with grid snapping
  - Auto-lock on Edit Mode exit
  - Auto-unlock on Edit Mode entry
  - Settings dialog opens on click (only when Edit Mode active)
  - Dismiss frame for click-outside-to-close behavior
  
- **Detection & Tracking**
  - Scans StanceBar first (priority for shapeshifters/stance classes)
  - Scans Action Bars 1-8
  - Filters to spell actions only (ignores items, macros, potions)
  - Update frequency: 0.1 seconds (10 FPS)
  
- **Slash Commands**
  - `/nextcast` or `/nextcast help` - Show command list
  - `/nextcast config` - Open settings
  - `/nextcast on/off` - Toggle addon
  - `/nextcast combat` - Toggle show out of combat
  - `/nextcast resetpos` - Reset position
  - `/nextcast debug` - Toggle debug mode
  - `/nextcast inspect` - Debug: list glowing buttons
  - `/nextcast check <ButtonName>` - Debug: inspect specific button
  
- **Quality of Life**
  - Settings persist across sessions (SavedVariables)
  - Button clamped to screen (can't be lost off-screen)
  - Automatic position correction if button is off-screen
  - Reset position button in settings
  - Preview frame in Options panel shows real-time changes

### Technical Details
- **Modules:** Core, UI, Tracker, Settings, EditMode
- **Save Variable:** NextCastDB
- **Interface Version:** 120000, 120001 (WoW Retail 11.0.0+)
- **Dependencies:** None (OptionalDeps: Blizzard_Settings)
- **Architecture:** Modular design with clean separation of concerns

### Known Limitations
- Only detects Blizzard's Assisted Combat highlight (child frame [14])
- Requires "Assisted Combat" or "Single Button Rotation" enabled in game settings
- Does not track player-initiated spell suggestions (not a rotation helper)

### Development Notes
- Renamed from "NextKey" to "NextCast" before release
- Extensive testing on scaling behavior and position anchoring
- Click vs drag detection refined through multiple iterations
- Edit Mode integration follows Blizzard's addon patterns

---

**Full Changelog:** Initial release

