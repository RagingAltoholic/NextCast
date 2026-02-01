local _, NextCast = ...

local Tracker = {}
NextCast:NewModule("Tracker", Tracker)
-- Cache for C_AssistedCombat API result to prevent excessive calls
local cachedRecommendedSpell = nil
local lastApiCallTime = 0
local API_CACHE_DURATION = 0.5  -- Cache API result for 500ms (reduce spam)

-- Track glowing spells for fallback detection (procs, ConsolePort, etc.)
local glowingSpells = {}

-- Track last found spell to reduce spam
local lastFoundSpell = nil
local lastFoundTime = 0

-- Hold last displayed spell briefly to prevent flicker
local lastDisplaySpellId = nil
local lastDisplayActionId = nil
local lastDisplayTexture = nil
local lastDisplayKeybind = nil
local lastDisplayTime = 0
local DISPLAY_HOLD_DURATION = 1.5  -- Hold for 1.5s to handle ConsolePort update cycles


local function FormatTime(seconds)
    if seconds <= 0 then return "" end
    if seconds < 10 then
        return string.format("%.1f", seconds)
    elseif seconds < 60 then
        return string.format("%d", seconds)
    elseif seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60 + 0.5))
    else
        return string.format("%dh", math.floor(seconds / 3600 + 0.5))
    end
end

local MODIFIER_TOKENS = {
    SHIFT = true,
    CTRL = true,
    LCTRL = true,
    RCTRL = true,
    ALT = true,
    LALT = true,
    RALT = true,
    CMD = true,
    META = true,
    LMETA = true,
    RMETA = true,
    WIN = true,
    LWIN = true,
    RWIN = true,
}

local function IsModifierToken(token)
    return MODIFIER_TOKENS[token] == true
end

local function FormatKeybind(keybind)
    if not keybind then return "" end

    local text = tostring(keybind)
    local upper = string.upper(text)

    -- Abbreviate modifier keys: LCTRL/RCTRL -> C, LSHIFT/RSHIFT -> S, LALT/RALT -> A, etc.
    -- Example: LCTRL-1 -> C1, RSHIFT-2 -> S2, LALT-F1 -> AF1
    local abbreviated = upper
    abbreviated = abbreviated:gsub("LCTRL%-", "C-"):gsub("RCTRL%-", "C-"):gsub("CTRL%-", "C-")
    abbreviated = abbreviated:gsub("LSHIFT%-", "S-"):gsub("RSHIFT%-", "S-"):gsub("SHIFT%-", "S-")
    abbreviated = abbreviated:gsub("LALT%-", "A-"):gsub("RALT%-", "A-"):gsub("ALT%-", "A-")
    abbreviated = abbreviated:gsub("LMETA%-", "M-"):gsub("RMETA%-", "M-"):gsub("META%-", "M-")
    abbreviated = abbreviated:gsub("LWIN%-", "M-"):gsub("RWIN%-", "M-"):gsub("WIN%-", "M-")
    abbreviated = abbreviated:gsub("CMD%-", "C-")

    -- Now remove all remaining hyphens
    local result = abbreviated:gsub("%-", "")
    return result
end

local function GetActionId(button)
    -- Try standard action button methods first
    if button.action then return button.action end
    if button.GetPagedID then
        local id = button:GetPagedID()
        if id and id > 0 then return id end
    end
    local attr = button:GetAttribute("action")
    if attr and attr > 0 then return attr end
    
    -- For stance/shapeshift buttons and other special buttons, try to get spell ID directly
    if button.GetAttribute then
        local spellID = button:GetAttribute("spell")
        if spellID and spellID > 0 then
            -- Return nil for actionId, spellID as second return
            return nil, spellID
        end
    end
    
    return nil
end

