--[[
==================================================================================
NextCast - Edit Mode Module
==================================================================================
Handles integration with Blizzard's Edit Mode system.

This module provides:
- Compact basic settings dialog (default)
- "Advanced Options" checkbox that expands to show full tabbed interface
- All settings accessible within Edit Mode (no external panels needed)
- Auto-lock/unlock behavior when entering/exiting Edit Mode

UI States:
- Compact (500x320): Basic settings only
- Expanded (720x560): Full tabbed interface (General, Cooldown, Keybind, Warning)

This eliminates the need for external Settings panel access and prevents all taint issues.
==================================================================================
--]]

local _, NextCast = ...

local EditMode = {}
NextCast:NewModule("EditMode", EditMode)

EditMode.active = false

------------------------------------------------------------
-- WoW Font List (for dropdowns)
------------------------------------------------------------
local FONT_LIST = {
    { path = "Fonts\\FRIZQT__.TTF", name = "Friz Quadrata (Default)" },
    { path = "Fonts\\ARIALN.TTF", name = "Arial Narrow" },
    { path = "Fonts\\skurri.ttf", name = "Skurri" },
    { path = "Fonts\\MORPHEUS.TTF", name = "Morpheus" },
    { path = "separator" },
    { path = "Fonts\\FRIZQT___CYR.TTF", name = "Friz Quadrata (Cyrillic)" },
    { path = "Fonts\\ARIALN_CYR.TTF", name = "Arial Narrow (Cyrillic)" },
    { path = "Fonts\\2002.TTF", name = "2002" },
    { path = "Fonts\\2002B.TTF", name = "2002 Bold" },
    { path = "Fonts\\ARHei.ttf", name = "AR CrystalzcuheiGBK Demibold (zhCN)" },
    { path = "Fonts\\ARKai_C.ttf", name = "AR ZhongkaiGBK Medium (zhCN)" },
    { path = "Fonts\\ARKai_T.ttf", name = "AR ZhongkaiBig5 Medium (zhTW)" },
    { path = "Fonts\\bHEI00M.ttf", name = "BL ZhongHei BD (zhTW)" },
    { path = "Fonts\\bHEI01B.ttf", name = "BL ZhongHei BD (zhTW)" },
    { path = "Fonts\\K_Damage.TTF", name = "K_Damage (koKR)" },
    { path = "Fonts\\K_Pagetext.TTF", name = "K_Pagetext (koKR)" },
}

