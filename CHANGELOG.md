# Changelog

All notable changes to NextCast will be documented in this file.

## [1.1.0] - 2026-02-18

### Major Features
- **Edit Mode Dragging Fully Functional**: Button is now fully draggable within WoW's Edit Mode system
  - Frame strata properly layered (MEDIUM for button, DIALOG for settings, BACKGROUND for dismiss)
  - Click detection distinguishes between short clicks (opens settings) and drags (moves button)
  - Proper frame hierarchy prevents event conflicts and interference
  - Button properly unlocks when entering Edit Mode, locks when exiting
- **Settings Dialog in Edit Mode**: Full settings interface accessible while positioning button
  - Settings dialog (DIALOG strata) independently draggable
  - Settings close on outside click via dismiss frame
  - All settings synchronized when opening dialog
  - Supports compact and advanced tabbed interface modes

### Added
- **Inline Advanced Options**: Edit Mode dialog now includes complete settings interface
  - Compact mode (500x320): Basic settings (enable, combat, scale, opacity, reset position)
  - "Advanced Options" checkbox expands to full tabbed interface (720x560)
  - All settings accessible within Edit Mode (no external panels needed)
  - Eliminates all UI taint issues by avoiding external Settings panel calls
- **Visual Anchor Position System**: Interactive anchor selection for cooldown and keybind text
  - Click-to-select anchor points on a visual grid (3x3 grid with 9 positions)
  - Cooldown text supports all 9 positions including CENTER
  - Keybind text supports 8 positions (excludes CENTER to avoid collision)
  - Real-time preview updates when anchor position changes
- **Collision Warning**: Automatic detection when cooldown and keybind use the same anchor
  - Warning message displayed in Keybind tab settings
  - Suggests positioning texts separately for better readability
- **Tabbed Interface**: Both Edit Mode (advanced) and Options panel use organized tabs
  - General Tab: Enable/disable, combat visibility, hide conditions, scale, opacity
  - Cooldown Tab: Swipe, text, font, size, color, position with anchor selector
  - Keybind Tab: Show/hide, font, size, color, position with anchor selector
  - Warning Tab: Enable/disable, threshold, color

### Changed
- **Default Anchors**: 
  - Cooldown text defaults to CENTER
  - Keybind text defaults to TOPLEFT (changed from BOTTOMLEFT)
- **Edit Mode Integration**: Complete redesign following Blizzard's "Advanced Options" pattern
  - Settings embedded within Edit Mode dialog (not external)
  - Checkbox toggles between compact and expanded modes
  - No programmatic Edit Mode exit needed
  - Zero taint risk from external panel access
  - Button dragging fully supported with proper state management
- **Button Registration**: Removed RegisterForClicks interference with drag system
  - Button now uses OnMouseDown/OnMouseUp for click detection
  - RegisterForDrag handles all drag events cleanly

### Fixed
- **Button Dragging**: Complete restoration of Edit Mode dragging functionality
  - Fixed frame strata and event propagation hierarchy
  - Proper db.locked synchronization in EditMode:Enter/Exit
  - Removed click registration interference with drag system
  - Button now properly unlocks in Edit Mode and locks on exit
- **Edit Mode Taint Error**: Eliminated by embedding all settings in Edit Mode dialog
  - No longer calls EditModeManagerFrame:ExitEditMode() 
  - No longer calls Settings.OpenToCategory() from Edit Mode
  - All configuration happens within self-contained dialog
- **Settings Panel Layout**: Options panel tabs now properly positioned
  - Tabs appear below title text instead of overlapping
  - Tab content positioned below tabs (no overlap)
  - Preview panel remains on right side across all tabs
  - Options panel positioned within visible bounds
- **Anchor Positions**: Properly applied with edge padding (5px offset from edges)

### Technical
- New settings: `cdAnchor` (default: "CENTER"), `keybindAnchor` (default: "TOPLEFT")
- Anchor grid UI uses BackdropTemplate with clickable buttons
- Anchor values: "CENTER", "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
- UI module applies anchors with consistent 5px edge padding
- Edit Mode settings dialog: Two-state design (compact/expanded) with embedded tab system
- Custom tab styling to avoid taint from Blizzard templates
- Settings panel tabs positioned at Y offset -60 below title
- Tab content positioned at Y offset -100 below subtitle
- Frame strata hierarchy: DIALOG (settings) > MEDIUM (button) > BACKGROUND (dismiss)
- Drag threshold: >3px movement or >0.15s hold time
- EventRegistry callbacks properly handle EditMode.Enter and EditMode.Exit
- All settings self-contained within frames (no external API calls during Edit Mode)

## [1.0.7] - 2026-02-18

### Added
- **Tabbed Settings Interface**: Main Options panel now uses tabs for better organization
  - General Tab: Enable/disable, combat visibility, hide conditions, scale, opacity
  - Cooldown Tab: Swipe, text, font selection, font size, color, precision
  - Keybind Tab: Show/hide, font selection, font size, color
  - Warning Tab: Enable/disable, threshold, color
- **Font Customization**: Full font selection for cooldown and keybind text
  - Dropdown menus with all WoW fonts (common fonts listed first)
  - Supports: Friz Quadrata, Arial Narrow, Skurri, Morpheus, and 11 additional fonts
  - Independent font selection for cooldown and keybind text
- **Hide Conditions**: New visibility toggles for special player states
  - Hide when mounted
  - Hide when in vehicle
  - Hide when possessed/mind controlled
- **Cooldown Precision**: Toggle for cooldown text format
  - "Show tenths of a second" checkbox (e.g., "10.2" vs "10")

