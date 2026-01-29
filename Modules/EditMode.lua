--[[
==================================================================================
NextCast - Edit Mode Module
==================================================================================
Handles integration with Blizzard's Edit Mode system.

This module provides:
- Settings dialog window (opened by clicking button in Edit Mode)
- All configuration options (mirrors Options panel)
- Auto-lock/unlock behavior when entering/exiting Edit Mode
- Active state tracking

The settings dialog is movable and shows:
- Enable/disable toggle
- Combat visibility
- Cooldown display options  
- Scale and opacity sliders
- Font size sliders
- Warning threshold settings
- Color pickers
- Reset position button

Edit Mode behavior:
- Entering Edit Mode: unlocks button, shows selection border
- Clicking button: opens settings dialog
- Exiting Edit Mode: locks button, hides selection border, closes dialog
==================================================================================
--]]

local _, NextCast = ...

local EditMode = {}
NextCast:NewModule("EditMode", EditMode)

------------------------------------------------------------
-- Edit Mode State
------------------------------------------------------------
-- Tracks whether Edit Mode is currently active
-- Used by UI module to determine click behavior
EditMode.active = false

------------------------------------------------------------
-- Color Picker Helper
------------------------------------------------------------

--[[
    OpenColorPicker(initial, callback)
    
    Opens Blizzard's color picker dialog.
    
    Parameters:
        initial (table): { r, g, b } - Starting color values (0-1 range)
        callback (function): Called with new color table when changed
    
    The color picker provides:
    - Visual color selector
    - RGB adjustment
    - Cancel button (restores previous color)
    - Immediate feedback as user drags
--]]
local function OpenColorPicker(initial, callback)
    local r, g, b = initial.r, initial.g, initial.b

    local function onColorChange()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        callback({ r = nr, g = ng, b = nb })
    end

    local function onCancel(prev)
        if prev then
            callback({ r = prev.r, g = prev.g, b = prev.b })
        end
    end

    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { r = r, g = g, b = b }
    ColorPickerFrame.func = onColorChange
    ColorPickerFrame.cancelFunc = onCancel

    if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker then
        ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
    end

    ColorPickerFrame:Show()
end

------------------------------------------------------------
-- Settings Window Construction
------------------------------------------------------------

