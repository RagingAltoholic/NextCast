--[[
==================================================================================
NextCast - UI Module
==================================================================================
Handles the floating spell recommendation button display.

This module creates and manages the main UI button that shows:
- Spell icon (from Assisted Combat detection)
- Keybind text (bottom-left corner)
- Cooldown animation (swipe overlay)
- Cooldown countdown text (center)

The button supports:
- Dragging in Edit Mode
- Click-to-configure in Edit Mode
- Scale/opacity customization
- Font size customization
- Color customization
==================================================================================
--]]

local _, NextCast = ...

local UI = {}
NextCast:NewModule("UI", UI)

------------------------------------------------------------
-- Position Helpers
------------------------------------------------------------

--[[
    ApplyPosition(frame, db)
    
    Applies saved position to the frame, accounting for scale.
    Uses BOTTOMLEFT anchor to prevent position drift when scaling.
    
    The position is stored at scale 1.0, so we divide by current
    scale to get the correct unscaled coordinates.
--]]
local function ApplyPosition(frame, db)
    frame:ClearAllPoints()
    local scale = frame:GetScale()
    -- Convert stored position (at scale 1.0) to current scale
    local x = db.position.x / scale
    local y = db.position.y / scale
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

--[[
    EnsureOnScreen(frame)
    
    Safety check to prevent button from being lost off-screen.
    If the button is completely outside the visible area,
    reset it to the center of the screen.
--]]
local function EnsureOnScreen(frame)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or bottom then return end

    local uiWidth = UIParent:GetWidth()
    local uiHeight = UIParent:GetHeight()

    -- Check if button is completely off-screen
    if right < 0 or left > uiWidth or top < 0 or bottom > uiHeight then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end
end

------------------------------------------------------------
-- Initialization
------------------------------------------------------------