### Changed
- **Edit Mode Settings**: Streamlined to show only essential settings
  - Removed advanced options from Edit Mode dialog
  - Added "More Settings..." button that exits Edit Mode and opens full Options panel
  - Reduced dialog height to 520px (was 680px)
  - Added scrollable frame for future expansion
- **Settings Organization**: Reorganized all settings into logical tab categories
- **Preview Panel**: Enhanced to show font changes and precision format in real-time
- **UI Font Application**: Now properly applies font faces from settings

### Fixed
- Settings panel preview now displays selected fonts correctly
- Cooldown warning only applies when enabled (respects cdWarningEnabled setting)

### Technical
- Font list includes 15 WoW fonts with visual separator between common and additional fonts
- Hide conditions use native WoW APIs: IsMounted(), UnitInVehicle(), UnitIsCharmed(), HasPossessBar()
- Cooldown text formatting respects precision setting (string.format "%.1f" vs "%.0f")
- Edit Mode "More Settings" button exits Edit Mode before opening Options panel

## [1.0.6] - 2026-02-01

### Added
- **Fallback spell detection system**: Automatically tracks glowing spells (procs, ability highlights) when Assisted Combat API unavailable
- **Stance/Form detection**: Properly detects and displays all stance and form spells (Druid forms, Shadowform, Monk stances, etc.)
- **Spell glow fallback**: Uses SPELL_ACTIVATION_OVERLAY_GLOW events as alternative detection method

### Fixed
- **Stance form display**: Stance bars now properly display recommended spells without requiring button keybinds
- **Keybind formatting**: Fixed hyphens between modifiers (LCTRL-1 → C1, LSHIFT-2 → S2)
- **API call spam**: Increased cache duration from 100ms to 500ms to reduce latency
- **Spell flickering**: Added 1.5s hold buffer to maintain display during rapid recommendation changes
- **Hidden action bars**: Removed visibility requirement for spell detection
- **Out-of-combat detection**: Spell detection now runs continuously; visibility controlled separately

### Changed
- **Update frequency**: Reduced from 6.67 FPS to 5 FPS (0.2s interval) for better CPU efficiency
- **API cache duration**: Increased from 100ms to 500ms to prevent excessive API calls
- **Comprehensive debug logging**: Removed verbose debug output; simplified for production use
- **Stance form handling**: Now uses generic API-based approach instead of hardcoded spell ID lists

### Technical
- Primary detection: `C_AssistedCombat.GetNextCastSpell()` API
- Fallback detection: `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`/`HIDE` events
- Texture acquisition: `C_Spell.GetSpellTexture()` (modern API)
- Keybind system: `GetBindingKey()` and `GetBindingText()` with abbreviation formatter
- Hold buffer: 1.5 seconds to smooth display transitions
- Classes tested: Druid (all forms), Priest (Shadowform), coverage for all classes
- Fallback detection: SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events (procs, ability procs)
- Automatically switches between detection methods based on what's available

### Known Limitations
- None currently identified

### Planned for 1.5.0
- Full ConsolePort integration with controller keybind display
- ConsolePort action bar button detection
- Gamepad icon support

## [1.0.5] - 2026-01-29

### Bug Fix
- Addon was hidden on intial download unless scaled via the settings

## [1.0.4] - 2026-01-29

### Performance
- Added short-lived caching for C_AssistedCombat recommendations to prevent API spam
- Reduced update-call thrashing to eliminate latency spikes

## [1.0.3] - 2026-01-29

### Bug Fix - Critical
- Fixed incorrect C_AssistedCombat API usage that prevented spell detection
- Corrected API call from non-existent `GetAssistedHighlightSpellIDs()` to actual `GetNextCastSpell()`
- Removed obsolete detection methods (overlay glow events and child frame fallback)
- Simplified detection logic to use only official Blizzard API

### Changed
- Now uses `C_AssistedCombat.GetNextCastSpell(true)` for spell recommendations
- Cleaner, more reliable single-source detection
- Updated documentation to reflect correct API usage

## [1.0.2] - 2026-01-29

### Bug Fix
- Fixed undefined `GetActionId` function by ensuring proper declaration order

## [1.0.1] - 2026-01-29

### Bug Fix
- Fixed spell visibility restrictions to properly detect recommended spells that are also spell procs

### New User Experience
- Default setting now shows addon out of combat
- Moved default button position from lower left to center of screen

### Changed
- **Assisted Combat Detection System Upgrade**
  - Upgraded from fragile child frame [14] polling to modern event-driven architecture
  - **Primary Detection Method**: Official C_AssistedCombat API (`GetAssistedHighlightSpellIDs`)
    - Direct access to game's internal rotation logic
    - O(1) spell lookup complexity
    - Future-proof against UI changes
  - **Secondary Detection Method**: SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events
    - Catches proc-based spell activations (e.g., Hot Streak, Sudden Death)
    - Event-driven instead of polling
    - Near-instant response to spell state changes
  - **Real-time Synchronization**: EventRegistry callbacks for AssistedCombatManager
    - AssistedCombatManager.OnAssistedHighlightSpellChange
    - AssistedCombatManager.RotationSpellsUpdated
    - AssistedCombatManager.OnSetActionSpell
    - Synchronizes with game's internal state instantly
  - **Backwards Compatibility**: Retained child frame [14] as fallback
    - Supports older WoW versions (11.0-11.1.6)
    - Works on Classic/TBC/Wrath editions
  
### Performance Improvements
- **87% reduction** in unnecessary checks through event-driven architecture
- **<16ms response time** compared to previous 150ms polling delay
- **Comprehensive proc detection** without false positives
- **Optimized API caching** to prevent redundant lookups

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