local function BuildButtonList()
    local bars = {
        { name = "StanceBar", buttonPrefix = "StanceButton", bindingPrefix = "SHAPESHIFTBUTTON", count = _G.NUM_SHAPESHIFT_SLOTS or 10 },
        { name = "PossessBar", buttonPrefix = "PossessButton", bindingPrefix = "POSSESSBUTTON", count = _G.NUM_POSSESS_SLOTS or 2 },
        { name = "ActionBar1", buttonPrefix = "ActionButton", bindingPrefix = "ACTIONBUTTON", count = 12 },
        { name = "ActionBar2", buttonPrefix = "MultiBarBottomLeftButton", bindingPrefix = "MULTIACTIONBAR1BUTTON", count = 12 },
        { name = "ActionBar3", buttonPrefix = "MultiBarBottomRightButton", bindingPrefix = "MULTIACTIONBAR2BUTTON", count = 12 },
        { name = "ActionBar4", buttonPrefix = "MultiBarRightButton", bindingPrefix = "MULTIACTIONBAR3BUTTON", count = 12 },
        { name = "ActionBar5", buttonPrefix = "MultiBarLeftButton", bindingPrefix = "MULTIACTIONBAR4BUTTON", count = 12 },
        { name = "ActionBar6", buttonPrefix = "MultiBar5Button", bindingPrefix = "MULTIACTIONBAR5BUTTON", count = 12 },
        { name = "ActionBar7", buttonPrefix = "MultiBar6Button", bindingPrefix = "MULTIACTIONBAR6BUTTON", count = 12 },
        { name = "ActionBar8", buttonPrefix = "MultiBar7Button", bindingPrefix = "MULTIACTIONBAR7BUTTON", count = 12 },
    }

    local list = {}

    local function AddButtonsFromPrefix(prefix, bindingPrefix, maxCount)
        local foundCount = 0
        for i = 1, (maxCount or 12) do
            local name = prefix .. i
            local button = _G[name]
            if button then
                list[#list + 1] = {
                    button = button,
                    binding = bindingPrefix and (bindingPrefix .. i) or nil,
                }
                foundCount = foundCount + 1
            end
        end
        return foundCount
    end

    for _, bar in ipairs(bars) do
        AddButtonsFromPrefix(bar.buttonPrefix, bar.bindingPrefix, bar.count)
    end

    return list
end

function Tracker:Initialize()
    if self.frame then return end

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    self.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self.frame:RegisterEvent("UPDATE_BINDINGS")
    self.frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    
    -- Register SPELL_ACTIVATION_OVERLAY_GLOW events for better proc detection
    self.frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    self.frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    
    self.frame:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)

    -- Register EventRegistry callbacks for AssistedCombatManager (if available)
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

    self.buttons = BuildButtonList()
    
    self.lastUpdate = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate >= 0.2 then  -- Reduced from 0.15 to 0.2 (5 FPS instead of 6.67 FPS)
            self.lastUpdate = 0
            self:Update()
        end
    end)

    self:Update()
end

function Tracker:OnEvent(event, ...)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellId = ...
        if spellId then
            glowingSpells[spellId] = true
            self:Update()
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellId = ...
        if spellId then
            glowingSpells[spellId] = nil
            self:Update()
        end
    end
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
end

