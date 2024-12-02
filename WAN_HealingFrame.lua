local _, wan = ...

local groupHealingFrame = CreateFrame("Frame")

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    local framePool = {}
    local resizePool = {}
    local unitTokensInFrames = {}
    local frameReference = {}


    local function GroupFrames()
        local nGroupMembers = GetNumGroupMembers()
        if nGroupMembers > 0 then
            for i = 1, nGroupMembers do
                local groupMember = "group" .. i
                local frameName = "CompactPartyFrameMember" .. i
                local groupUIMember = _G[frameName]
                local groupUnitToken = groupUIMember and groupUIMember.unit
                if groupUIMember then
                    frameReference[groupMember] = groupUIMember
                    unitTokensInFrames[groupUnitToken] = groupMember

                    if not framePool[groupMember] then
                        framePool[groupMember] = CreateFrame("Frame", nil, groupUIMember)
                        resizePool[groupMember] = CreateFrame("Button", nil, framePool[groupMember])

                        wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                        if wan.Options.Heal.FrameSize.width == nil then wan.Options.Heal.FrameSize.width = 40 end
                        if wan.Options.Heal.FrameSize.height == nil then wan.Options.Heal.FrameSize.height = 40 end
                        wan.SetResizableIconGroupFrame(
                            framePool[groupMember],
                            wan.Options.Heal.HorizontalPosition,
                            wan.Options.Heal.VerticalPosition,
                            wan.Options.Heal.Toggle,
                            wan.Options.Heal.FrameSize,
                            groupUIMember
                        )
                        wan.SetClickThroughFrame(framePool[groupMember], wan.Options.Heal.Toggle)
                        wan.SetDragFrameGroup(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal, groupUIMember)
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
                    frameReference[groupMember] = nil
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
                local frameNumber = unitTokensInFrames[validGroupUnitToken]
                wan.IconUpdater(framePool[frameNumber], topIcon, topDesat, alphaValue)
                wan.TextUpdater1(framePool[frameNumber], topName, wan.Options.Heal.AlphaSlider)
                wan.TextUpdater2(framePool[frameNumber], topValue, wan.Options.Heal.AlphaSlider)
            end
        end
    end)

    wan.EventFrame:HookScript("OnEvent", function(self, event,...)
        if event == "HEAL_FRAME_TOGGLE" then
            for groupMember, _ in pairs(framePool) do
                wan.SetClickThroughFrame(framePool[groupMember], wan.Options.Heal.Toggle)
                wan.SetDragFrameGroup(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal, frameReference[groupMember])
                wan.SetResize(resizePool[groupMember], wan.Options.Heal.Toggle)
                wan.SetAlpha(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)
                wan.SetTesterAlpha(framePool[groupMember], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)
            end
        end

        if event == "TRAIT_DATA_READY" then
            for groupMember, _ in pairs(framePool) do
                wan.IconUpdater(framePool[groupMember], nil, nil, nil)
            end
        end

        if event == "FRAME_DRAG" or "FRAME_RESIZE" then
            for groupMember, _ in pairs(framePool) do
                if frameReference[groupMember] then
                    wan.UpdatePositionGroup(
                        framePool[groupMember],
                        frameReference[groupMember],
                        wan.Options.Heal.HorizontalPosition,
                        wan.Options.Heal.VerticalPosition,
                        wan.Options.Heal.FrameSize
                    )
                end
            end
        end

        if event == "HEAL_FRAME_HORIZONTAL_SLIDER" or event == "HEAL_FRAME_VERTICAL_SLIDER" then
            for groupMember, _ in pairs(framePool) do
                framePool[groupMember]:SetPoint("CENTER", frameReference[groupMember], wan.Options.Heal.HorizontalPosition, wan.Options.Heal.VerticalPosition)
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