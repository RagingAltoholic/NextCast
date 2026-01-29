# NextCast

**Version:** 1.0.0  
**Author:** RagingAltoholic  
**Category:** HUD

## Description

NextCast is a World of Warcraft addon that displays Blizzard's recommended spell as a clean, movable floating button. It detects the blue "Assisted Combat" highlight that Blizzard shows on your action bars and displays that spell in an easy-to-see location.

## Features

- **Assisted Combat Integration** - Automatically detects which spell Blizzard recommends you cast next
- **Floating Button Display** - Clean 50x50px button showing the spell icon, keybind, and cooldown
- **Fully Customizable** - Adjust scale, opacity, font sizes, and colors to match your UI
- **Edit Mode Support** - Drag and position the button using WoW's built-in Edit Mode (ESC → Edit Mode)
- **Cooldown Warning** - Optionally changes text color when cooldown is under a threshold you set
- **Combat Toggle** - Choose whether to show the button out of combat
- **Persistent Settings** - Your preferences are saved between sessions

## Installation

1. Download the addon
2. Extract the `NextCast` folder to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)
4. Type `/nextcast config` to open settings

## Usage

### Positioning the Button

1. Press `ESC` and click **Edit Mode**
2. Click the NextCast button to open positioning settings
3. Drag the button to your desired location
4. Click **Exit Edit Mode** when done

### Configuration

Open the settings panel in three ways:
- **Editmode:** Press `ESC` → Editmode
- **In-Game:** Press `ESC` → Options → AddOns → NextCast
- **Command:** `/nextcast config`

Available settings:
- Enable/disable addon
- Show out of combat
- Show/hide cooldown swipe animation
- Show/hide cooldown text
- Show/hide keybind text
- Scale (0.5x to 2.0x)
- Opacity (20% to 100%)
- Cooldown font size (10-32)
- Keybind font size (8-20)
- Cooldown warning (enable/disable and set threshold)
- Text colors (cooldown, keybind, warning)

### Slash Commands

- `/nextcast` or `/nextcast help` - Show help
- `/nextcast config` - Open settings panel
- `/nextcast on` - Enable addon
- `/nextcast off` - Disable addon
- `/nextcast combat` - Toggle show out of combat
- `/nextcast resetpos` - Reset button position to default
- `/nextcast debug` - Toggle debug mode
- `/nextcast inspect` - Show buttons with Assisted Combat highlights (debug)
- `/nextcast check <ButtonName>` - Inspect specific action button (debug)

## How It Works

NextCast scans your action bars (Stance Bar prioritized, then Action Bars 1-8) looking for Blizzard's blue "Assisted Combat" highlight. When found, it:
1. Extracts the spell icon and keybind
2. Displays them in the floating button
3. Shows the cooldown with a visual swipe and countdown text
4. Optionally warns you when the cooldown is almost ready

The addon only tracks **spell** actions - items, macros, and potions are ignored.

## Technical Details

- **Detection Method:** Uses multiple robust methods for detecting Assisted Combat:
  1. **Primary:** C_AssistedCombat API (`GetAssistedHighlightSpellIDs`)
  2. **Secondary:** SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events
  3. **EventRegistry:** AssistedCombatManager callbacks for real-time updates
  4. **Fallback:** ActionButton child frame [14] (legacy compatibility)
- **Position Anchor:** BOTTOMLEFT (prevents button from shifting when scaled)
- **Save Variable:** `NextCastDB` (stored in `WTF\Account\<Account>\SavedVariables\`)
- **Modules:** Core, UI, Tracker, Settings, EditMode

## Troubleshooting

**Q: The button doesn't show any spell**  
A: Ensure "Assisted Combat" or "Single Button Rotation" is enabled in Blizzard's Interface Options.

**Q: The button won't move**  
A: Make sure you're in Edit Mode (ESC → Edit Mode). The button can only be moved while Edit Mode is active.

**Q: Settings won't open**  
A: Try `/reload` to restart the UI. If the problem persists, check for conflicting addons.

**Q: Cooldown text is cut off**  
A: Increase the cooldown font size in settings, or increase the button scale.

## Support

For bugs, feature requests, or questions:
- [(Open an issue on GitHub)](https://github.com/RagingAltoholic/NextCast/issues)

## Credits

- **Author:** RagingAltoholic
- **Inspired by:** Blizzard's Assisted Combat system
- **Special Thanks:** To the WoW addon development community

## License

This addon is provided as-is with no warranty. Feel free to modify for personal use.

---

**Enjoy using NextCast!**  
May your rotation be smooth and your DPS be high!