--[[
    UI:Initialize()
    
    Creates the main spell recommendation button and sets up all
    visual elements, mouse handlers, and dismiss frame.
    
    Called once on PLAYER_LOGIN by Core module.
    
    Frame hierarchy:
    - NextCastButton (main button, 50x50px)
      - bg texture (semi-transparent black background)
      - border texture (black border)
      - selectionBorder (yellow glow in Edit Mode)
      - icon (spell texture)
      - cooldown (swipe overlay)
      - keybind (bottom-left text)
      - cdText (center countdown text)
      - editLabel (top-left "NextCast" label in Edit Mode)
    - NextCastDismissFrame (fullscreen overlay for click-outside-to-close)
--]]
function UI:Initialize()
    if self.frame then return end

    -- Create main button frame (BackdropTemplate required for borders)
    local frame = CreateFrame("Button", "NextCastButton", UIParent, "BackdropTemplate")
    frame:SetSize(50, 50)
    frame:SetFrameStrata("MEDIUM")  -- Between LOW and HIGH
    frame:SetClampedToScreen(true)  -- Prevent dragging off-screen
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp")

    --------------------------------------------------------
    -- Click vs Drag Detection Variables
    --------------------------------------------------------
    -- Used to differentiate between a click and a drag
    -- If mouse moves >3 pixels or >0.15 seconds pass, it's a drag
    frame._mouseDownX = 0
    frame._mouseDownY = 0
    frame._mouseDownTime = 0

    --------------------------------------------------------
    -- Visual Elements
    --------------------------------------------------------
    -- Background: Semi-transparent black, hidden when no spell
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0, 0, 0, 0.35)
    frame.bg = bg

    -- Border: Solid black outline
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(0, 0, 0, 0.8)
    frame.border = border

    -- Selection Border: Yellow glow shown only in Edit Mode
    local selectionBorder = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    selectionBorder:SetAllPoints(frame)
    if selectionBorder.SetAtlas then
        -- Use Blizzard's Edit Mode highlight texture if available
        selectionBorder:SetAtlas("editmode-highlight")
    else
        -- Fallback to yellow color
        selectionBorder:SetColorTexture(1, 1, 0, 0.5)
    end
    selectionBorder:Hide()
    frame.selectionBorder = selectionBorder

    -- Icon: Spell texture with slight inset
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Crop edges for clean look
    frame.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    frame.cooldown = cooldown

    local keybind = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keybind:SetPoint("BOTTOMLEFT", 5, 5)
    keybind:SetTextColor(1, 1, 1)
    keybind:SetFont(keybind:GetFont(), 12, "OUTLINE")
    frame.keybind = keybind

    local cdText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cdText:SetPoint("CENTER", 0, 0)
    cdText:SetTextColor(1, 0.95, 0.6)
    cdText:SetFont(cdText:GetFont(), 18, "OUTLINE")
    frame.cdText = cdText

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, -4)
    label:SetTextColor(0.7, 0.9, 1)
    label:SetText("NextCast")
    label:Hide()
    frame.editLabel = label

    --------------------------------------------------------
    -- Fullscreen Dismiss Frame
    --------------------------------------------------------
    local dismiss = CreateFrame("Button", "NextCastDismissFrame", UIParent)
    dismiss:SetFrameStrata("BACKGROUND")
    dismiss:SetFrameLevel(0)
    dismiss:SetAllPoints(UIParent)
    dismiss:EnableMouse(true)
    dismiss:Hide()

    dismiss:SetScript("OnMouseDown", function()
        local EditMode = NextCast:GetModule("EditMode")
        if EditMode and EditMode.settingsDialog then
            EditMode.settingsDialog:Hide()
        end
        UI:SetUnlocked(false)
        dismiss:Hide()
        UI:SetTestMode(false)
    end)

    self.dismissFrame = dismiss

    --------------------------------------------------------
    -- Drag Behavior
    --------------------------------------------------------
    frame:SetScript("OnDragStart", function(self)
        if UI:CanMove() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)

    --------------------------------------------------------
    -- Click Behavior (Strict)
    --------------------------------------------------------
    frame:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end

        self._mouseDownX, self._mouseDownY = GetCursorPosition()
        self._mouseDownTime = GetTime()
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end

        local EditMode = NextCast:GetModule("EditMode")
        if not (EditMode and EditMode.active) then return end

        local x, y = GetCursorPosition()
        local dx = math.abs(x - self._mouseDownX)
        local dy = math.abs(y - self._mouseDownY)
        local dt = GetTime() - self._mouseDownTime

        -- Drag detection
        if dx > 3 or dy > 3 then return end
        if dt > 0.15 then return end

        -- Strict: If settings are open, do nothing
        if EditMode.settingsDialog and EditMode.settingsDialog:IsShown() then
            return
        end

        -- Open settings
        for _, checkbox in ipairs(EditMode.checkboxList or {}) do
            if checkbox.getter then checkbox:SetChecked(checkbox.getter()) end
        end
        for _, slider in ipairs(EditMode.sliderList or {}) do
            if slider.getter then slider:SetValue(slider.getter()) end
        end
        for _, btn in ipairs(EditMode.colorList or {}) do
            if btn.updateSwatch then btn.updateSwatch() end
        end

        EditMode.settingsDialog:ClearAllPoints()
        EditMode.settingsDialog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 305, -100)
        EditMode.settingsDialog:Show()

        UI:SetUnlocked(true)
        UI.dismissFrame:Show()
        UI:SetTestMode(true)
    end)

    --------------------------------------------------------
    -- Finalize
    --------------------------------------------------------
    self.frame = frame
    self:ApplySettings()
    self:SetVisible(true)
end

