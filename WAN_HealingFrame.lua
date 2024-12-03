local _, wan = ...

local groupHealingFrame = CreateFrame("Frame")

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    local framePool = {}
    local resizePool = {}
    local unitTokensInFrames = {}
    local frameReference = {}


    local function GroupFrame_CompactParty()
        
        local groupUIParent = "CompactPartyFrameMember"
        local nGroupMembers = GetNumGroupMembers()
        if nGroupMembers > 0 then
            for i = 1, nGroupMembers do
                local groupTag = "group_" .. groupUIParent .. i
                local frameName = groupUIParent .. i
                local groupUIMember = _G[frameName]
                local groupUnitToken = groupUIMember and groupUIMember.unit
                if groupUIMember then
                    frameReference[groupTag] = groupUIMember
                    unitTokensInFrames[groupUnitToken] = groupTag

                    if not framePool[groupTag] then
                        framePool[groupTag] = CreateFrame("Frame", nil, groupUIMember)
                        resizePool[groupTag] = CreateFrame("Button", nil, framePool[groupTag])

                        wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                        if wan.Options.Heal.FrameSize.width == nil then wan.Options.Heal.FrameSize.width = 40 end
                        if wan.Options.Heal.FrameSize.height == nil then wan.Options.Heal.FrameSize.height = 40 end
                        wan.SetResizableIconGroupFrame(
                            framePool[groupTag],
                            wan.Options.Heal.HorizontalPosition,
                            wan.Options.Heal.VerticalPosition,
                            wan.Options.Heal.Toggle,
                            wan.Options.Heal.FrameSize,
                            groupUIMember
                        )
                        wan.SetClickThroughFrame(framePool[groupTag], wan.Options.Heal.Toggle)
                        wan.SetDragFrameGroup(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal, groupUIMember)
                        wan.SetText1(framePool[groupTag], wan.Options.ShowName.Toggle)
                    
                        framePool[groupTag].texture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].texture:SetAllPoints(framePool[groupTag])
                        framePool[groupTag].texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    
                        framePool[groupTag].testtexture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].testtexture:SetAllPoints(framePool[groupTag])
                        framePool[groupTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        wan.SetTesterAlpha(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)

                        resizePool[groupTag]:SetPoint("BOTTOMRIGHT")
                        resizePool[groupTag]:SetSize(10, 10)
                        resizePool[groupTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                        resizePool[groupTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                        wan.SetResize(resizePool[groupTag], wan.Options.Heal.Toggle)
                    end

                    if framePool[groupTag] and not framePool[groupTag]:IsShown() then
                        framePool[groupTag]:Show()
                        resizePool[groupTag]:Show()
                    end
                else
                    if framePool[groupTag] then
                        framePool[groupTag]:Hide()
                        resizePool[groupTag]:Hide()
                        frameReference[groupTag] = nil
                        unitTokensInFrames[groupUnitToken] = nil
                    end
                end
            end
        end
    end

    local function GroupFrame_Party()
        local parentFrame = _G["PartyFrame"]
        local groupUIParent = "MemberFrame"

        local nGroupMembers = GetNumGroupMembers()
        if nGroupMembers > 0 then
            local playerTag = "group_player"
            local playerUIParent = _G["PlayerFrame"]
            local playerUnitToken = "player"

            frameReference[playerTag] = playerUIParent
            unitTokensInFrames[playerUnitToken] = playerTag

            if not framePool[playerTag] then
                framePool[playerTag] = CreateFrame("Frame", nil, playerUIParent)
                resizePool[playerTag] = CreateFrame("Button", nil, framePool[playerTag])

                wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                if wan.Options.Heal.FrameSize.width == nil then wan.Options.Heal.FrameSize.width = 40 end
                if wan.Options.Heal.FrameSize.height == nil then wan.Options.Heal.FrameSize.height = 40 end
                wan.SetResizableIconGroupFrame(
                    framePool[playerTag],
                    wan.Options.Heal.HorizontalPosition,
                    wan.Options.Heal.VerticalPosition,
                    wan.Options.Heal.Toggle,
                    wan.Options.Heal.FrameSize,
                    playerUIParent
                )
                wan.SetClickThroughFrame(framePool[playerTag], wan.Options.Heal.Toggle)
                wan.SetDragFrameGroup(framePool[playerTag], wan.Options.Heal.Toggle, wan.Options.Heal, playerUIParent)
                wan.SetText1(framePool[playerTag], wan.Options.ShowName.Toggle)

                framePool[playerTag].texture = framePool[playerTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                framePool[playerTag].texture:SetAllPoints(framePool[playerTag])
                framePool[playerTag].texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

                framePool[playerTag].testtexture = framePool[playerTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                framePool[playerTag].testtexture:SetAllPoints(framePool[playerTag])
                framePool[playerTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                wan.SetTesterAlpha(framePool[playerTag], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)

                resizePool[playerTag]:SetPoint("BOTTOMRIGHT")
                resizePool[playerTag]:SetSize(10, 10)
                resizePool[playerTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                resizePool[playerTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                wan.SetResize(resizePool[playerTag], wan.Options.Heal.Toggle)
            end

            for i = 1, nGroupMembers do
                local groupTag = "group_" .. groupUIParent .. i
                local groupUIMember = parentFrame[groupUIParent .. i]
                local groupUnitToken = groupUIMember and groupUIMember.unit
                if groupUIMember then
                    frameReference[groupTag] = groupUIMember
                    unitTokensInFrames[groupUnitToken] = groupTag

                    if not framePool[groupTag] then
                        framePool[groupTag] = CreateFrame("Frame", nil, groupUIMember)
                        resizePool[groupTag] = CreateFrame("Button", nil, framePool[groupTag])

                        wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                        if wan.Options.Heal.FrameSize.width == nil then wan.Options.Heal.FrameSize.width = 40 end
                        if wan.Options.Heal.FrameSize.height == nil then wan.Options.Heal.FrameSize.height = 40 end
                        wan.SetResizableIconGroupFrame(
                            framePool[groupTag],
                            wan.Options.Heal.HorizontalPosition,
                            wan.Options.Heal.VerticalPosition,
                            wan.Options.Heal.Toggle,
                            wan.Options.Heal.FrameSize,
                            groupUIMember
                        )
                        wan.SetClickThroughFrame(framePool[groupTag], wan.Options.Heal.Toggle)
                        wan.SetDragFrameGroup(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal, groupUIMember)
                        wan.SetText1(framePool[groupTag], wan.Options.ShowName.Toggle)
                    
                        framePool[groupTag].texture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].texture:SetAllPoints(framePool[groupTag])
                        framePool[groupTag].texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    
                        framePool[groupTag].testtexture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].testtexture:SetAllPoints(framePool[groupTag])
                        framePool[groupTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        wan.SetTesterAlpha(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal.AlphaSlider)

                        resizePool[groupTag]:SetPoint("BOTTOMRIGHT")
                        resizePool[groupTag]:SetSize(10, 10)
                        resizePool[groupTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                        resizePool[groupTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                        wan.SetResize(resizePool[groupTag], wan.Options.Heal.Toggle)
                    end

                    if framePool[groupTag] and not framePool[groupTag]:IsShown() then
                        framePool[groupTag]:Show()
                        resizePool[groupTag]:Show()
                    end
                else
                    if framePool[groupTag] then
                        framePool[groupTag]:Hide()
                        resizePool[groupTag]:Hide()
                        frameReference[groupTag] = nil
                        unitTokensInFrames[groupUnitToken] = nil
                    end
                end
            end

            if _G["CompactPartyFrame"]:IsShown() == false then
                if framePool[playerTag] and not framePool[playerTag]:IsShown() then
                    framePool[playerTag]:Show()
                    resizePool[playerTag]:Show()
                end
            else
                framePool[playerTag]:Hide()
                resizePool[playerTag]:Hide()
                frameReference[playerTag] = nil
                unitTokensInFrames[playerUnitToken] = nil
            end
        end
    end

    local function GroupFrames()
        GroupFrame_CompactParty()
        GroupFrame_Party()
    end

    wan.RegisterBlizzardEvents(
        groupHealingFrame,
        "GROUP_ROSTER_UPDATE",
        "PLAYER_FOCUS_CHANGED"
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