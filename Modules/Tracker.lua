local _, NextCast = ...

local Tracker = {}
NextCast:NewModule("Tracker", Tracker)

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

local function FormatKeybind(keybind)
    if not keybind then return "" end
    -- Remove hyphens from modifiers and uppercase: S-1 -> S1, C-A -> CA, etc.
    return string.upper(keybind:gsub("%-", ""))
end

local function IsButtonGlowing(button)
    if not button then return false end
    
    -- Check for Assisted Combat / Single Button Rotation highlight (child [14])
    local children = {button:GetChildren()}
    if children[14] and children[14]:IsShown() then
        return true
    end
    
    return false
end

local function GetActionId(button)
    if button.action then return button.action end
    if button.GetPagedID then
        local id = button:GetPagedID()
        if id and id > 0 then return id end
    end
    local attr = button:GetAttribute("action")
    if attr and attr > 0 then return attr end
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
    for _, bar in ipairs(bars) do
        for i = 1, (bar.count or 12) do
            local name = bar.buttonPrefix .. i
            local button = _G[name]
            if button then
                list[#list + 1] = {
                    button = button,
                    binding = bar.bindingPrefix .. i,
                }
            end
        end
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
    self.frame:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)

    self.buttons = BuildButtonList()
    self.lastUpdate = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate >= 0.15 then
            self.lastUpdate = 0
            self:Update()
        end
    end)

    self:Update()
end

function Tracker:OnEvent(event, ...)
    self:Update()
end

local function IsDungeonOrRaid()
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

    if ui.isUnlocked then
        ui:SetVisible(true)
    else
        ui:SetVisible(showRecommendation)
    end

    if not showRecommendation then
        ui:SetSpell(nil, nil)
        ui:SetCooldown(0, 0, false)
        ui:SetCooldownText("")
        return
    end

    local texture, keybind = nil, nil
    local cooldownStart, cooldownDuration, cooldownEnabled

    for _, entry in ipairs(self.buttons) do
        local button = entry.button
        local isGlowing = IsButtonGlowing(button)
        if button and button:IsShown() and isGlowing then
            local actionId = GetActionId(button)
            if actionId then
                local actionType, id = GetActionInfo(actionId)
                -- Only show spells, not items/macros/potions
                if actionType == "spell" and id then
                    if C_Spell and C_Spell.GetSpellTexture then
                        texture = C_Spell.GetSpellTexture(id)
                    elseif GetSpellTexture then
                        texture = GetSpellTexture(id)
                    end

                    local bindingKey = GetBindingKey(entry.binding)
                    if bindingKey then
                        keybind = FormatKeybind(GetBindingText(bindingKey, "KEY_", 1))
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
                    break
                end
            end
        end
    end

    ui:SetSpell(texture, keybind)
    ui:SetCooldown(cooldownStart or 0, cooldownDuration or 0, cooldownEnabled == 1)

    if cooldownStart and cooldownDuration and cooldownEnabled == 1 then
        local remaining = (cooldownStart + cooldownDuration) - GetTime()
        ui:SetCooldownText(FormatTime(remaining), remaining)
    else
        ui:SetCooldownText("")
    end
end