--[[
    CreateEditModeSettings()
    
    Builds the settings dialog window shown in Edit Mode.
    
    This creates a movable 330x680px dialog with:
    - Title and category labels
    - 6 checkboxes (enable, combat, swipe, text, keybind, warning)
    - 6 sliders (scale, opacity, cd font, kb font, warning threshold)
    - 3 color pickers (cd color, kb color, warning color)
    - Reset position button
    
    All settings immediately apply when changed.
    Settings are stored in checkboxList, sliderList, and colorList
    for syncing when dialog opens.
    
    Returns:
        settings (Frame): The constructed settings dialog
--]]
local function CreateEditModeSettings()
    local db = NextCast:GetModule("Core").db
    local ui = NextCast:GetModule("UI")

    -- Main dialog frame (BackdropTemplate for border/background)
    local settings = CreateFrame("Frame", "NextCastEditModeSettings", UIParent, "BackdropTemplate")
    settings:SetSize(330, 680)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")  -- Above game UI
    settings:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    settings:SetBackdropColor(0.5, 0.5, 0.5, 0.95)  -- Dark gray, mostly opaque
    settings:Hide()
    settings:EnableMouse(true)  -- Block clicks from passing through
    settings:SetMovable(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)

    --------------------------------------------------------
    -- Title + Category Label
    --------------------------------------------------------
    local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetFont("Fonts\\FRIZQT__.TTF", 21, "OUTLINE")
    title:SetText("NextCast Settings")
    title:SetTextColor(1, 1, 1)

    local category = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    category:SetPoint("TOPLEFT", 20, -40)
    category:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    category:SetText("Category: HUD")
    category:SetTextColor(0.8, 0.9, 1)

    --------------------------------------------------------
    -- UI Element Builder Functions
    --------------------------------------------------------
    
    --[[
        CreateCheckbox(label, yOffset, getter, setter, list)
        
        Creates a checkbox control.
        
        Parameters:
            label (string): Display text
            yOffset (number): Y position from top-left
            getter (function): Returns current boolean value
            setter (function): Called with new boolean value
            list (table): Checkbox added to this array for syncing
    --]]
    local function CreateCheckbox(label, yOffset, getter, setter, list)
        local check = CreateFrame("CheckButton", nil, settings, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20, yOffset)
        check:SetScale(1.15)  -- Slightly larger for visibility
        check.Text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        check.Text:SetText(label)
        check.Text:SetTextColor(1, 1, 1)
        check.getter = getter  -- Store for later syncing
        check:SetChecked(getter())
        check:SetScript("OnClick", function(self)
            setter(self:GetChecked())
        end)
        list[#list + 1] = check
        return check
    end

    --[[
        CreateSlider(label, yOffset, min, max, step, getter, setter, list)
        
        Creates a slider control with label and value display.
        
        Parameters:
            label (string): Display text above slider
            yOffset (number): Y position from top-left
            min, max (number): Range limits
            step (number): Increment per notch
            getter (function): Returns current value
            setter (function): Called with new value
            list (table): Slider added to this array for syncing
    --]]
    local function CreateSlider(label, yOffset, min, max, step, getter, setter, list)
        local container = CreateFrame("Frame", nil, settings)
        container:SetSize(260, 60)
        container:SetPoint("TOPLEFT", 20, yOffset)

        -- Label above slider
        local sliderLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        sliderLabel:SetPoint("TOPLEFT", 0, 0)
        sliderLabel:SetText(label)
        sliderLabel:SetTextColor(1, 1, 1)

        -- Slider control
        local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 0, -25)
        slider:SetWidth(260)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetValue(getter())
        slider:SetObeyStepOnDrag(true)
        if slider.Low then slider.Low:Hide() end
        if slider.High then slider.High:Hide() end

        local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
        valueText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        valueText:SetText(string.format("%.2f", getter()))
        valueText:SetTextColor(1, 1, 1)

        slider.getter = getter
        slider:SetScript("OnValueChanged", function(self, value)
            valueText:SetText(string.format("%.2f", value))
            setter(value)
        end)

        list[#list + 1] = slider
        return container
    end

    local function CreateColorButton(label, yOffset, getter, setter, list)
        local btn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 20, yOffset)
        btn:SetSize(180, 22)
        if btn.Text then
            btn.Text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        end
        btn:SetText(label)

        local swatch = btn:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", btn, "RIGHT", 8, 0)

        local function updateSwatch()
            local c = getter()
            swatch:SetColorTexture(c.r, c.g, c.b)
        end

        btn.getter = getter
        btn.updateSwatch = updateSwatch

        btn:SetScript("OnClick", function()
            OpenColorPicker(getter(), function(color)
                setter(color)
                updateSwatch()
            end)
        end)

        updateSwatch()
        list[#list + 1] = btn
        return btn
    end

    --------------------------------------------------------
    -- Settings Layout
    --------------------------------------------------------
    local yPos = - 45

    CreateCheckbox("Enable", yPos,
        function() return db.enabled end,
        function(v) db.enabled = v; NextCast:GetModule("Tracker"):Update() end,
        EditMode.checkboxList)
    yPos = yPos - 30

    CreateCheckbox("Show out of combat", yPos,
        function() return db.showOutOfCombat end,
        function(v) db.showOutOfCombat = v; NextCast:GetModule("Tracker"):Update() end,
        EditMode.checkboxList)
    yPos = yPos - 30

    CreateCheckbox("Show cooldown swipe", yPos,
        function() return db.showCooldownSwipe end,
        function(v) db.showCooldownSwipe = v; ui:ApplySettings() end,
        EditMode.checkboxList)
    yPos = yPos - 30

    CreateCheckbox("Show cooldown text", yPos,
        function() return db.showCooldownText end,
        function(v) db.showCooldownText = v; ui:ApplySettings() end,
        EditMode.checkboxList)
    yPos = yPos - 30

    CreateCheckbox("Cooldown warning", yPos,
        function() return db.cdWarningEnabled end,
        function(v) db.cdWarningEnabled = v; ui:ApplySettings() end,
        EditMode.checkboxList)
    yPos = yPos - 30

    CreateCheckbox("Show keybind", yPos,
        function() return db.showKeybind end,
        function(v) db.showKeybind = v; ui:ApplySettings() end,
        EditMode.checkboxList)
    yPos = yPos - 50

    --------------------------------------------------------
    -- Visual / Font options
    --------------------------------------------------------
    CreateSlider("Scale", yPos, 0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) db.scale = v; ui:ApplySettings() end,
        EditMode.sliderList)
    yPos = yPos - 50

    CreateSlider("Opacity", yPos, 0.2, 1.0, 0.05,
        function() return db.alpha end,
        function(v) db.alpha = v; ui:ApplySettings() end,
        EditMode.sliderList)
    yPos = yPos - 50

    CreateSlider("Countdown font size", yPos, 10, 32, 1,
        function() return db.cdFontSize end,
        function(v) db.cdFontSize = v; ui:ApplySettings() end,
        EditMode.sliderList)
    yPos = yPos - 50

    CreateSlider("Keybind font size", yPos, 8, 20, 1,
        function() return db.keybindFontSize end,
        function(v) db.keybindFontSize = v; ui:ApplySettings() end,
        EditMode.sliderList)
    yPos = yPos - 50

    CreateSlider("Warning threshold", yPos, 1, 5, 1,
        function() return db.cdWarningThreshold end,
        function(v) db.cdWarningThreshold = v; ui:ApplySettings() end,
        EditMode.sliderList)
    yPos = yPos - 60

    --------------------------------------------------------
    -- Color options
    --------------------------------------------------------
    CreateColorButton("Countdown text color", yPos,
        function() return db.cdFontColor end,
        function(v) db.cdFontColor = v; ui:ApplySettings() end,
        EditMode.colorList)
    yPos = yPos - 40

    CreateColorButton("Keybind text color", yPos,
        function() return db.keybindFontColor end,
        function(v) db.keybindFontColor = v; ui:ApplySettings() end,
        EditMode.colorList)
    yPos = yPos - 40

    CreateColorButton("Warning text color", yPos,
        function() return db.cdWarningColor end,
        function(v) db.cdWarningColor = v; ui:ApplySettings() end,
        EditMode.colorList)
    yPos = yPos - 40

    --------------------------------------------------------
    -- Reset Button
    --------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    resetBtn:SetSize(settings:GetWidth() - 40, 24)
    resetBtn:SetPoint("BOTTOM", 0, 15)
    resetBtn:SetText("Reset position")
    if resetBtn.Text then
        resetBtn.Text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    end
    resetBtn:SetScript("OnClick", function()
        db.position = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 400, y = 300 }
        ui:ApplySettings()
    end)

    return settings
