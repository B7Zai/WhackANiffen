local _, wan = ...

local mechanicFrame = CreateFrame("Frame")
local resizeFrame = CreateFrame("Button", nil, mechanicFrame)

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    wan.Options.Mechanic.FrameSize = wan.Options.Mechanic.FrameSize or {}
    if wan.Options.Mechanic.FrameSize.width == nil then wan.Options.Mechanic.FrameSize.width = 45 end
    if wan.Options.Mechanic.FrameSize.height == nil then wan.Options.Mechanic.FrameSize.height = 45 end
    wan.SetResizableIconFrame(
        self,
        wan.Options.Mechanic.HorizontalPosition,
        wan.Options.Mechanic.VerticalPosition,
        wan.Options.Mechanic.Toggle,
        wan.Options.Mechanic.FrameSize
    )
    wan.SetClickThroughFrame(self, wan.Options.Mechanic.Toggle)
    wan.SetDragFrame(self, wan.Options.Mechanic.Toggle, wan.Options.Mechanic)
    wan.SetText1(self, wan.Options.ShowName.Toggle)

    self.texture = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    self.texture:SetAllPoints(self)
    self.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    self.testtexture = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    self.testtexture:SetAllPoints(self)
    self.testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    wan.SetTesterAlpha(self, wan.Options.Mechanic.Toggle, wan.Options.Mechanic.AlphaSlider)

    resizeFrame:SetPoint("BOTTOMRIGHT")
    resizeFrame:SetSize(15, 15)
    resizeFrame:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeFrame:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    wan.SetResize(resizeFrame, wan.Options.Mechanic.Toggle)

    -- Icon Updater
    local last = 0
    local updateThrottle = 0.2
    self:SetScript("OnUpdate", function(self)
        if not last or last < GetTime() - updateThrottle then
            last = GetTime()
            updateThrottle = wan.UpdateFrameThrottle()
            local topValue, topIcon, topName, topDesat = wan.GetHighestMechanicValues()
            local alphaValue = (wan.PlayerState.Combat and wan.Options.Mechanic.AlphaSlider) or wan.Options.Mechanic.CombatAlphaSlider
            wan.IconUpdater(self, topIcon, topDesat, alphaValue)
            wan.TextUpdater1(self, topName)
            wan.TextUpdater2(self, topValue)
        end
    end)
end

wan.EventFrame:HookScript("OnEvent", function(self, event,...)
    if event == "MECHANIC_FRAME_TOGGLE" then
        wan.SetClickThroughFrame(mechanicFrame, wan.Options.Mechanic.Toggle)
        wan.SetDragFrame(mechanicFrame, wan.Options.Mechanic.Toggle, wan.Options.Mechanic)
        wan.SetResize(resizeFrame, wan.Options.Mechanic.Toggle)
        wan.SetAlpha(mechanicFrame, wan.Options.Mechanic.Toggle, wan.Options.Mechanic.AlphaSlider)
        wan.SetTesterAlpha(mechanicFrame, wan.Options.Mechanic.Toggle, wan.Options.Mechanic.AlphaSlider)
    end

    if event == "TRAIT_DATA_READY" then
        wan.IconUpdater(mechanicFrame, nil, nil, nil)
    end

    if event == "MECHANIC_FRAME_HORIZONTAL_SLIDER" or event == "MECHANIC_FRAME_VERTICAL_SLIDER" then
        mechanicFrame:SetPoint("CENTER", wan.Options.Mechanic.HorizontalPosition, wan.Options.Mechanic.VerticalPosition)
    end

    if event == "NAME_TEXT_TOGGLE" then
        wan.SetText1(mechanicFrame, wan.Options.ShowName.Toggle)
    end
end)

SLASH_WANMVALUE1 = "/wanmv"
SlashCmdList["WANMVALUE"] = function()
    wan.SetText2(mechanicFrame)
end

mechanicFrame:RegisterEvent("ADDON_LOADED")
mechanicFrame:SetScript("OnEvent", OnEvent)