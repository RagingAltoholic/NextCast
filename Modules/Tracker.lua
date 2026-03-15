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
local GCD_SPELL_ID = 61304

local SELF_BUFF_SPELLS_BY_CLASS = {
    DRUID = { 1126 },       -- Mark of the Wild
    MAGE = { 1459 },        -- Arcane Intellect
    PRIEST = { 21562 },     -- Power Word: Fortitude
    WARRIOR = { 6673 },     -- Battle Shout
    EVOKER = { 364342 },    -- Blessing of the Bronze
    SHAMAN = { 462854 },    -- Skyfury
    PALADIN = { 433568, 433583 }, -- Lightsmith: Rite of Sanctification / Rite of Adjuration
}

local PALADIN_RITE_SPELLS = {
    [433568] = true,
    [433583] = true,
}

local function IsDungeonOrRaid()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
end

local function IsSpellKnownForPlayer(spellId)
    if not spellId then return false end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellId)
    end

    if IsPlayerSpell then
        return IsPlayerSpell(spellId)
    end

    if IsSpellKnown then
        return IsSpellKnown(spellId)
    end

    return false
end

local function GetSpellNameCompat(spellId)
    if not spellId then
        return nil
    end

    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end

    if GetSpellInfo then
        return GetSpellInfo(spellId)
    end

    return nil
end

local function GetPlayerBuffState(spellId)
    if not spellId then return false, nil end

    local spellName = GetSpellNameCompat(spellId)

    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local auraInfo = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if auraInfo then
            return true, auraInfo.expirationTime
        end
    end

    -- Fallback for buffs where cast spell ID and applied aura ID differ.
    if spellName and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local auraInfo = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not auraInfo then break end
            if auraInfo.name == spellName then
                return true, auraInfo.expirationTime
            end
        end
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local ok, aura = pcall(AuraUtil.FindAuraBySpellID, spellId, "player", "HELPFUL")
        if ok and aura then
            if type(aura) == "table" then
                return true, aura.expirationTime
            end
            local okLegacy, _, _, _, _, _, expirationTime = pcall(AuraUtil.FindAuraBySpellID, spellId, "player", "HELPFUL")
            if okLegacy then
                return true, expirationTime
            end
        end
    end

    if spellName and AuraUtil and AuraUtil.FindAuraByName then
        local ok, aura = pcall(AuraUtil.FindAuraByName, spellName, "player", "HELPFUL")
        if ok and aura then
            if type(aura) == "table" then
                return true, aura.expirationTime
            end
            local okLegacy, _, _, _, _, _, expirationTime = pcall(AuraUtil.FindAuraByName, spellName, "player", "HELPFUL")
            if okLegacy then
                return true, expirationTime
            end
        end
    end

    if UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, expirationTime, _, _, _, auraSpellId = UnitBuff("player", i)
            if not name then break end
            if auraSpellId == spellId or (spellName and name == spellName) then
                return true, expirationTime
            end
        end
    end

    return false, nil
end

local function HasActiveWeaponEnchant()
    if not GetWeaponEnchantInfo then
        return false
    end

    local hasMainHandEnchant, mainHandExpiration, _, hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
    if hasMainHandEnchant and mainHandExpiration and mainHandExpiration > 0 then
        return true
    end
    if hasOffHandEnchant and offHandExpiration and offHandExpiration > 0 then
        return true
    end

    return false
end

local function GetSelfBuffReminderSpellId(db, currentTime)
    if not db or not db.selfBuffReminderEnabled then
        return nil
    end

    if InCombatLockdown() and not db.selfBuffReminderInCombat then
        return nil
    end

    local _, classTag = UnitClass("player")
    local classBuffs = classTag and SELF_BUFF_SPELLS_BY_CLASS[classTag]
    if not classBuffs then
        return nil
    end

    local threshold = db.selfBuffReminderThreshold or 30

    for _, spellId in ipairs(classBuffs) do
        if IsSpellKnownForPlayer(spellId) then
            local hasBuff, expirationTime = GetPlayerBuffState(spellId)

            if not hasBuff and classTag == "PALADIN" and PALADIN_RITE_SPELLS[spellId] and HasActiveWeaponEnchant() then
                hasBuff = true
                expirationTime = nil
            end

            if not hasBuff then
                return spellId
            end

            if expirationTime and expirationTime > 0 and (expirationTime - currentTime) <= threshold then
                return spellId
            end
        end
    end

    return nil
end

local function GetGCDCooldownCompat()
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if type(info) == "table" then
            local startTime = info.startTime
            local duration = info.duration
            if (startTime == nil or duration == nil) and info.timeUntilEndOfStartRecovery then
                startTime = GetTime()
                duration = info.timeUntilEndOfStartRecovery
            end
            if startTime == nil then startTime = 0 end
            if duration == nil then duration = 0 end
            return startTime, duration, 1
        end
    end

    if GetSpellCooldown then
        local startTime, duration = GetSpellCooldown(GCD_SPELL_ID)
        if startTime == nil then startTime = 0 end
        if duration == nil then duration = 0 end
        return startTime, duration, 1
    end

    return 0, 0, 0