------------------------------------------------------------
-- Settings Application
------------------------------------------------------------
function UI:ApplySettings()
    local db = NextCast:GetModule("Core").db
    if not db then return end

    self.frame:SetScale(db.scale or 1.0)
    self.frame:SetAlpha(db.alpha or 1.0)

    -- Always apply position to ensure it's set correctly
    ApplyPosition(self.frame, db)
    EnsureOnScreen(self.frame)

    self.frame.keybind:SetTextHeight(db.keybindFontSize or 12)
    local kColor = db.keybindFontColor or { r = 1, g = 1, b = 1 }
    self.frame.keybind:SetTextColor(kColor.r, kColor.g, kColor.b)

    self.frame.cdText:SetTextHeight(db.cdFontSize or 18)
    local cColor = db.cdFontColor or { r = 1, g = 0.95, b = 0.6 }
    self.frame.cdText:SetTextColor(cColor.r, cColor.g, cColor.b)

    self.frame.keybind:SetShown(db.showKeybind)
    self.frame.cdText:SetShown(db.showCooldownText)
    self.frame.cooldown:SetDrawSwipe(db.showCooldownSwipe)
end

------------------------------------------------------------
-- Position Saving (Blizzard Grid Only)
------------------------------------------------------------
function UI:SavePosition()
    local db = NextCast:GetModule("Core").db
    if not db then return end

    local scale = self.frame:GetScale()
    local left = self.frame:GetLeft() * scale
    local bottom = self.frame:GetBottom() * scale

    -- Snap to Blizzard grid only
    if EditModeManagerFrame and EditModeManagerFrame.GetGridSpacing then
        local grid = EditModeManagerFrame:GetGridSpacing()
        if grid and grid > 0 then
            left = math.floor(left / grid + 0.5) * grid
            bottom = math.floor(bottom / grid + 0.5) * grid
        end
    end

    db.position.point = "BOTTOMLEFT"
    db.position.relativePoint = "BOTTOMLEFT"
    db.position.x = left
    db.position.y = bottom
end

------------------------------------------------------------
-- Visibility
------------------------------------------------------------
function UI:SetVisible(visible)
    if visible then self.frame:Show() else self.frame:Hide() end
end

------------------------------------------------------------
-- Unlock / Lock
------------------------------------------------------------
function UI:SetUnlocked(unlocked)
    self.isUnlocked = unlocked
    if unlocked then
        self.frame.editLabel:Show()
        self.frame.selectionBorder:Show()
    else
        self.frame.editLabel:Hide()
        self.frame.selectionBorder:Hide()
    end
end

function UI:CanMove()
    local db = NextCast:GetModule("Core").db
    return self.isUnlocked and db and db.locked == false
end

------------------------------------------------------------
-- Spell / Cooldown / Test Mode
------------------------------------------------------------
function UI:SetSpell(texture, keybind)
    if texture then
        self.frame.icon:SetTexture(texture)
        self.frame.keybind:SetText(keybind or "")
        self.frame.icon:Show()
        self.frame.bg:SetColorTexture(0, 0, 0, 0.35)
    else
        self.frame.icon:SetTexture(nil)
        self.frame.keybind:SetText("")
        self.frame.bg:SetColorTexture(0, 0, 0, 0.0)
    end
end

function UI:SetCooldown(startTime, duration, enabled)
    if enabled and duration and duration > 0 then
        self.frame.cooldown:SetCooldown(startTime, duration)
    else
        if CooldownFrame_Clear then
            CooldownFrame_Clear(self.frame.cooldown)
        else
            self.frame.cooldown:SetCooldown(0, 0)
        end
    end
end

function UI:SetTestMode(enabled)
    if enabled then
        self:SetSpell("Interface\\Icons\\INV_Misc_QuestionMark", "S1")
        self:SetCooldown(GetTime(), 10, true)
        self:SetCooldownText("10.0", 10.0)
    else
        self:SetSpell(nil, nil)
        self:SetCooldown(0, 0, false)
        self:SetCooldownText("")
    end
end

function UI:SetCooldownText(text, remaining)
    self.frame.cdText:SetText(text or "")

    local db = NextCast:GetModule("Core").db
    if remaining and db and db.cdWarningThreshold and remaining <= db.cdWarningThreshold then
        local color = db.cdWarningColor or { r = 1, g = 0, b = 0 }
        self.frame.cdText:SetTextColor(color.r, color.g, color.b)
    else
        self.frame.cdText:SetTextColor(1, 0.95, 0.6)
    end
end