end

------------------------------------------------------------
-- Module Initialization
------------------------------------------------------------
function EditMode:Initialize()
    if self.initialized then return end
    self.initialized = true

    local ui = NextCast:GetModule("UI")
    if not ui then return end

    self.checkboxList = {}
    self.sliderList = {}
    self.colorList = {}

    self.settingsDialog = CreateEditModeSettings()
end

------------------------------------------------------------
-- Edit Mode Control
------------------------------------------------------------
function EditMode:Enter()
    if self.active then return end
    self.active = true

    local ui = NextCast:GetModule("UI")
    local db = NextCast:GetModule("Core").db

    if db then
        db.locked = false
    end

    if ui and ui.frame then
        ui:SetUnlocked(true)
        ui:SetVisible(true)
    end
end

function EditMode:Exit()
    if not self.active then return end
    self.active = false

    local ui = NextCast:GetModule("UI")
    local db = NextCast:GetModule("Core").db

    if db then
        db.locked = true
    end

    if ui and ui.frame then
        ui:SetUnlocked(false)
        ui:SetTestMode(false)
    end

    if self.settingsDialog then
        self.settingsDialog:Hide()
    end
end

function EditMode:Toggle()
    if self.active then
        self:Exit()
    else
        self:Enter()
    end
end

------------------------------------------------------------
-- Blizzard Edit Mode Integration
------------------------------------------------------------
EventRegistry:RegisterCallback("EditMode.Enter", function()
    local module = NextCast:GetModule("EditMode")
    if module then module:Enter() end
end)

EventRegistry:RegisterCallback("EditMode.Exit", function()
    local module = NextCast:GetModule("EditMode")
    if module then module:Exit() end
end)
