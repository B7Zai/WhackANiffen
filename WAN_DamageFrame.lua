local _, wan = ...

local damageFrame = CreateFrame("Frame")
local resizeFrame = CreateFrame("Button", nil, damageFrame)

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    wan.Options.Damage.FrameSize = wan.Options.Damage.FrameSize or {}
    if wan.Options.Damage.FrameSize.width == nil then wan.Options.Damage.FrameSize.width = 45 end
    if wan.Options.Damage.FrameSize.height == nil then wan.Options.Damage.FrameSize.height = 45 end
    wan.SetResizableIconFrame(
        self,
        wan.Options.Damage.HorizontalPosition,
        wan.Options.Damage.VerticalPosition,
        wan.Options.Damage.Toggle,
        wan.Options.Damage.FrameSize
    )
    wan.SetClickThroughFrame(self, wan.Options.Damage.Toggle)
    wan.SetDragFrame(self, wan.Options.Damage.Toggle, wan.Options.Damage)
    wan.SetText1(self, wan.Options.ShowName.Toggle)

    self.texture = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    self.texture:SetAllPoints(self)
    self.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    self.testtexture = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    self.testtexture:SetAllPoints(self)
    self.testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    wan.SetTesterAlpha(self, wan.Options.Damage.Toggle, wan.Options.Damage.AlphaSlider)

    resizeFrame:SetPoint("BOTTOMRIGHT")
    resizeFrame:SetSize(15, 15)
    resizeFrame:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeFrame:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    wan.SetResize(resizeFrame, wan.Options.Damage.Toggle)

    -- Icon Updater
    local last = 0
    local updateThrottle = 0.2
    self:SetScript("OnUpdate", function(self)
        if not last or last < GetTime() - updateThrottle then
            last = GetTime()
            updateThrottle = wan.UpdateFrameThrottle()
            local topValue, topIcon, topName, topDesat = wan.GetHighestAbilityValues()
            local alphaValue = (wan.PlayerState.Combat and wan.Options.Damage.AlphaSlider) or wan.Options.Damage.CombatAlphaSlider
            wan.IconUpdater(self, topIcon, topDesat, alphaValue)
            wan.TextUpdater1(self, topName, wan.Options.Damage.AlphaSlider)
            wan.TextUpdater2(self, topValue, wan.Options.Damage.AlphaSlider)
        end
    end)

    wan.EventFrame:HookScript("OnEvent", function(self, event,...)
        if event == "DAMAGE_FRAME_TOGGLE" then
            wan.SetClickThroughFrame(damageFrame, wan.Options.Damage.Toggle)
            wan.SetDragFrame(damageFrame, wan.Options.Damage.Toggle, wan.Options.Damage)
            wan.SetResize(resizeFrame, wan.Options.Damage.Toggle)
            wan.SetAlpha(damageFrame, wan.Options.Damage.Toggle, wan.Options.Damage.AlphaSlider)
            wan.SetTesterAlpha(damageFrame, wan.Options.Damage.Toggle, wan.Options.Damage.AlphaSlider)
        end

        if event == "DAMAGE_FRAME_HORIZONTAL_SLIDER" or event == "DAMAGE_FRAME_VERTICAL_SLIDER" then
            damageFrame:SetPoint("CENTER", wan.Options.Damage.HorizontalPosition, wan.Options.Damage.VerticalPosition)
        end

        if event == "NAME_TEXT_TOGGLE" then
            wan.SetText1(damageFrame, wan.Options.ShowName.Toggle, wan.Options.Damage.AlphaSlider)
        end
    end)

    SLASH_WANDVALUE1 = "/wandv"
    SlashCmdList["WANDVALUE"] = function()
        wan.SetText2(damageFrame)
    end
end

damageFrame:RegisterEvent("ADDON_LOADED")
damageFrame:SetScript("OnEvent", OnEvent)