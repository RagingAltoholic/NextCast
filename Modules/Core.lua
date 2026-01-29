local addonName, NextCast = ...

local Core = {}
NextCast:NewModule("Core", Core)

local defaults = {
    enabled = true,
    showOutOfCombat = false,
    showCooldownSwipe = true,
    showCooldownText = true,
    showKeybind = true,
    scale = 1.0,
    alpha = 1.0,
    cdWarningThreshold = 3,
    cdWarningColor = { r = 1.0, g = 0.0, b = 0.0 },
    cdFontSize = 18,
    cdFontColor = { r = 1.0, g = 0.95, b = 0.6 },
    keybindFontSize = 12,
    keybindFontColor = { r = 1.0, g = 1.0, b = 1.0 },
    position = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 400, y = 300 },
    trackAssistedCombat = true,
    trackOverlay = true,
    trackProcs = false,
    debugMode = false,
    locked = true,
    cdWarningEnabled = true,
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function Core:InitializeDB()
    NextCastDB = CopyDefaults(defaults, NextCastDB or {})
    self.db = NextCastDB
end

function Core:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:InitializeDB()
        end
    elseif event == "PLAYER_LOGIN" then
        local ui = NextCast:GetModule("UI")
        if ui and ui.Initialize then ui:Initialize() end
        local tracker = NextCast:GetModule("Tracker")
        if tracker and tracker.Initialize then tracker:Initialize() end
        local settings = NextCast:GetModule("Settings")
        if settings and settings.Initialize then settings:Initialize() end
        local editMode = NextCast:GetModule("EditMode")
        if editMode and editMode.Initialize then editMode:Initialize() end
    end
end

function Core:Initialize()
    if self.frame then return end
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("PLAYER_LOGIN")
end

Core:Initialize()