------------------------------------------------------------
-- Settings Window Construction
------------------------------------------------------------
local function CreateEditModeSettings()
    local db = NextCast:GetModule("Core").db
    local ui = NextCast:GetModule("UI")

    -- Main dialog frame
    local settings = CreateFrame("Frame", "NextCastEditModeSettings", UIParent, "BackdropTemplate")
    settings:SetSize(500, 320)  -- Compact by default
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
    -- Title (Left-justified)
    --------------------------------------------------------
    local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    title:SetText("NextCast Settings")
    title:SetTextColor(1, 1, 1)

    --------------------------------------------------------
    -- Advanced Options Checkbox (Right side, text on left)
    --------------------------------------------------------
    local advancedCheck = CreateFrame("CheckButton", nil, settings, "InterfaceOptionsCheckButtonTemplate")
    advancedCheck:SetPoint("TOPRIGHT", -20, -18)
    advancedCheck:SetScale(1.0)
    advancedCheck.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    advancedCheck.Text:SetText("Advanced Options")
    advancedCheck.Text:SetTextColor(1, 1, 1)
    advancedCheck.Text:ClearAllPoints()
    advancedCheck.Text:SetPoint("RIGHT", advancedCheck, "LEFT", 0, 0)
    advancedCheck:SetChecked(false)

    --------------------------------------------------------
    -- Basic Settings Container (compact mode)
    --------------------------------------------------------
    local basicContainer = CreateFrame("Frame", nil, settings)
    basicContainer:SetPoint("TOPLEFT", 20, -55)
    basicContainer:SetSize(460, 240)

    --------------------------------------------------------
    -- Advanced Settings Container (expanded mode with tabs)
    --------------------------------------------------------
    local advancedContainer = CreateFrame("Frame", nil, settings)
    advancedContainer:SetPoint("TOPLEFT", 20, -55)
    advancedContainer:SetSize(680, 485)
    advancedContainer:Hide()

    --------------------------------------------------------
    -- Helper Functions
    --------------------------------------------------------
    local function CreateCheckbox(parent, label, yOffset, getter, setter)
        local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 10, yOffset)
        check:SetScale(1.15)
        check.Text:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        check.Text:SetText(label)
        check.Text:SetTextColor(1, 1, 1)
        check:SetChecked(getter())
        check:SetScript("OnClick", function(self)
            setter(self:GetChecked())
        end)
        return check
    end

    local function CreateSlider(parent, label, yOffset, min, max, step, getter, setter)
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(220, 50)
        container:SetPoint("TOPLEFT", 10, yOffset)

        local sliderLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel:SetPoint("TOPLEFT", 0, 0)
        sliderLabel:SetText(label)

        local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 0, -20)
        slider:SetWidth(200)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetValue(getter())
        slider:SetObeyStepOnDrag(true)
        if slider.Low then slider.Low:Hide() end
        if slider.High then slider.High:Hide() end

        local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOM", slider, "TOP", 0, 2)
        valueText:SetText(string.format("%.2f", getter()))

        slider:SetScript("OnValueChanged", function(self, value)
            valueText:SetText(string.format("%.2f", value))
            setter(value)
        end)

        return container
    end

    local function CreateColorButton(parent, label, yOffset, getter, setter)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 16, yOffset)
        btn:SetSize(160, 22)
        btn:SetText(label)

        local swatch = btn:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", btn, "RIGHT", 8, 0)

        local function updateSwatch()
            local c = getter()
            swatch:SetColorTexture(c.r, c.g, c.b)
        end

        btn:SetScript("OnClick", function()
            local c = getter()
            local r, g, b = c.r, c.g, c.b

            local function onColorChange()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                setter({ r = nr, g = ng, b = nb })
                updateSwatch()
            end

            local function onCancel(prev)
                if prev then
                    setter({ r = prev.r, g = prev.g, b = prev.b })
                    updateSwatch()
                end
            end

            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = { r = r, g = g, b = b }
            ColorPickerFrame.func = onColorChange
            ColorPickerFrame.cancelFunc = onCancel
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end)

        updateSwatch()
        return btn
    end

    local function CreateFontDropdown(parent, label, yOffset, getter, setter)
        if not UIDropDownMenu_Initialize then
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 16, yOffset)
            container:SetSize(260, 30)
            
            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetText(label .. " (dropdown unavailable)")
            
            return container
        end

        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", 16, yOffset)
        container:SetSize(260, 40)

        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 0, 0)
        labelText:SetText(label)

        local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -15, -20)
        UIDropDownMenu_SetWidth(dropdown, 200)

        local function OnClick(self)
            setter(self.value)
            UIDropDownMenu_SetText(dropdown, self:GetText())
        end

        local function initialize(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for i, fontData in ipairs(FONT_LIST) do
                if fontData.path == "separator" then
                    info.text = "-------------------"
                    info.disabled = true
                    info.notClickable = true
                    UIDropDownMenu_AddButton(info, level)
                else
                    info.text = fontData.name
                    info.value = fontData.path
                    info.func = OnClick
                    info.disabled = false
                    info.notClickable = false
                    info.checked = (getter() == fontData.path)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end

        UIDropDownMenu_Initialize(dropdown, initialize)
        
        for i, fontData in ipairs(FONT_LIST) do
            if fontData.path == getter() then
                UIDropDownMenu_SetText(dropdown, fontData.name)
                break
            end
        end

        return dropdown
    end

    local function CreateAnchorSelector(parent, label, yOffset, getter, setter, allowCenter)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", 16, yOffset)
        container:SetSize(260, 110)

        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 0, 0)
        labelText:SetText(label)

        local anchorFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
        anchorFrame:SetPoint("TOPLEFT", 0, -20)
        anchorFrame:SetSize(90, 90)
        anchorFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        anchorFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        anchorFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local anchors = {
            { point = "TOPLEFT", x = 5, y = -5 },
            { point = "TOP", x = 37, y = -5 },
            { point = "TOPRIGHT", x = 69, y = -5 },
            { point = "LEFT", x = 5, y = -37 },
            { point = "CENTER", x = 37, y = -37 },
            { point = "RIGHT", x = 69, y = -37 },
            { point = "BOTTOMLEFT", x = 5, y = -69 },
            { point = "BOTTOM", x = 37, y = -69 },
            { point = "BOTTOMRIGHT", x = 69, y = -69 },
        }

        local buttons = {}
        for _, anchor in ipairs(anchors) do
            if allowCenter or anchor.point ~= "CENTER" then
                local btn = CreateFrame("Button", nil, anchorFrame)
                btn:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", anchor.x, anchor.y)
                btn:SetSize(16, 16)
                
                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                btn.bg = bg
                
                local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                
                local selected = btn:CreateTexture(nil, "OVERLAY")
                selected:SetAllPoints()
                selected:SetColorTexture(0.2, 0.8, 0.2, 1.0)
                selected:Hide()
                btn.selected = selected
                
                btn.anchorPoint = anchor.point
                btn:SetScript("OnClick", function(self)
                    setter(self.anchorPoint)
                    for _, b in ipairs(buttons) do
                        b.selected:Hide()
                    end
                    self.selected:Show()
                end)
                
                table.insert(buttons, btn)
            end
        end

        local currentAnchor = getter()
        for _, btn in ipairs(buttons) do
            if btn.anchorPoint == currentAnchor then
                btn.selected:Show()
                break
            end
        end

        local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("LEFT", anchorFrame, "RIGHT", 10, 0)
        desc:SetWidth(150)
        desc:SetJustifyH("LEFT")
        desc:SetText("Click a point to position text")

        return container
    end

    --------------------------------------------------------
    -- BASIC SETTINGS (Compact Mode)
    --------------------------------------------------------
    local yPos = -10

    CreateCheckbox(basicContainer, "Enable NextCast", yPos,
        function() return db.enabled end,
        function(v) db.enabled = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(basicContainer, "Show out of combat", yPos,
        function() return db.showOutOfCombat end,
        function(v) db.showOutOfCombat = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 40

    CreateSlider(basicContainer, "Scale", yPos, 0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) db.scale = v; ui:ApplySettings() end)
    yPos = yPos - 60

    CreateSlider(basicContainer, "Opacity", yPos, 0.2, 1.0, 0.05,
        function() return db.alpha end,
        function(v) db.alpha = v; ui:ApplySettings() end)

    --------------------------------------------------------
    -- ADVANCED SETTINGS (Expanded Mode with Tabs)
    --------------------------------------------------------
    local tabs = {}
    local tabContents = {}
    local activeTab = 1

    -- Create custom tabs (no template dependencies)
    for i = 1, 4 do
        local tab = CreateFrame("Button", nil, advancedContainer)
        tab:SetID(i)
        tab:SetSize(110, 28)
        
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        tab.bg = bg
        
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(({ "General", "Cooldown", "Keybind", "Warning" })[i])
        tab.text = text
        
        local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)
        
        tab:SetScript("OnClick", function(self)
            activeTab = self:GetID()
            for j = 1, 4 do
                if tabs[j] then
                    if j == activeTab then
                        tabs[j].bg:SetColorTexture(0.3, 0.3, 0.3, 1.0)
                        tabs[j].text:SetTextColor(1, 1, 1)
                    else
                        tabs[j].bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                        tabs[j].text:SetTextColor(0.7, 0.7, 0.7)
                    end
                end
                if tabContents[j] then
                    tabContents[j]:SetShown(j == activeTab)
                end
            end
        end)
        
        if i == 1 then
            tab:SetPoint("TOPLEFT", advancedContainer, "TOPLEFT", 10, -10)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 4, 0)
        end
        
        tabs[i] = tab
    end

    if tabs[1] then
        tabs[1].bg:SetColorTexture(0.3, 0.3, 0.3, 1.0)
        tabs[1].text:SetTextColor(1, 1, 1)
    end

    -- Scrollable containers for each tab
    for i = 1, 4 do
        local scrollFrame = CreateFrame("ScrollFrame", nil, advancedContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -50)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
        if i > 1 then scrollFrame:Hide() end

        local scrollChild = CreateFrame("Frame")
        scrollChild:SetSize(630, 650)
        scrollFrame:SetScrollChild(scrollChild)

        tabContents[i] = scrollFrame
        tabContents[i].content = scrollChild
    end

    -- TAB 1: GENERAL
    yPos = -10
    CreateCheckbox(tabContents[1].content, "Enable NextCast", yPos,
        function() return db.enabled end,
        function(v) db.enabled = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1].content, "Show out of combat", yPos,
        function() return db.showOutOfCombat end,
        function(v) db.showOutOfCombat = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 35

    local hideLabel = tabContents[1].content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hideLabel:SetPoint("TOPLEFT", 16, yPos)
    hideLabel:SetText("Hide Conditions")
    yPos = yPos - 25

    CreateCheckbox(tabContents[1].content, "Hide when mounted", yPos,
        function() return db.hideWhenMounted end,
        function(v) db.hideWhenMounted = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1].content, "Hide when in vehicle", yPos,
        function() return db.hideWhenInVehicle end,
        function(v) db.hideWhenInVehicle = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1].content, "Hide when possessed", yPos,
        function() return db.hideWhenPossessed end,
        function(v) db.hideWhenPossessed = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 45

    local displayLabel = tabContents[1].content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayLabel:SetPoint("TOPLEFT", 16, yPos)
    displayLabel:SetText("Display")
    yPos = yPos - 35

    CreateSlider(tabContents[1].content, "Scale", yPos, 0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) db.scale = v; ui:ApplySettings() end)
    yPos = yPos - 60

    CreateSlider(tabContents[1].content, "Opacity", yPos, 0.2, 1.0, 0.05,
        function() return db.alpha end,
        function(v) db.alpha = v; ui:ApplySettings() end)

    -- TAB 2: COOLDOWN
    yPos = -10
    CreateCheckbox(tabContents[2].content, "Show cooldown swipe", yPos,
        function() return db.showCooldownSwipe end,
        function(v) db.showCooldownSwipe = v; ui:ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[2].content, "Show cooldown text", yPos,
        function() return db.showCooldownText end,
        function(v) db.showCooldownText = v; ui:ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[2].content, "Show tenths of a second", yPos,
        function() return db.cdShowTenths end,
        function(v) db.cdShowTenths = v; ui:ApplySettings() end)
    yPos = yPos - 45

    CreateFontDropdown(tabContents[2].content, "Cooldown font", yPos,
        function() return db.cdFontFace end,
        function(v) db.cdFontFace = v; ui:ApplySettings() end)
    yPos = yPos - 55

    CreateSlider(tabContents[2].content, "Cooldown font size", yPos, 10, 32, 1,
        function() return db.cdFontSize end,
        function(v) db.cdFontSize = v; ui:ApplySettings() end)
    yPos = yPos - 60

    CreateColorButton(tabContents[2].content, "Cooldown text color", yPos,
        function() return db.cdFontColor end,
        function(c) db.cdFontColor = c; ui:ApplySettings() end)
    yPos = yPos - 40

    CreateAnchorSelector(tabContents[2].content, "Text position", yPos,
        function() return db.cdAnchor end,
        function(v) db.cdAnchor = v; ui:ApplySettings() end,
        true)

    -- TAB 3: KEYBIND
    yPos = -10
    CreateCheckbox(tabContents[3].content, "Show keybind", yPos,
        function() return db.showKeybind end,
        function(v) db.showKeybind = v; ui:ApplySettings() end)
    yPos = yPos - 45

    CreateFontDropdown(tabContents[3].content, "Keybind font", yPos,
        function() return db.keybindFontFace end,
        function(v) db.keybindFontFace = v; ui:ApplySettings() end)
    yPos = yPos - 55

    CreateSlider(tabContents[3].content, "Keybind font size", yPos, 8, 20, 1,
        function() return db.keybindFontSize end,
        function(v) db.keybindFontSize = v; ui:ApplySettings() end)
    yPos = yPos - 60

    CreateColorButton(tabContents[3].content, "Keybind text color", yPos,
        function() return db.keybindFontColor end,
        function(c) db.keybindFontColor = c; ui:ApplySettings() end)
    yPos = yPos - 40

    CreateAnchorSelector(tabContents[3].content, "Text position", yPos,
        function() return db.keybindAnchor end,
        function(v) 
            db.keybindAnchor = v
            ui:ApplySettings()
            if warningText then
                warningText:SetShown(db.cdAnchor == db.keybindAnchor)
            end
        end,
        false)
    yPos = yPos - 120

    local warningText = tabContents[3].content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOPLEFT", 16, yPos)
    warningText:SetWidth(260)
    warningText:SetJustifyH("LEFT")
    warningText:SetTextColor(1.0, 0.5, 0.0)
    warningText:SetText("|cFFFF8800Warning:|r Cooldown and Keybind are using the same position. This may cause readability issues. Consider positioning them separately.")
    warningText:SetWordWrap(true)
    warningText:SetShown(db.cdAnchor == db.keybindAnchor)

    -- TAB 4: WARNING
    yPos = -10
    CreateCheckbox(tabContents[4].content, "Enable cooldown warning", yPos,
        function() return db.cdWarningEnabled end,
        function(v) db.cdWarningEnabled = v end)
    yPos = yPos - 60

    CreateSlider(tabContents[4].content, "Warning threshold (seconds)", yPos, 1, 5, 1,
        function() return db.cdWarningThreshold end,
        function(v) db.cdWarningThreshold = v end)
    yPos = yPos - 60

    CreateColorButton(tabContents[4].content, "Warning text color", yPos,
        function() return db.cdWarningColor end,
        function(c) db.cdWarningColor = c; ui:ApplySettings() end)

    --------------------------------------------------------
    -- Advanced Options Toggle
    --------------------------------------------------------
    advancedCheck:SetScript("OnClick", function(self)
        local isAdvanced = self:GetChecked()
        
        if isAdvanced then
            settings:SetSize(720, 560)
            basicContainer:Hide()
            advancedContainer:Show()
        else
            settings:SetSize(500, 320)
            basicContainer:Show()
            advancedContainer:Hide()
        end
    end)
    
    --------------------------------------------------------
    -- Click Outside Handler (Settings Dialog)
    --------------------------------------------------------
    -- Register the settings dialog to close on outside clicks
    settings:SetScript("OnLeave", function(self)
        -- Track when mouse leaves the dialog
    end)
    
    -- Create a backdrop that doesn't intercept clicks
    -- The settings dialog itself will handle click-outside detection
    -- by checking if the click occurred outside its bounds
    local originalOnMouseDown = settings:GetScript("OnMouseDown") or function() end
    
    settings:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            if originalOnMouseDown then originalOnMouseDown(self, button) end
            return
        end
        
        -- Let internal click handling proceed
        if originalOnMouseDown then originalOnMouseDown(self, button) end
    end)
    
    -- Use a dismiss frame approach: full-screen frame BELOW settings that closes it
    local dismissFrame = CreateFrame("Frame", nil, UIParent)
    dismissFrame:SetFrameStrata("BACKGROUND")  -- Very low, below button
    dismissFrame:SetAllPoints(UIParent)
    dismissFrame:EnableMouse(true)
    dismissFrame:Hide()
    
    dismissFrame:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if settings:IsShown() then
            -- Check if click was inside settings frame - if so, don't close
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetScale()
            mx, my = mx / scale, my / scale
            
            local left = settings:GetLeft()
            local right = settings:GetRight()
            local top = settings:GetTop()
            local bottom = settings:GetBottom()
            
            if left and right and top and bottom then
                -- If click IS inside settings, don't do anything (let settings handle it)
                if mx >= left and mx <= right and my >= bottom and my <= top then
                    return
                end
            end
            
            -- Click was outside settings, close it and clean up UI state
            settings:Hide()
            ui:SetUnlocked(false)
            ui:SetTestMode(false)
        end
    end)
    
    -- Show/hide dismiss frame with settings
    settings:HookScript("OnShow", function(self)
        dismissFrame:Show()
    end)
    
    settings:HookScript("OnHide", function(self)
        dismissFrame:Hide()
    end)

    --------------------------------------------------------
    -- Reset Position Button
    --------------------------------------------------------
    local resetBtn = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOM", 0, 12)
    resetBtn:SetSize(140, 25)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 }
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

    self.settings = CreateEditModeSettings()

    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            self:Enter()
        end)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:Exit()
        end)
    end
end

function EditMode:Enter()
    self.active = true
    local core = NextCast:GetModule("Core")
    if core and core.db then
        core.db.locked = false
    end
    local ui = NextCast:GetModule("UI")
    if ui then
        ui:SetUnlocked(true)
    end
end

function EditMode:Exit()
    self.active = false
    local core = NextCast:GetModule("Core")
    if core and core.db then
        core.db.locked = true
    end
    if self.settings then
        self.settings:Hide()
    end
    local ui = NextCast:GetModule("UI")
    if ui then
        ui:SetUnlocked(false)
    end
end

function EditMode:ToggleSettings()
    if not self.settings then return end
    if self.settings:IsShown() then
        self.settings:Hide()
    else
        self.settings:Show()
    end
end

function EditMode:Toggle()
    if self.active then
        self:Exit()
    else
        self:Enter()
    end
end
