local _, wan = ...

local groupHealingFrame = CreateFrame("Frame")

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    local framePool = {}
    local resizePool = {}
    local unitTokensInFrames = {}


    local function GroupFrames()
        local nGroupMembers = GetNumGroupMembers()
        if nGroupMembers > 0 then
            for i = 1, nGroupMembers do
                local groupMember = "group" .. i
                local groupUIMember = _G["CompactPartyFrameMember" .. i]
                local groupUnitToken = groupUIMember and groupUIMember.unit
                if groupUIMember then
                    unitTokensInFrames[groupUnitToken] = groupMember

                    if not framePool[groupMember] then
                        framePool[groupMember] = CreateFrame("Frame", nil, groupUIMember)
                        resizePool[groupMember] = CreateFrame("Button", nil, framePool[groupMember])

                        wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                        if wan.Options.Heal.FrameSize.width == nil then wan.Options.Heal.FrameSize.width = 20 end
                        if wan.Options.Heal.FrameSize.height == nil then wan.Options.Heal.FrameSize.height = 20 end
                        wan.SetResizableIconFrame(
                            framePool[groupMember],
                            wan.Options.Heal.HorizontalPosition,
                            wan.Options.Heal.VerticalPosition,
                            wan.Options.Heal.Toggle,
                            wan.Options.Heal.FrameSize
                        )
                        wan.SetClickThroughFrame(framePool[groupMember], wan.Options.Heal.Toggle)
                        wan.SetDragFrame(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal)
                        wan.SetText1(framePool[groupMember], wan.Options.ShowName.Toggle)
                    
                        framePool[groupMember].texture = framePool[groupMember]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupMember].texture:SetAllPoints(framePool[groupMember])
                        framePool[groupMember].texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    
                        framePool[groupMember].testtexture = framePool[groupMember]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupMember].testtexture:SetAllPoints(framePool[groupMember])
                        framePool[groupMember].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        wan.SetTesterAlpha(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)

                        resizePool[groupMember]:SetPoint("BOTTOMRIGHT")
                        resizePool[groupMember]:SetSize(10, 10)
                        resizePool[groupMember]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                        resizePool[groupMember]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                        wan.SetResize(resizePool[groupMember], wan.Options.Heal.Toggle)
                    end

                    if framePool[groupMember] and not framePool[groupMember]:IsShown() then
                        framePool[groupMember]:Show()
                        resizePool[groupMember]:Show()
                    end
                else
                    framePool[groupMember]:Hide()
                    resizePool[groupMember]:Hide()
                    unitTokensInFrames[groupUnitToken] = nil
                end
            end
        end
    end

    wan.RegisterBlizzardEvents(
        groupHealingFrame,
        "GROUP_ROSTER_UPDATE"
    )

    groupHealingFrame:SetScript("OnEvent", GroupFrames)

    -- Icon Updater
    local last = 0
    local updateThrottle = 0.2
    self:SetScript("OnUpdate", function(self)
        if not last or last < GetTime() - updateThrottle then
            last = GetTime()
            updateThrottle = wan.UpdateFrameThrottle()
            local alphaValue = (wan.PlayerState.Combat and wan.Options.Heal.AlphaSlider) or wan.Options.Heal.CombatAlphaSlider
            local highestSpellData = wan.GetHighestHealingValues()
            for validGroupUnitToken, topSpellData in pairs(highestSpellData) do
                local topValue, topIcon, topName, topDesat = topSpellData.value, topSpellData.icon, topSpellData.name, topSpellData.desat
                if unitTokensInFrames[validGroupUnitToken] then
                    wan.IconUpdater(framePool[validGroupUnitToken], topIcon, topDesat, alphaValue)
                    wan.TextUpdater1(framePool[validGroupUnitToken], topName, wan.Options.Heal.AlphaSlider)
                    wan.TextUpdater2(framePool[validGroupUnitToken], topValue, wan.Options.Heal.AlphaSlider)                   
                end
            end
        end
    end)

    wan.EventFrame:HookScript("OnEvent", function(self, event,...)
        if event == "HEAL_FRAME_TOGGLE" then
            for groupMember, _ in pairs(framePool) do
                wan.SetClickThroughFrame(framePool[groupMember], wan.Options.Heal.Toggle)
                wan.SetDragFrame(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal)
                wan.SetAlpha(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)
                wan.SetTesterAlpha(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)
            end
            
            for groupMember, _ in pairs(resizePool) do
                wan.SetResize(resizePool[groupMember], wan.Options.Heal.Toggle)
            end
        end

        if event == "TRAIT_DATA_READY" then
            for groupMember, _ in pairs(framePool) do
                wan.IconUpdater(framePool[groupMember], nil, nil, nil)
            end
        end

        if event == "HEAL_FRAME_DRAG" then
            for groupMember, _ in pairs(framePool) do
                wan.SetDragFrame(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal)
                framePool[groupMember]:SetPoint("CENTER", wan.Options.Heal.HorizontalPosition, wan.Options.Heal.VerticalPosition)
            end
        end

        if event == "HEAL_FRAME_HORIZONTAL_SLIDER" or event == "HEAL_FRAME_VERTICAL_SLIDER" then
            for groupMember, _ in pairs(framePool) do
                framePool[groupMember]:SetPoint("CENTER", wan.Options.Heal.HorizontalPosition, wan.Options.Heal.VerticalPosition)
            end
        end

        if event == "NAME_TEXT_TOGGLE" then
            for groupMember, _ in pairs(framePool) do
                wan.SetText1(framePool[groupMember], wan.Options.ShowName.Toggle, wan.Options.Heal.AlphaSlider)
            end
        end
    end)

    SLASH_WANHVALUE1 = "/wanhv"
    SlashCmdList["WANHVALUE"] = function()
        for groupMember, _ in pairs(framePool) do
            wan.SetText2(framePool[groupMember])
        end
    end
end

groupHealingFrame:RegisterEvent("ADDON_LOADED")
groupHealingFrame:SetScript("OnEvent", OnEvent)