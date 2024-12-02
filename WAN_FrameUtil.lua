local _, wan = ...

-- Sets the update rate of the displays
function wan.UpdateFrameThrottle()
    local gcdValue = 1
    local _, gcdMS = GetSpellBaseCooldown(61304)
    if gcdMS then
        gcdValue = gcdMS / 1000
    end
    local setting = 8
    if wan.Options.UpdateRate.Toggle then
        setting = wan.Options.UpdateRate.Slider * 2
    else
        setting = 8
    end
    return gcdValue / setting
end

function wan.SetResizableIconFrame(frame, xPosition, yPosition, enabler, savedVariable)
    local settings = enabler or true
    local frameWidth = savedVariable.width
    local frameHeight = savedVariable.height

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", xPosition, yPosition)
    frame:SetSize(frameWidth, frameHeight)
    frame:EnableMouse(settings)
    frame:SetMovable(settings)
    frame:SetResizable(true)
    frame:SetResizeBounds(20, 20, 100, 100)
    frame:SetScript("OnSizeChanged", function(frame, width, height)
        if width ~= height then frame:SetHeight(width) end
        savedVariable.width, savedVariable.height = frame:GetSize()
    end)
end

function wan.SetResizableIconGroupFrame(frame, xPosition, yPosition, enabler, savedVariable, relativeTo)
    local settings = enabler or true
    local frameWidth = savedVariable.width
    local frameHeight = savedVariable.height

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", relativeTo, xPosition, yPosition)
    frame:SetSize(frameWidth, frameHeight)
    frame:EnableMouse(settings)
    frame:SetMovable(settings)
    frame:SetResizable(true)
    frame:SetResizeBounds(20, 20, 100, 100)
    frame:HookScript("OnSizeChanged", function(frame, width, height)
        if width ~= height then frame:SetHeight(width) end
        savedVariable.width, savedVariable.height = frame:GetSize()
    end)
end

function wan.SetClickThroughFrame(frame, enabler)
    local enablePropagation = not enabler
    frame:SetPropagateMouseMotion(enablePropagation)
    frame:SetPropagateMouseClicks(enablePropagation)
end

function wan.SetDragFrame(frame, enabler, savedPosition)
    local isDraggable = enabler
    if isDraggable then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then self:StartMoving() end
        end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                self:StopMovingOrSizing()
                local _, _, _, x, y = frame:GetPoint()
                savedPosition.HorizontalPosition = x
                savedPosition.VerticalPosition = y
            end
        end)
    else
        frame:RegisterForDrag()
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnMouseUp", nil)
    end
end

function wan.SetDragFrameGroup(frame, enabler, savedPosition, anchorFrame)
    local isDraggable = enabler
    if isDraggable then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then self:StartMoving() end
        end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                self:StopMovingOrSizing()

                local parentX, parentY = anchorFrame:GetCenter()
                local frameX, frameY = self:GetCenter()
                local relativeX = frameX - parentX
                local relativeY = frameY - parentY

                savedPosition.HorizontalPosition = relativeX
                savedPosition.VerticalPosition = relativeY
                wan.CustomEvents("FRAME_DRAG")

                self:ClearAllPoints()
                self:SetPoint("CENTER", anchorFrame, "CENTER", relativeX, relativeY)
            end
        end)
    else
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnMouseUp", nil)
    end
end

function wan.UpdatePositionGroup(frame, relativeTo, xPosition, yPosition, size)
    local width = size.width
    local height = size.height
    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", relativeTo, "CENTER", xPosition, yPosition)
end


function wan.SetResize(frame, enabler)
    if enabler then
        frame:SetScript("OnMouseDown", function(frame) frame:GetParent():StartSizing("BOTTOMRIGHT") end)
        frame:SetScript("OnMouseUp", function(frame) frame:GetParent():StopMovingOrSizing()
            wan.CustomEvents("FRAME_RESIZE")
         end)
        frame:SetAlpha(1)
    else
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnMouseUp", nil)
        frame:SetScript("OnSizeChanged", nil)
        frame:SetAlpha(0)
    end
end

function wan.IconUpdater(frame, icon, desaturation, alpha)
    if icon then
        frame.texture:SetTexture(icon)
        frame.texture:SetAlpha(alpha)
    else
        frame.texture:SetAlpha(0)
    end
    if desaturation then
        frame.texture:SetDesaturated(desaturation)
    else
        frame.texture:SetDesaturated(false)
    end
end

function wan.SetText1(frame, enabler, alpha)
    local textAlpha = alpha or 0.75
    if enabler and not frame.text1 then
        frame.text1 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text1:SetPoint("BOTTOM", frame, "BOTTOM", 0, -15)
    end

    if frame.text1 then
        if enabler then
            frame.text1:SetAlpha(textAlpha)
            frame.text1:Show()
        else
            frame.text1:Hide()
        end
    end
end

function wan.TextUpdater1(frame, value, alpha)
    local textAlpha = alpha or 0.75
    if value and frame.text1 then
        frame.text1:SetText(tostring(value))
        frame.text1:SetAlpha(textAlpha)
    elseif frame.text1 then
        frame.text1:SetAlpha(0)
    end
end

function wan.SetText2(frame)
    if not frame.text2 then
        frame.text2 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text2:SetPoint("TOP", frame, "TOP", 0, 15)
        frame.text2:Hide()  -- Start hidden
        frame.text2Visible = false
    end

    frame.text2Visible = not frame.text2Visible
    frame.text2:SetShown(frame.text2Visible)
end



function wan.TextUpdater2(frame, value, alpha)
    local textAlpha = alpha or 0.75
    if value and frame.text2 then
        frame.text2:SetText(tostring(value))
        frame.text2:SetAlpha(textAlpha)
    elseif frame.text2 then
        frame.text2:SetAlpha(0)
    end
end

function wan.SetAlpha(frame, enabler, setting)
    if enabler == false then 
        frame.texture:SetAlpha(0)
    else
        frame.texture:Show()
        frame.texture:SetAlpha(setting)
    end
end

function wan.SetTesterAlpha(frame, enabler, setting)
    if enabler == true then 
        frame.testtexture:Show()
        frame.testtexture:SetAlpha(setting)
    else
        frame.testtexture:SetAlpha(0)
    end
end

function wan.FormatDecimalNumbers(value)
    return math.floor(value)
end

function wan.GetHighestAbilityValues()
    local highestValue = 0
    local highestSpell = nil
    for _, data in pairs(wan.AbilityData) do
        if data.value and data.value >= highestValue then
            highestValue = data.value
            highestSpell = data
        end
    end

    if highestSpell then
        return highestSpell.value, highestSpell.icon, highestSpell.name, highestSpell.desat
    end
end

function wan.GetHighestMechanicValues()
    local highestValue = 0
    local highestSpell = nil
    for _, data in pairs(wan.MechanicData) do
        if data.value and data.value >= highestValue then
            highestValue = data.value
            highestSpell = data
        end
    end

    if highestSpell then
        return highestSpell.value, highestSpell.icon, highestSpell.name, highestSpell.desat
    end
end

function wan.GetHighestHealingValues()
    local highestValuesForUnitToken = {}
    for groupUnitToken, _ in pairs(wan.HealingData) do
        local highestValue = 0
        highestValuesForUnitToken[groupUnitToken] = {}
        for _, healingValues in pairs(wan.HealingData[groupUnitToken]) do
            if healingValues.value and healingValues.value >= highestValue then
                highestValue = healingValues.value
                highestValuesForUnitToken[groupUnitToken] = healingValues
            end
        end
    end

    return highestValuesForUnitToken
end