function Tracker:Update()
    local ui = NextCast:GetModule("UI")
    if not ui or not ui.frame then return end

    local db = NextCast:GetModule("Core").db
    if not db or not db.enabled then
        ui:SetVisible(false)
        return
    end

    local showRecommendation = InCombatLockdown() or db.showOutOfCombat or IsDungeonOrRaid()

    -- Always detect spells, just control visibility
    -- Get the recommended spell from C_AssistedCombat API
    -- Cache result to avoid excessive API calls that cause latency
    local recommendedSpellId = nil
    local currentTime = GetTime()
    local usingFallback = false
    
    if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        -- Use cached result if recent (within 500ms)
        if cachedRecommendedSpell and (currentTime - lastApiCallTime) < API_CACHE_DURATION then
            recommendedSpellId = cachedRecommendedSpell
        else
            -- Call API and cache result
            local success, result = pcall(C_AssistedCombat.GetNextCastSpell, true)
            if success and result and type(result) == "number" and result > 0 then
                recommendedSpellId = result
                cachedRecommendedSpell = result
                lastApiCallTime = currentTime
                lastFoundSpell = recommendedSpellId
                lastFoundTime = currentTime
            else
                cachedRecommendedSpell = nil
                lastApiCallTime = currentTime
            end
        end
    end
    
    -- Fallback: If Assisted Combat API returns nothing, check for glowing spells only
    if not recommendedSpellId and next(glowingSpells) then
        for _, entry in ipairs(self.buttons) do
            local button = entry.button
            if button then
                local actionId, directSpellId = GetActionId(button)
                -- Check regular action buttons for glowing spells
                if actionId then
                    local actionType, spellId = GetActionInfo(actionId)
                    if actionType == "spell" and spellId and glowingSpells[spellId] then
                        recommendedSpellId = spellId
                        usingFallback = true
                        break
                    end
                end
                -- Also check stance buttons for glowing spells
                if not actionId and directSpellId and glowingSpells[directSpellId] then
                    recommendedSpellId = directSpellId
                    usingFallback = true
                    break
                end
            end
        end
    end

    local texture, keybind = nil, nil
    local cooldownStart, cooldownDuration, cooldownEnabled

    -- If we have a recommended spell, find it on our action bars
    if recommendedSpellId then
        for _, entry in ipairs(self.buttons) do
            local button = entry.button
            if button then  -- Removed IsShown() check - bars can be hidden but still have keybinds
                local actionId, directSpellId = GetActionId(button)
                
                -- Handle stance buttons that return spell IDs directly
                if not actionId and directSpellId then
                    if directSpellId == recommendedSpellId then
                        if C_Spell and C_Spell.GetSpellTexture then
                            texture = C_Spell.GetSpellTexture(directSpellId)
                        elseif GetSpellTexture then
                            texture = GetSpellTexture(directSpellId)
                        end
                        
                        -- Get keybind
                        local bindingKey = entry.binding and GetBindingKey(entry.binding)
                        if bindingKey then
                            keybind = FormatKeybind(GetBindingText(bindingKey))
                        end
                        
                        -- Cache display info
                        lastDisplaySpellId = directSpellId
                        lastDisplayActionId = nil  -- No action ID for stance buttons
                        lastDisplayTexture = texture
                        lastDisplayKeybind = keybind
                        lastDisplayTime = currentTime
                        break
                    end
                end
                
                if actionId then
                    local actionType, spellId = GetActionInfo(actionId)
                    -- Only show spells, not items/macros/potions
                    if actionType == "spell" and spellId and spellId == recommendedSpellId then
                        if C_Spell and C_Spell.GetSpellTexture then
                            texture = C_Spell.GetSpellTexture(spellId)
                        elseif GetSpellTexture then
                            texture = GetSpellTexture(spellId)
                        end

                        -- Get keybind from binding
                        local bindingKey = entry.binding and GetBindingKey(entry.binding)
                        if bindingKey then
                            keybind = FormatKeybind(GetBindingText(bindingKey))
                        end

                        -- Fallback to button's hotkey text
                        if (not keybind or keybind == "") and button.HotKey then
                            local hotkeyText = button.HotKey:GetText()
                            if hotkeyText and hotkeyText ~= "" and hotkeyText ~= "RANGE_INDICATOR" then
                                keybind = hotkeyText
                            end
                        end

                        if actionId then
                            cooldownStart, cooldownDuration, cooldownEnabled = GetActionCooldown(actionId)
                        elseif button and button.cooldown and button.cooldown.GetCooldownTimes then
                            local startMS, durationMS = button.cooldown:GetCooldownTimes()
                            if startMS and durationMS then
                                cooldownStart = startMS / 1000
                                cooldownDuration = durationMS / 1000
                                cooldownEnabled = 1
                            end
                        end
                        -- Cache display info to prevent flicker
                        lastDisplaySpellId = spellId
                        lastDisplayActionId = actionId
                        lastDisplayTexture = texture
                        lastDisplayKeybind = keybind
                        lastDisplayTime = currentTime
                        break
                    end
                end
            end
        end
    end

    -- If still no texture and we have a recommended spell from the API,
    -- display it directly (trust the API - it's validated as appropriate)
    -- This handles stances, procs, and other spells not on action bars
    if not texture and recommendedSpellId then
        -- Get texture from spell
        if C_Spell and C_Spell.GetSpellTexture then
            texture = C_Spell.GetSpellTexture(recommendedSpellId)
        elseif GetSpellTexture then
            texture = GetSpellTexture(recommendedSpellId)
        end
    end

    -- If nothing found this frame, keep last display briefly to avoid flicker
    if not texture and lastDisplaySpellId and (currentTime - lastDisplayTime) <= DISPLAY_HOLD_DURATION then
        texture = lastDisplayTexture
        keybind = lastDisplayKeybind
        if lastDisplayActionId then
            cooldownStart, cooldownDuration, cooldownEnabled = GetActionCooldown(lastDisplayActionId)
        end
    elseif not texture and lastDisplaySpellId then
        -- Hold buffer expired, clear the cache
        lastDisplaySpellId = nil
        lastDisplayActionId = nil
        lastDisplayTexture = nil
        lastDisplayKeybind = nil
    end

    -- Always update spell display (even out of combat)
    ui:SetSpell(texture, keybind)
    ui:SetCooldown(cooldownStart or 0, cooldownDuration or 0, cooldownEnabled == 1)

    if cooldownStart and cooldownDuration and cooldownEnabled == 1 then
        local remaining = (cooldownStart + cooldownDuration) - GetTime()
        ui:SetCooldownText(FormatTime(remaining), remaining)
    else
        ui:SetCooldownText("")
    end

    -- Control visibility based on combat/settings
    if ui.isUnlocked then
        ui:SetVisible(true)
    else
        ui:SetVisible(showRecommendation)
    end
end
