local _, NextCast = ...

local SettingsModule = {}
NextCast:NewModule("Settings", SettingsModule)

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

    -- Add preview frame on the right
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

    -- Create a mini preview button
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
    previewKeybind:SetFont(previewKeybind:GetFont(), db.keybindFontSize or 12, "OUTLINE")

    local previewCdText = previewBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    previewCdText:SetPoint("CENTER")
    previewCdText:SetTextColor(1, 0.95, 0.6)
    previewCdText:SetJustifyH("CENTER")
    previewCdText:SetJustifyV("MIDDLE")
    previewCdText:SetFont(previewCdText:GetFont(), db.cdFontSize or 18, "OUTLINE")
    previewCdText:SetText("10.0")

    -- Update preview when settings change
    local function UpdatePreview()
        previewBtn:SetScale(db.scale or 1.0)
        previewBtn:SetAlpha(db.alpha or 1.0)
        previewKeybind:SetFont(previewKeybind:GetFont(), db.keybindFontSize or 12, "OUTLINE")
        previewCdText:SetFont(previewCdText:GetFont(), db.cdFontSize or 18, "OUTLINE")
        previewKeybind:SetShown(db.showKeybind)
        previewCdText:SetShown(db.showCooldownText)
        previewCd:SetDrawSwipe(db.showCooldownSwipe)
    end

    panel.UpdatePreview = UpdatePreview

    local function CreateCheckbox(label, yOffset, getter, setter)
        local check = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", 16, yOffset)
        check.Text:SetText(label)
        check:SetChecked(getter())
        check:SetScript("OnClick", function(self)
            setter(self:GetChecked())
            UpdatePreview()
            -- Sync to Edit Mode if available
            local editMode = NextCast:GetModule("EditMode")
            if editMode and editMode.checkboxList then
                for _, chk in ipairs(editMode.checkboxList) do
                    if chk and chk.getter then
                        chk:SetChecked(chk.getter())
                    end
                end
            end
        end)
        return check
    end

    local function CreateSlider(label, yOffset, min, max, step, getter, setter)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
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
        valueText:SetText(string.format("%.2f", getter()))

        slider:SetScript("OnValueChanged", function(self, value)
            valueText:SetText(string.format("%.2f", value))
            setter(value)
            UpdatePreview()
        end)

        return slider
    end

    local function CreateColorButton(label, yOffset, getter, setter)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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

    local yPos = -70

    CreateCheckbox("Enable NextCast", yPos,
        function() return db.enabled end,
        function(v) db.enabled = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox("Show out of combat", yPos,
        function() return db.showOutOfCombat end,
        function(v) db.showOutOfCombat = v; NextCast:GetModule("Tracker"):Update() end)
    yPos = yPos - 25

    CreateCheckbox("Show cooldown swipe", yPos,
        function() return db.showCooldownSwipe end,
        function(v) db.showCooldownSwipe = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox("Show cooldown text", yPos,
        function() return db.showCooldownText end,
        function(v) db.showCooldownText = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 25

    CreateCheckbox("Show keybind", yPos,
        function() return db.showKeybind end,
        function(v) db.showKeybind = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 45

    CreateSlider("Scale", yPos, 0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) db.scale = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 50

    CreateSlider("Opacity", yPos, 0.2, 1.0, 0.05,
        function() return db.alpha end,
        function(v) db.alpha = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 50

    CreateSlider("Cooldown font size", yPos, 10, 32, 1,
        function() return db.cdFontSize end,
        function(v) db.cdFontSize = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 50

    CreateSlider("Keybind font size", yPos, 8, 20, 1,
        function() return db.keybindFontSize end,
        function(v) db.keybindFontSize = v; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 40

    CreateCheckbox("Cooldown warning", yPos,
        function() return db.cdWarningEnabled end,
        function(v) db.cdWarningEnabled = v end)
    yPos = yPos - 50

    CreateSlider("Warning threshold", yPos, 1, 5, 1,
        function() return db.cdWarningThreshold end,
        function(v) db.cdWarningThreshold = v end)
    yPos = yPos - 45

    CreateColorButton("Cooldown text color", yPos,
        function() return db.cdFontColor end,
        function(c) db.cdFontColor = c; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 30

    CreateColorButton("Keybind text color", yPos,
        function() return db.keybindFontColor end,
        function(c) db.keybindFontColor = c; NextCast:GetModule("UI"):ApplySettings() end)
    yPos = yPos - 30

    CreateColorButton("Warning text color", yPos,
        function() return db.cdWarningColor end,
        function(c) db.cdWarningColor = c; NextCast:GetModule("UI"):ApplySettings() end)

    panel.default = function()
        db.enabled = true
        db.showOutOfCombat = false
        db.showCooldownSwipe = true
        db.showCooldownText = true
        db.showKeybind = true
        db.scale = 1.0
        db.alpha = 1.0
        db.cdWarningThreshold = 3
        db.cdWarningColor = { r = 1.0, g = 0.0, b = 0.0 }
        db.cdFontSize = 18
        db.cdFontColor = { r = 1.0, g = 0.95, b = 0.6 }
        db.keybindFontSize = 12
        db.keybindFontColor = { r = 1.0, g = 1.0, b = 1.0 }
        NextCast:GetModule("UI"):ApplySettings()
        NextCast:GetModule("Tracker"):Update()
    end

    return panel
end

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
    end

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
        elseif cmd == "inspect" then
            local tracker = NextCast:GetModule("Tracker")
            if tracker and tracker.buttons then
                print("NextCast: Inspecting buttons (showing only those with highlights)...")
                local foundAny = false
                for i, entry in ipairs(tracker.buttons) do
                    local btn = entry.button
                    if btn and btn:IsShown() then
                        local hasHighlight = (btn.overlay and btn.overlay:IsShown()) or 
                                            (btn.ActionButtonOverlay and btn.ActionButtonOverlay:IsShown()) or
                                            (btn.SpellActivationAlert and btn.SpellActivationAlert:IsShown())
                        if hasHighlight then
                            foundAny = true
                            local btnName = btn:GetName() or "unknown"
                            print(string.format("Button: %s (%s)", btnName, entry.binding or "?"))
                            if btn.overlay then print(string.format("  overlay: exists, shown=%s", btn.overlay:IsShown() and "YES" or "no")) end
                            if btn.ActionButtonOverlay then print(string.format("  ActionButtonOverlay: exists, shown=%s", btn.ActionButtonOverlay:IsShown() and "YES" or "no")) end
                            if btn.SpellActivationAlert then print(string.format("  SpellActivationAlert: exists, shown=%s", btn.SpellActivationAlert:IsShown() and "YES" or "no")) end
                        end
                    end
                end
                if not foundAny then
                    print("NextCast: No buttons with highlights found. Make sure you're in combat with Assisted Combat enabled.")
                end
            end
        elseif cmd == "check" and arg ~= "" then
            local btn = _G[arg]
            if btn then
                print(string.format("NextCast: Checking %s", arg))
                print(string.format("  Shown: %s", btn:IsShown() and "YES" or "no"))
                print(string.format("  overlay: %s", btn.overlay and "exists" or "nil"))
                if btn.overlay then 
                    print(string.format("    shown: %s", btn.overlay:IsShown() and "YES" or "no"))
                    print(string.format("    name: %s", btn.overlay:GetName() or "no name"))
                    print(string.format("    objType: %s", btn.overlay:GetObjectType()))
                end
                print(string.format("  ActionButtonOverlay: %s", btn.ActionButtonOverlay and "exists" or "nil"))
                if btn.ActionButtonOverlay then print(string.format("    shown: %s", btn.ActionButtonOverlay:IsShown() and "YES" or "no")) end
                print(string.format("  SpellActivationAlert: %s", btn.SpellActivationAlert and "exists" or "nil"))
                if btn.SpellActivationAlert then print(string.format("    shown: %s", btn.SpellActivationAlert:IsShown() and "YES" or "no")) end
                -- Check for children
                local children = {btn:GetChildren()}
                print(string.format("  Children: %d", #children))
                for i, child in ipairs(children) do
                    local childName = child:GetName() or "unnamed"
                    local shown = child:IsShown() and "shown" or "hidden"
                    print(string.format("    [%d] %s (%s) - %s", i, childName, child:GetObjectType(), shown))
                end
            else
                print(string.format("NextCast: Button '%s' not found", arg))
            end
        elseif cmd == "config" or cmd == "settings" or cmd == "" then
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory("NextCast")
            elseif InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory(self.panel)
                InterfaceOptionsFrame_OpenToCategory(self.panel)
            end
        else
            print("NextCast v1.0.0")
            print("/NextCast on|off - Enable/disable addon")
            print("/NextCast combat - Toggle show out of combat")
            print("/NextCast debug - Toggle debug mode")
            print("/NextCast resetpos - Reset position")
            print("/NextCast inspect - Show buttons with highlights")
            print("/NextCast check <ButtonName> - Inspect specific button (e.g., ActionButton2)")
            print("/NextCast config - Open settings")
        end
    end
end
