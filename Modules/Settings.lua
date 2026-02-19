local _, NextCast = ...

local SettingsModule = {}
NextCast:NewModule("Settings", SettingsModule)

------------------------------------------------------------
-- WoW Font List (Common first, then separator, then rest)
------------------------------------------------------------
local FONT_LIST = {
    -- Common fonts
    { path = "Fonts\\FRIZQT__.TTF", name = "Friz Quadrata (Default)" },
    { path = "Fonts\\ARIALN.TTF", name = "Arial Narrow" },
    { path = "Fonts\\skurri.ttf", name = "Skurri" },
    { path = "Fonts\\MORPHEUS.TTF", name = "Morpheus" },
    { path = "separator" },  -- Visual separator
    -- Additional fonts
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
-- Helper Functions
------------------------------------------------------------
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
-- Tab Panel Creation
------------------------------------------------------------
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "NextCastOptionsPanel")
    panel.name = "NextCast"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("NextCast")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure NextCast spell recommendation display")

    local db = NextCast:GetModule("Core").db

    --------------------------------------------------------
    -- Preview Panel (Right Side - Persistent across tabs)
    --------------------------------------------------------
    local previewLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("TOPRIGHT", -16, -16)
    previewLabel:SetText("Preview")
    
    local previewBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    previewBg:SetPoint("TOPRIGHT", -16, -40)
    previewBg:SetSize(120, 120)
    previewBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    previewBg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)

    -- Preview button
    local previewBtn = CreateFrame("Button", nil, previewBg)
    previewBtn:SetSize(50, 50)
    previewBtn:SetPoint("CENTER")
    previewBtn:EnableMouse(false)

    local previewIcon = previewBtn:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints(previewBtn)
    previewIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local previewCd = CreateFrame("Cooldown", nil, previewBtn, "CooldownFrameTemplate")
    previewCd:SetAllPoints(previewBtn)
    previewCd:SetDrawEdge(false)
    previewCd:SetHideCountdownNumbers(true)

    local previewKeybind = previewBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewKeybind:SetPoint("BOTTOMLEFT", 2, 2)
    previewKeybind:SetTextColor(1, 1, 1)
    previewKeybind:SetText("S1")

    local previewCdText = previewBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    previewCdText:SetPoint("CENTER")
    previewCdText:SetTextColor(1, 0.95, 0.6)
    previewCdText:SetJustifyH("CENTER")
    previewCdText:SetJustifyV("MIDDLE")

    -- Update preview function
    local function UpdatePreview()
        previewBtn:SetScale(db.scale or 1.0)
        previewBtn:SetAlpha(db.alpha or 1.0)
        
        -- Apply fonts (with fallback protection)
        local cdFont = db.cdFontFace or "Fonts\\FRIZQT__.TTF"
        local kbFont = db.keybindFontFace or "Fonts\\FRIZQT__.TTF"
        
        local success1 = pcall(previewKeybind.SetFont, previewKeybind, kbFont, db.keybindFontSize or 12, "OUTLINE")
        if not success1 then
            previewKeybind:SetFont("Fonts\\FRIZQT__.TTF", db.keybindFontSize or 12, "OUTLINE")
        end
        
        local success2 = pcall(previewCdText.SetFont, previewCdText, cdFont, db.cdFontSize or 18, "OUTLINE")
        if not success2 then
            previewCdText:SetFont("Fonts\\FRIZQT__.TTF", db.cdFontSize or 18, "OUTLINE")
        end
        
        -- Apply colors
        local kbColor = db.keybindFontColor or { r = 1, g = 1, b = 1 }
        local cdColor = db.cdFontColor or { r = 1, g = 0.95, b = 0.6 }
        previewKeybind:SetTextColor(kbColor.r, kbColor.g, kbColor.b)
        previewCdText:SetTextColor(cdColor.r, cdColor.g, cdColor.b)
        
        -- Apply anchor positions
        previewKeybind:ClearAllPoints()
        previewCdText:ClearAllPoints()
        
        local kbAnchor = db.keybindAnchor or "TOPLEFT"
        local cdAnchor = db.cdAnchor or "CENTER"
        
        -- Keybind anchor (with 2px padding)
        if kbAnchor == "TOPLEFT" then
            previewKeybind:SetPoint("TOPLEFT", previewBtn, "TOPLEFT", 2, -2)
        elseif kbAnchor == "TOP" then
            previewKeybind:SetPoint("TOP", previewBtn, "TOP", 0, -2)
        elseif kbAnchor == "TOPRIGHT" then
            previewKeybind:SetPoint("TOPRIGHT", previewBtn, "TOPRIGHT", -2, -2)
        elseif kbAnchor == "LEFT" then
            previewKeybind:SetPoint("LEFT", previewBtn, "LEFT", 2, 0)
        elseif kbAnchor == "RIGHT" then
            previewKeybind:SetPoint("RIGHT", previewBtn, "RIGHT", -2, 0)
        elseif kbAnchor == "BOTTOMLEFT" then
            previewKeybind:SetPoint("BOTTOMLEFT", previewBtn, "BOTTOMLEFT", 2, 2)
        elseif kbAnchor == "BOTTOM" then
            previewKeybind:SetPoint("BOTTOM", previewBtn, "BOTTOM", 0, 2)
        elseif kbAnchor == "BOTTOMRIGHT" then
            previewKeybind:SetPoint("BOTTOMRIGHT", previewBtn, "BOTTOMRIGHT", -2, 2)
        end
        
        -- Cooldown text anchor (with 2px padding)
        if cdAnchor == "CENTER" then
            previewCdText:SetPoint("CENTER", previewBtn, "CENTER", 0, 0)
        elseif cdAnchor == "TOPLEFT" then
            previewCdText:SetPoint("TOPLEFT", previewBtn, "TOPLEFT", 2, -2)
        elseif cdAnchor == "TOP" then
            previewCdText:SetPoint("TOP", previewBtn, "TOP", 0, -2)
        elseif cdAnchor == "TOPRIGHT" then
            previewCdText:SetPoint("TOPRIGHT", previewBtn, "TOPRIGHT", -2, -2)
        elseif cdAnchor == "LEFT" then
            previewCdText:SetPoint("LEFT", previewBtn, "LEFT", 2, 0)
        elseif cdAnchor == "RIGHT" then
            previewCdText:SetPoint("RIGHT", previewBtn, "RIGHT", -2, 0)
        elseif cdAnchor == "BOTTOMLEFT" then
            previewCdText:SetPoint("BOTTOMLEFT", previewBtn, "BOTTOMLEFT", 2, 2)
        elseif cdAnchor == "BOTTOM" then
            previewCdText:SetPoint("BOTTOM", previewBtn, "BOTTOM", 0, 2)
        elseif cdAnchor == "BOTTOMRIGHT" then
            previewCdText:SetPoint("BOTTOMRIGHT", previewBtn, "BOTTOMRIGHT", -2, 2)
        end
        
        -- Show/hide elements
        previewKeybind:SetShown(db.showKeybind)
        previewCdText:SetShown(db.showCooldownText)
        previewCd:SetDrawSwipe(db.showCooldownSwipe)
        
        -- Update text format based on precision
        if db.cdShowTenths then
            previewCdText:SetText("10.2")
        else
            previewCdText:SetText("10")
        end
    end

    panel.UpdatePreview = UpdatePreview

    --------------------------------------------------------
    -- Helper Functions for UI Elements
    --------------------------------------------------------
    local function CreateCheckbox(parent, label, yOffset, getter, setter)
        local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 16, yOffset)
        check.Text:SetText(label)
        check:SetChecked(getter())
        check:SetScript("OnClick", function(self)
            setter(self:GetChecked())
            UpdatePreview()
        end)
        return check
    end

    local function CreateSlider(parent, label, yOffset, min, max, step, getter, setter, formatFunc)
        local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 16, yOffset)
        slider:SetWidth(260)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetValue(getter())
        slider:SetObeyStepOnDrag(true)
        if slider.Low then slider.Low:Hide() end
        if slider.High then slider.High:Hide() end

        local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
        labelText:SetText(label)

        local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
        local format = formatFunc or function(v) return string.format("%.2f", v) end
        valueText:SetText(format(getter()))

        slider:SetScript("OnValueChanged", function(self, value)
            valueText:SetText(format(value))
            setter(value)
            UpdatePreview()
        end)

        return slider
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
            OpenColorPicker(getter(), function(color)
                setter(color)
                updateSwatch()
                UpdatePreview()
            end)
        end)

        updateSwatch()
        return btn
    end

    local function CreateAnchorSelector(parent, label, yOffset, getter, setter, allowCenter)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", 16, yOffset)
        container:SetSize(260, 110)

        -- Label
        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("TOPLEFT", 0, 0)
        labelText:SetText(label)

        -- Anchor grid (3x3 grid with optional center)
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

        -- Anchor points mapping
        local anchors = {
            { point = "TOPLEFT", x = 5, y = -5, row = 1, col = 1 },
            { point = "TOP", x = 37, y = -5, row = 1, col = 2 },
            { point = "TOPRIGHT", x = 69, y = -5, row = 1, col = 3 },
            { point = "LEFT", x = 5, y = -37, row = 2, col = 1 },
            { point = "CENTER", x = 37, y = -37, row = 2, col = 2 },
            { point = "RIGHT", x = 69, y = -37, row = 2, col = 3 },
            { point = "BOTTOMLEFT", x = 5, y = -69, row = 3, col = 1 },
            { point = "BOTTOM", x = 37, y = -69, row = 3, col = 2 },
            { point = "BOTTOMRIGHT", x = 69, y = -69, row = 3, col = 3 },
        }

        local buttons = {}
        for _, anchor in ipairs(anchors) do
            -- Skip CENTER if not allowed
            if allowCenter or anchor.point ~= "CENTER" then
                local btn = CreateFrame("Button", nil, anchorFrame)
                btn:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", anchor.x, anchor.y)
                btn:SetSize(16, 16)
                
                -- Background
                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                btn.bg = bg
                
                -- Selection highlight
                local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                
                -- Selected indicator
                local selected = btn:CreateTexture(nil, "OVERLAY")
                selected:SetAllPoints()
                selected:SetColorTexture(0.2, 0.8, 0.2, 1.0)
                selected:Hide()
                btn.selected = selected
                
                btn.anchorPoint = anchor.point
                btn:SetScript("OnClick", function(self)
                    setter(self.anchorPoint)
                    -- Update selection visual
                    for _, b in ipairs(buttons) do
                        b.selected:Hide()
                    end
                    self.selected:Show()
                    UpdatePreview()
                end)
                
                table.insert(buttons, btn)
            end
        end

        -- Set initial selection
        local currentAnchor = getter()
        for _, btn in ipairs(buttons) do
            if btn.anchorPoint == currentAnchor then
                btn.selected:Show()
                break
            end
        end

        -- Description text
        local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("LEFT", anchorFrame, "RIGHT", 10, 0)
        desc:SetWidth(150)
        desc:SetJustifyH("LEFT")
        desc:SetText("Click a point to position text")

        return container
    end

    local function CreateFontDropdown(parent, label, yOffset, getter, setter)
        -- Check if UIDropDownMenu API exists (may be deprecated in future)
        if not UIDropDownMenu_Initialize then
            -- Fallback: Create a simple text label showing current font
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 16, yOffset)
            container:SetSize(260, 30)
            
            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetText(label .. " (dropdown unavailable)")
            labelText:SetTextColor(1, 0.5, 0)
            
            return container
        end
        
        local dropdown = CreateFrame("Frame", "NextCastFontDropdown_" .. label, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -4, yOffset)
        
        local labelText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        labelText:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 2)
        labelText:SetText(label)

        UIDropDownMenu_SetWidth(dropdown, 200)
        
        local function OnClick(self)
            UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
            setter(self.value)
            UpdatePreview()
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
        
        -- Set initial display text
        for i, fontData in ipairs(FONT_LIST) do
            if fontData.path == getter() then
                UIDropDownMenu_SetText(dropdown, fontData.name)
                break
            end
        end

        return dropdown
    end

    --------------------------------------------------------
    -- Create Tab System (Custom - no template dependencies)
    --------------------------------------------------------
    local TAB_GENERAL = 1
    local TAB_COOLDOWN = 2
    local TAB_KEYBIND = 3
    local TAB_WARNING = 4

    local tabs = {}
    local tabContents = {}
    local activeTab = 1

    -- Create tabs without template (positioned within panel bounds)
    for i = 1, 4 do
        local tab = CreateFrame("Button", "NextCastTab" .. i, panel)
        tab:SetID(i)
        tab:SetSize(110, 28)
        
        -- Tab background (normal state)
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        tab.bg = bg
        
        -- Tab text
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(({ "General", "Cooldown", "Keybind", "Warning" })[i])
        tab.text = text
        
        -- Selection highlight
        local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)
        
        -- Tab click handler
        tab:SetScript("OnClick", function(self)
            activeTab = self:GetID()
            -- Update tab visuals
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
                -- Update content visibility
                if tabContents[j] then
                    tabContents[j]:SetShown(j == activeTab)
                end
            end
        end)
        
        -- Position tabs inside panel below the subtitle
        if i == 1 then
            tab:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -60)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 4, 0)
        end
        
        tabs[i] = tab
    end

    -- Set initial active tab
    if tabs[1] then
        tabs[1].bg:SetColorTexture(0.3, 0.3, 0.3, 1.0)
        tabs[1].text:SetTextColor(1, 1, 1)
    end

    --------------------------------------------------------
    -- TAB 1: GENERAL
    --------------------------------------------------------
    tabContents[1] = CreateFrame("Frame", nil, panel)
    tabContents[1]:SetPoint("TOPLEFT", 10, -100)
    tabContents[1]:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMLEFT", -20, 0)
    
    local yPos = -10
    CreateCheckbox(tabContents[1], "Enable NextCast", yPos,
        function() return db.enabled end,
        function(v) db.enabled = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1], "Show out of combat", yPos,
        function() return db.showOutOfCombat end,
        function(v) db.showOutOfCombat = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 35

    -- Hide conditions section
    local hideLabel = tabContents[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hideLabel:SetPoint("TOPLEFT", 16, yPos)
    hideLabel:SetText("Hide Conditions")
    yPos = yPos - 25

    CreateCheckbox(tabContents[1], "Hide when mounted", yPos,
        function() return db.hideWhenMounted end,
        function(v) db.hideWhenMounted = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1], "Hide when in vehicle", yPos,
        function() return db.hideWhenInVehicle end,
        function(v) db.hideWhenInVehicle = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[1], "Hide when possessed", yPos,
        function() return db.hideWhenPossessed end,
        function(v) db.hideWhenPossessed = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 45

    -- Display section
    local displayLabel = tabContents[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayLabel:SetPoint("TOPLEFT", 16, yPos)
    displayLabel:SetText("Display")
    yPos = yPos - 35

    CreateSlider(tabContents[1], "Scale", yPos, 0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) db.scale = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 50

    CreateSlider(tabContents[1], "Opacity", yPos, 0.2, 1.0, 0.05,
        function() return db.alpha end,
        function(v) db.alpha = v; NextCast:GetModule("UI"):ApplySettings() end)

    --------------------------------------------------------
    -- TAB 2: COOLDOWN
    --------------------------------------------------------
    tabContents[2] = CreateFrame("Frame", nil, panel)
    tabContents[2]:SetPoint("TOPLEFT", 10, -100)
    tabContents[2]:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMLEFT", -20, 0)
    tabContents[2]:Hide()
    
    yPos = -10
    CreateCheckbox(tabContents[2], "Show cooldown swipe", yPos,
        function() return db.showCooldownSwipe end,
        function(v) db.showCooldownSwipe = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[2], "Show cooldown text", yPos,
        function() return db.showCooldownText end,
        function(v) db.showCooldownText = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox(tabContents[2], "Show tenths of a second", yPos,
        function() return db.cdShowTenths end,
        function(v) db.cdShowTenths = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 45

    CreateFontDropdown(tabContents[2], "Cooldown font", yPos,
        function() return db.cdFontFace end,
        function(v) db.cdFontFace = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 55

    CreateSlider(tabContents[2], "Cooldown font size", yPos, 10, 32, 1,
        function() return db.cdFontSize end,
        function(v) db.cdFontSize = v; NextCast:GetModule("UI"):ApplySettings() end,
        function(v) return string.format("%.0f", v) end)
    yPos = yPos - 50

    CreateColorButton(tabContents[2], "Cooldown text color", yPos,
        function() return db.cdFontColor end,
        function(c) db.cdFontColor = c; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 40

    -- v1.1.0: Anchor position selector
    CreateAnchorSelector(tabContents[2], "Text position", yPos,
        function() return db.cdAnchor end,
        function(v) db.cdAnchor = v; NextCast:GetModule("UI"):ApplySettings() end,
        true)  -- Allow CENTER for cooldown

    --------------------------------------------------------
    -- TAB 3: KEYBIND
    --------------------------------------------------------
    tabContents[3] = CreateFrame("Frame", nil, panel)
    tabContents[3]:SetPoint("TOPLEFT", 10, -100)
    tabContents[3]:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMLEFT", -20, 0)
    tabContents[3]:Hide()
    
    yPos = -10
    CreateCheckbox(tabContents[3], "Show keybind", yPos,
        function() return db.showKeybind end,
        function(v) db.showKeybind = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 45

    CreateFontDropdown(tabContents[3], "Keybind font", yPos,
        function() return db.keybindFontFace end,
        function(v) db.keybindFontFace = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 55

    CreateSlider(tabContents[3], "Keybind font size", yPos, 8, 20, 1,
        function() return db.keybindFontSize end,
        function(v) db.keybindFontSize = v; NextCast:GetModule("UI"):ApplySettings() end,
        function(v) return string.format("%.0f", v) end)
    yPos = yPos - 50

    CreateColorButton(tabContents[3], "Keybind text color", yPos,
        function() return db.keybindFontColor end,
        function(c) db.keybindFontColor = c; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 40

    -- v1.1.0: Anchor position selector
    CreateAnchorSelector(tabContents[3], "Text position", yPos,
        function() return db.keybindAnchor end,
        function(v) 
            db.keybindAnchor = v
            NextCast:GetModule("UI"):ApplySettings()
            -- Update collision warning
            if warningText then
                if db.cdAnchor == db.keybindAnchor then
                    warningText:Show()
                else
                    warningText:Hide()
                end
            end
        end,
        false)  -- No CENTER for keybind
    yPos = yPos - 120

    -- Collision warning
    local warningText = tabContents[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOPLEFT", 16, yPos)
    warningText:SetWidth(260)
    warningText:SetJustifyH("LEFT")
    warningText:SetTextColor(1.0, 0.5, 0.0)
    warningText:SetText("|cFFFF8800Warning:|r Cooldown and Keybind are using the same position. This may cause readability issues. Consider positioning them separately.")
    warningText:SetWordWrap(true)
    -- Show/hide based on anchor collision
    if db.cdAnchor == db.keybindAnchor then
        warningText:Show()
    else
        warningText:Hide()
    end

    --------------------------------------------------------
    -- TAB 4: WARNING
    --------------------------------------------------------
    tabContents[4] = CreateFrame("Frame", nil, panel)
    tabContents[4]:SetPoint("TOPLEFT", 10, -100)
    tabContents[4]:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMLEFT", -20, 0)
    tabContents[4]:Hide()
    
    yPos = -10
    CreateCheckbox(tabContents[4], "Enable cooldown warning", yPos,
        function() return db.cdWarningEnabled end,
        function(v) db.cdWarningEnabled = v end)
    yPos = yPos - 50

    CreateSlider(tabContents[4], "Warning threshold (seconds)", yPos, 1, 5, 1,
        function() return db.cdWarningThreshold end,
        function(v) db.cdWarningThreshold = v end,
        function(v) return string.format("%.0f", v) end)
    yPos = yPos - 50

    CreateColorButton(tabContents[4], "Warning text color", yPos,
        function() return db.cdWarningColor end,
        function(c) db.cdWarningColor = c; NextCast:GetModule("UI"):ApplySettings() end)

    --------------------------------------------------------
    -- Default Settings Function
    --------------------------------------------------------
    panel.default = function()
        db.enabled = true
        db.showOutOfCombat = true
        db.hideWhenMounted = false
        db.hideWhenInVehicle = false
        db.hideWhenPossessed = false
        db.showCooldownSwipe = true
        db.showCooldownText = true
        db.showKeybind = true
        db.scale = 1.0
        db.alpha = 1.0
        db.cdWarningThreshold = 3
        db.cdWarningColor = { r = 1.0, g = 0.0, b = 0.0 }
        db.cdFontSize = 18
        db.cdFontColor = { r = 1.0, g = 0.95, b = 0.6 }
        db.cdFontFace = "Fonts\\FRIZQT__.TTF"
        db.cdAnchor = "CENTER"  -- v1.1.0
        db.keybindFontSize = 12
        db.keybindFontColor = { r = 1.0, g = 1.0, b = 1.0 }
        db.keybindFontFace = "Fonts\\FRIZQT__.TTF"
        db.keybindAnchor = "TOPLEFT"  -- v1.1.0
        db.cdShowTenths = true
        db.cdWarningEnabled = true
        NextCast:GetModule("UI"):ApplySettings()
        NextCast:GetModule("Tracker"):Update()
        UpdatePreview()
    end

    return panel
end

------------------------------------------------------------
-- Module Initialization
------------------------------------------------------------
function SettingsModule:Initialize()
    if self.initialized then return end
    self.initialized = true

    local db = NextCast:GetModule("Core").db
    if not db then return end

    self.panel = CreateOptionsPanel()
    
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(self.panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(self.panel, self.panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    end

    --------------------------------------------------------
    -- Slash Commands
    --------------------------------------------------------
    SLASH_NextCast1 = "/NextCast"
    SlashCmdList.NextCast = function(msg)
        local parts = {}
        for word in msg:gmatch("%S+") do
            table.insert(parts, word)
        end
        
        local cmd = (parts[1] or ""):lower()
        local arg = parts[2] or ""
        
        if cmd == "on" then
            db.enabled = true
            print("NextCast: Enabled")
            NextCast:GetModule("Tracker"):Update()
        elseif cmd == "off" then
            db.enabled = false
            print("NextCast: Disabled")
            NextCast:GetModule("Tracker"):Update()
        elseif cmd == "combat" then
            db.showOutOfCombat = not db.showOutOfCombat
            print("NextCast: Show out of combat - " .. (db.showOutOfCombat and "ON" or "OFF"))
            NextCast:GetModule("Tracker"):Update()
        elseif cmd == "resetpos" then
            db.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 }
            NextCast:GetModule("UI"):ApplySettings()
            print("NextCast: Position reset")
        elseif cmd == "debug" then
            db.debugMode = not db.debugMode
            print("NextCast: Debug mode - " .. (db.debugMode and "ON" or "OFF"))
        elseif cmd == "config" or cmd == "settings" or cmd == "" then
            if Settings and Settings.OpenToCategory and self.category then
                -- Modern API: Use stored category's numeric ID
                Settings.OpenToCategory(self.category.ID)
            elseif InterfaceOptionsFrame_OpenToCategory then
                -- Legacy API: Use panel object
                InterfaceOptionsFrame_OpenToCategory(self.panel)
                InterfaceOptionsFrame_OpenToCategory(self.panel)
            end
        else
            print("NextCast v1.1.0")
            print("/nextcast on|off - Enable/disable addon")
            print("/nextcast combat - Toggle show out of combat")
            print("/nextcast debug - Toggle debug mode")
            print("/nextcast resetpos - Reset position")
            print("/nextcast config - Open settings")
        end
    end
end
