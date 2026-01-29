# Assisted Combat Detection Implementation

## Overview

This document explains NextCast's Assisted Combat detection mechanism using official Blizzard APIs.

## Problem Statement

The original implementation relied on polling ActionButton child frame [14] to detect Blizzard's Assisted Combat highlight:

```lua
-- Old approach (fragile)
local children = {button:GetChildren()}
if children[14] and children[14]:IsShown() then
    return true
end
```

**Issues with this approach:**
- **Fragility**: Frame indices can change between WoW patches, breaking the addon
- **Performance**: Constant polling and frame enumeration is inefficient
- **Accuracy**: Unreliable detection
- **Maintenance**: No official documentation; relies on reverse engineering

## Current Solution

The implementation uses the **official C_AssistedCombat API**:

### C_AssistedCombat.GetNextCastSpell(checkForVisibleButton)

```lua
-- Get the recommended spell from C_AssistedCombat API
local recommendedSpellId = nil
if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
    local success, result = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if success and result and type(result) == "number" and result > 0 then
        recommendedSpellId = result
    end
end
```

**Parameters:**
- `checkForVisibleButton` (boolean): When `true`, only returns spell if it has a visible action button

**Benefits:**
- ✅ Official Blizzard API (WoW 11.0+)
- ✅ Direct access to the game's internal rotation logic
- ✅ No reverse engineering required
- ✅ Future-proof against UI changes
- ✅ Simple, single-source detection

## EventRegistry Callbacks

To receive real-time updates when Blizzard's rotation changes:

```lua
if EventRegistry then
    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", function()
        self:Update()
    end, self)
    EventRegistry:RegisterCallback("AssistedCombatManager.RotationSpellsUpdated", function()
        self:Update()
    end, self)
    EventRegistry:RegisterCallback("AssistedCombatManager.OnSetActionSpell", function()
        self:Update()
    end, self)
end
```

**Benefits:**
- ✅ Real-time updates when Blizzard's rotation logic changes
- ✅ Synchronizes with the game's internal state instantly
- ✅ Minimal latency between recommendation and display

## Performance

- ✅ Event-driven updates via EventRegistry callbacks
- ✅ O(1) spell lookup complexity
- ✅ Near-instant response time

## Compatibility

- **WoW Retail 11.0+**: Full support with C_AssistedCombat API
- **Earlier versions**: Not supported (requires Assisted Combat system)

## Testing Recommendations

1. **Enable Assisted Combat** in WoW:
   - Open Edit Mode (ESC → Edit Mode)
   - Enable "Assisted Combat" or "Single Button Rotation"
   - Ensure `assistedMode` CVar is enabled: `/console assistedMode 1`

2. **Test detection**:
   - Enter combat and observe spell recommendations
   - Verify NextCast displays the highlighted spell
   - Enable debug mode: `/nextcast debug`
   - Monitor chat for spell ID detection

3. **Verify API availability**:
   - Test that `C_AssistedCombat.GetNextCastSpell()` returns spell IDs
   - Ensure addon doesn't error if API is unavailable

## References

- [World of Warcraft API Documentation](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [C_AssistedCombat API](https://warcraft.wiki.gg/wiki/API_C_AssistedCombat)
- [JustAC Addon](https://github.com/wealdly/JustAC) - Reference implementation
- [Wowhead Combat Assistant Guide](https://www.wowhead.com/guide/ui/combat-assistant-one-button-rotation-tool-setup)

## Summary

NextCast uses the official `C_AssistedCombat.GetNextCastSpell()` API to detect Blizzard's spell recommendations. This provides a simple, reliable, single-source detection method that is future-proof against WoW UI changes.

**Key Benefits:**
- ✅ Official Blizzard API (no reverse engineering)
- ✅ Simple and maintainable
- ✅ Future-proof against UI changes
- ✅ Event-driven for instant updates
- ✅ Follows community best practices

## Summary

The improvements transform NextCast from a fragile, polling-based addon into a robust, event-driven system that leverages official Blizzard APIs. The multi-layered approach ensures compatibility across WoW versions while providing the best possible performance and accuracy on modern clients.

**Key Benefits:**
- ✅ Future-proof against WoW UI changes
- ✅ Better performance (event-driven vs polling)
- ✅ More accurate (catches procs and state changes)
- ✅ Backwards compatible (fallback for older versions)
- ✅ Follows best practices from community addons (JustAC)

This addresses the issue raised: **Yes, there are better hooks than frame 14, and we now use them!**