end

local function GetCastOrChannelCooldownCompat()
    if UnitChannelInfo then
        local _, _, _, startMS, endMS = UnitChannelInfo("player")
        if startMS and endMS and endMS > startMS then
            local startTime = startMS / 1000
            local duration = (endMS - startMS) / 1000
            if duration > 0 then
                return startTime, duration, 1
            end
        end
    end

    if UnitCastingInfo then
        local _, _, _, startMS, endMS = UnitCastingInfo("player")
        if startMS and endMS and endMS > startMS then
            local startTime = startMS / 1000
            local duration = (endMS - startMS) / 1000
            if duration > 0 then
                return startTime, duration, 1
            end
        end
    end

    return nil, nil, 0
end

local function GetSpellCooldownCompat(spellId)
    if not spellId then
        return 0, 0, 0
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellId)
        if type(info) == "table" then
            local startTime = info.startTime
            local duration = info.duration
            if (startTime == nil or duration == nil) and info.timeUntilEndOfStartRecovery then
                startTime = GetTime()
                duration = info.timeUntilEndOfStartRecovery
            end
            if (startTime == nil or duration == nil) and info.isOnGCD then
                return GetGCDCooldownCompat()
            end
            if startTime == nil then startTime = 0 end
            if duration == nil then duration = 0 end
            return startTime, duration, 1
        end
    end

    if GetSpellCooldown then
        local startTime, duration = GetSpellCooldown(spellId)
        if startTime == nil then startTime = 0 end
        if duration == nil then duration = 0 end
        return startTime, duration, 1
    end

    return 0, 0, 0
end


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

local function TryCalculateRemaining(startTime, duration, currentTime)
    local ok, remaining = pcall(function()
        return (startTime + duration) - currentTime
    end)

    if ok and type(remaining) == "number" then
        return remaining
    end

    return nil
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
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellId = ...
        if spellId then
            glowingSpells[spellId] = nil
        end
    end

    self:Update()
end

function Tracker:Update()
    local ui = NextCast:GetModule("UI")
    if not ui or not ui.frame then return end

    local db = NextCast:GetModule("Core").db
    if not db or not db.enabled then
        ui:SetVisible(false)
        return
    end

    -- Check hide conditions
    local shouldHide = false
    
    if db.hideWhenMounted and IsMounted() then
        shouldHide = true
    end
    
    if db.hideWhenInVehicle and (UnitInVehicle("player") or UnitHasVehicleUI("player")) then
        shouldHide = true
    end
    
    if db.hideWhenPossessed and (UnitIsCharmed("player") or (HasPossessBar and HasPossessBar())) then
        shouldHide = true
    end
    
    if shouldHide then
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

    local buffReminderSpellId = GetSelfBuffReminderSpellId(db, currentTime)
    if buffReminderSpellId then
        recommendedSpellId = buffReminderSpellId
        usingFallback = true
        showRecommendation = true
    end

    if not recommendedSpellId and C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
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
                        cooldownStart, cooldownDuration, cooldownEnabled = GetSpellCooldownCompat(directSpellId)
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

                        cooldownStart, cooldownDuration, cooldownEnabled = GetSpellCooldownCompat(spellId)
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

        cooldownStart, cooldownDuration, cooldownEnabled = GetSpellCooldownCompat(recommendedSpellId)
    end

    -- If nothing found this frame, keep last display briefly to avoid flicker
    if not texture and lastDisplaySpellId and (currentTime - lastDisplayTime) <= DISPLAY_HOLD_DURATION then
        texture = lastDisplayTexture
        keybind = lastDisplayKeybind
        if lastDisplaySpellId then
            cooldownStart, cooldownDuration, cooldownEnabled = GetSpellCooldownCompat(lastDisplaySpellId)
        else
            cooldownStart, cooldownDuration, cooldownEnabled = 0, 0, 0
        end
    elseif not texture and lastDisplaySpellId then
        -- Hold buffer expired, clear the cache
        lastDisplaySpellId = nil
        lastDisplayActionId = nil
        lastDisplayTexture = nil
        lastDisplayKeybind = nil
    end

    -- Always update spell display (even out of combat)
    local currentRemaining = nil
    if cooldownEnabled == 1 and cooldownStart and cooldownDuration then
        currentRemaining = TryCalculateRemaining(cooldownStart, cooldownDuration, GetTime())
    end

    if (not currentRemaining or currentRemaining <= 0) then
        local castStart, castDuration, castEnabled = GetCastOrChannelCooldownCompat()
        if castEnabled == 1 then
            cooldownStart, cooldownDuration, cooldownEnabled = castStart, castDuration, castEnabled
        end
    end

    ui:SetSpell(texture, keybind)
    ui:SetCooldown(cooldownStart or 0, cooldownDuration or 0, cooldownEnabled == 1)

    if cooldownStart and cooldownDuration and cooldownEnabled == 1 then
        local remaining = TryCalculateRemaining(cooldownStart, cooldownDuration, GetTime())
        if remaining then
            ui:SetCooldownText(FormatTime(remaining), remaining)
        else
            ui:SetCooldownText("")
        end
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
