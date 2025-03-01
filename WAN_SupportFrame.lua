local _, wan = ...

local framePool = {}
local resizePool = {}
local unitTokensInFrames = {}
local frameReference = {}
local groupSupportFrame = CreateFrame("Frame")

local function GroupFrame_CompactPartyFrame()

    local groupUIParent = "CompactPartyFrameMember"
    local nGroupMembers = GetNumGroupMembers()
    if nGroupMembers > 0 then
        for i = 1, nGroupMembers do
            local groupTag = "group_" .. groupUIParent .. i
            local frameName = groupUIParent .. i
            local groupUIMember = _G[frameName]
            local groupUnitToken = groupUIMember and groupUIMember.unit
            if groupUnitToken then
                frameReference[groupTag] = groupUIMember
                unitTokensInFrames[groupUnitToken] = groupTag

                if not framePool[groupTag] then
                    framePool[groupTag] = CreateFrame("Frame", nil, groupUIMember)
                    resizePool[groupTag] = CreateFrame("Button", nil, framePool[groupTag])

                    wan.Options.Support.FrameSize = wan.Options.Support.FrameSize or {}
                    wan.Options.Support.FrameSize.width = wan.Options.Support.FrameSize.width or 30
                    wan.Options.Support.FrameSize.height = wan.Options.Support.FrameSize.height or 30
                    wan.SetResizableIconGroupFrame(
                        framePool[groupTag],
                        wan.Options.Support.HorizontalPosition,
                        wan.Options.Support.VerticalPosition,
                        wan.Options.Support.Toggle,
                        wan.Options.Support.FrameSize,
                        groupUIMember
                    )
                    wan.SetClickThroughFrame(framePool[groupTag], wan.Options.Support.Toggle)
                    wan.SetDragFrameGroup(framePool[groupTag], wan.Options.Support.Toggle, wan.Options.Support, groupUIMember)
                    wan.SetText1(framePool[groupTag], wan.Options.ShowName.Toggle)

                    framePool[groupTag].texture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                    framePool[groupTag].texture:SetAllPoints(framePool[groupTag])

                    framePool[groupTag].testtexture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                    framePool[groupTag].testtexture:SetAllPoints(framePool[groupTag])
                    framePool[groupTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    wan.SetTesterAlpha(framePool[groupTag], wan.Options.Support.Toggle, wan.Options.Support.AlphaSlider)

                    resizePool[groupTag]:SetPoint("BOTTOMRIGHT")
                    resizePool[groupTag]:SetSize(10, 10)
                    resizePool[groupTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                    resizePool[groupTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                    wan.SetResize(resizePool[groupTag], wan.Options.Support.Toggle)
                end

                if framePool[groupTag] then
                    framePool[groupTag]:Show()
                    resizePool[groupTag]:Show()
                end
            else
                if framePool[groupTag] then
                    framePool[groupTag]:Hide()
                    resizePool[groupTag]:Hide()
                end
            end
        end
    end
end

local function GroupFrame_PartyFrame()
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

            wan.Options.PlayerSupport.FrameSize = wan.Options.PlayerSupport.FrameSize or {}
            wan.Options.PlayerSupport.FrameSize.width = wan.Options.PlayerSupport.FrameSize.width or 40
            wan.Options.PlayerSupport.FrameSize.height = wan.Options.PlayerSupport.FrameSize.height or 40
            wan.SetResizableIconGroupFrame(
                framePool[playerTag],
                wan.Options.PlayerSupport.HorizontalPosition,
                wan.Options.PlayerSupport.VerticalPosition,
                wan.Options.PlayerSupport.Toggle,
                wan.Options.PlayerSupport.FrameSize,
                playerUIParent
            )
            wan.SetClickThroughFrame(framePool[playerTag], wan.Options.PlayerSupport.Toggle)
            wan.SetDragFrameGroup(framePool[playerTag], wan.Options.PlayerSupport.Toggle, wan.Options.PlayerSupport, playerUIParent)
            wan.SetText1(framePool[playerTag], wan.Options.ShowName.Toggle)

            framePool[playerTag].texture = framePool[playerTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
            framePool[playerTag].texture:SetAllPoints(framePool[playerTag])

            framePool[playerTag].testtexture = framePool[playerTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
            framePool[playerTag].testtexture:SetAllPoints(framePool[playerTag])
            framePool[playerTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            wan.SetTesterAlpha(framePool[playerTag], wan.Options.PlayerSupport.Toggle, wan.Options.PlayerSupport.AlphaSlider)

            resizePool[playerTag]:SetPoint("BOTTOMRIGHT")
            resizePool[playerTag]:SetSize(10, 10)
            resizePool[playerTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            resizePool[playerTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            wan.SetResize(resizePool[playerTag], wan.Options.PlayerSupport.Toggle)
        end

        for i = 1, nGroupMembers do
            local groupTag = "group_" .. groupUIParent .. i
            local groupUIMember = parentFrame[groupUIParent .. i]
            local groupUnitToken = groupUIMember and groupUIMember.unit
            if groupUnitToken then
                frameReference[groupTag] = groupUIMember
                unitTokensInFrames[groupUnitToken] = groupTag

                if not framePool[groupTag] then
                    framePool[groupTag] = CreateFrame("Frame", nil, groupUIMember)
                    resizePool[groupTag] = CreateFrame("Button", nil, framePool[groupTag])

                    wan.Options.Support.FrameSize = wan.Options.Support.FrameSize or {}
                    wan.Options.Support.FrameSize.width = wan.Options.Support.FrameSize.width or 30
                    wan.Options.Support.FrameSize.height = wan.Options.Support.FrameSize.height or 30
                    wan.SetResizableIconGroupFrame(
                        framePool[groupTag],
                        wan.Options.Support.HorizontalPosition,
                        wan.Options.Support.VerticalPosition,
                        wan.Options.Support.Toggle,
                        wan.Options.Support.FrameSize,
                        groupUIMember
                    )
                    wan.SetClickThroughFrame(framePool[groupTag], wan.Options.Support.Toggle)
                    wan.SetDragFrameGroup(framePool[groupTag], wan.Options.Support.Toggle, wan.Options.Support, groupUIMember)
                    wan.SetText1(framePool[groupTag], wan.Options.ShowName.Toggle)

                    framePool[groupTag].texture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                    framePool[groupTag].texture:SetAllPoints(framePool[groupTag])

                    framePool[groupTag].testtexture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                    framePool[groupTag].testtexture:SetAllPoints(framePool[groupTag])
                    framePool[groupTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    wan.SetTesterAlpha(framePool[groupTag], wan.Options.Support.Toggle, wan.Options.Support.AlphaSlider)

                    resizePool[groupTag]:SetPoint("BOTTOMRIGHT")
                    resizePool[groupTag]:SetSize(10, 10)
                    resizePool[groupTag]:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                    resizePool[groupTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                    wan.SetResize(resizePool[groupTag], wan.Options.Support.Toggle)
                end

                if framePool[groupTag] then
                    framePool[groupTag]:Show()
                    resizePool[groupTag]:Show()
                end
            else
                
                if framePool[groupTag] then
                    framePool[groupTag]:Hide()
                    resizePool[groupTag]:Hide()
                end
            end
        end

        if framePool[playerTag] and _G["CompactPartyFrame"]:IsShown() == false then
            framePool[playerTag]:Show()
            resizePool[playerTag]:Show()

        elseif framePool[playerTag] and _G["CompactPartyFrame"]:IsShown() == true then
            framePool[playerTag]:Hide()
            resizePool[playerTag]:Hide()
        end
    end
end

local function GroupFrames()
    if EditModeManagerFrame:UseRaidStylePartyFrames() then
        GroupFrame_CompactPartyFrame()
    else
        GroupFrame_PartyFrame()
    end
end

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    wan.RegisterBlizzardEvents(
        groupSupportFrame,
        "GROUP_ROSTER_UPDATE",
        "UPDATE_INSTANCE_INFO"
    )

    groupSupportFrame:SetScript("OnEvent", GroupFrames)
    hooksecurefunc(EditModeManagerFrame, "OnSystemSettingChange", GroupFrames)

    -- Icon Updater
    local last = 0
    local updateThrottle = 0.2
    self:SetScript("OnUpdate", function(self)
        if not last or last < GetTime() - updateThrottle then
            last = GetTime()
            updateThrottle = wan.UpdateFrameThrottle()
            if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode and not wan.PlayerState.InRaid then
                local playerTag = "group_player"
                local alphaValue = (wan.PlayerState.Combat and wan.Options.Support.AlphaSlider) or wan.Options.Support.CombatAlphaSlider
                local alphaValuePlayer = (wan.PlayerState.Combat and wan.Options.PlayerSupport.AlphaSlider) or wan.Options.PlayerSupport.CombatAlphaSlider
                local highestSpellData = wan.GetHighestSupportValues()
                for validGroupUnitToken, topSpellData in pairs(highestSpellData) do
                    local topValue, topIcon, topName, topDesat = topSpellData.value, topSpellData.icon, topSpellData.name, topSpellData.desat
                    local frameID = unitTokensInFrames[validGroupUnitToken]
                    if frameID then
                        if frameID ~= playerTag then
                            wan.IconUpdater(framePool[frameID], topIcon, topDesat, alphaValue)
                            wan.TextUpdater1(framePool[frameID], topName, wan.Options.Support.AlphaSlider)
                            wan.TextUpdater2(framePool[frameID], topValue, wan.Options.Support.AlphaSlider)
                        else
                            wan.IconUpdater(framePool[playerTag], topIcon, topDesat, alphaValuePlayer)
                            wan.TextUpdater1(framePool[playerTag], topName, wan.Options.PlayerSupport.AlphaSlider)
                            wan.TextUpdater2(framePool[playerTag], topValue, wan.Options.PlayerSupport.AlphaSlider)
                        end
                    end
                end
            end
        end
    end)
end

wan.EventFrame:HookScript("OnEvent", function(self, event,...)
    if event == "SUPPORT_FRAME_TOGGLE" or event == "PLAYER_SUPPORT_FRAME_TOGGLE" then
        local playerFrameID = "group_player"
        for groupMember, _ in pairs(framePool) do
            if groupMember ~= playerFrameID then
                wan.SetClickThroughFrame(framePool[groupMember], wan.Options.Support.Toggle)
                wan.SetDragFrameGroup(framePool[groupMember], wan.Options.Support.Toggle, wan.Options.Support, frameReference[groupMember])
                wan.SetResize(resizePool[groupMember], wan.Options.Support.Toggle)
                wan.SetAlpha(framePool[groupMember], wan.Options.Support.Toggle, wan.Options.Support.AlphaSlider)
                wan.SetTesterAlpha(framePool[groupMember], wan.Options.Support.Toggle, wan.Options.Support.AlphaSlider)
            else
                wan.SetClickThroughFrame(framePool[playerFrameID], wan.Options.PlayerSupport.Toggle)
                wan.SetDragFrameGroup(framePool[playerFrameID], wan.Options.PlayerSupport.Toggle, wan.Options.PlayerSupport, frameReference[playerFrameID])
                wan.SetResize(resizePool[playerFrameID], wan.Options.PlayerSupport.Toggle)
                wan.SetAlpha(framePool[playerFrameID], wan.Options.PlayerSupport.Toggle, wan.Options.PlayerSupport.AlphaSlider)
                wan.SetTesterAlpha(framePool[playerFrameID], wan.Options.PlayerSupport.Toggle, wan.Options.PlayerSupport.AlphaSlider)
            end
        end
    end

    if event == "TRAIT_DATA_READY" then
        for groupMember, _ in pairs(framePool) do
            wan.IconUpdater(framePool[groupMember], nil, nil, nil)
        end
    end

    if event == "FRAME_DRAG" or "FRAME_RESIZE" then
        local playerFrameID = "group_player"
        for groupMember, _ in pairs(framePool) do
            if groupMember ~= playerFrameID then
                wan.UpdatePositionGroup(
                    framePool[groupMember],
                    frameReference[groupMember],
                    wan.Options.Support.HorizontalPosition,
                    wan.Options.Support.VerticalPosition,
                    wan.Options.Support.FrameSize
                )
            else
                wan.UpdatePositionGroup(
                    framePool[playerFrameID],
                    frameReference[playerFrameID],
                    wan.Options.PlayerSupport.HorizontalPosition,
                    wan.Options.PlayerSupport.VerticalPosition,
                    wan.Options.PlayerSupport.FrameSize
                )
            end
        end
    end

    if event == "SUPPORT_FRAME_HORIZONTAL_SLIDER" or event == "SUPPORT_FRAME_VERTICAL_SLIDER"
    or event == "PLAYER_SUPPORT_FRAME_HORIZONTAL_SLIDER" or event == "PLAYER_SUPPORT_FRAME_VERTICAL_SLIDER" then
        local playerFrameID = "group_player"
        for groupMember, _ in pairs(framePool) do
            if groupMember ~= playerFrameID then
                framePool[groupMember]:SetPoint("CENTER", frameReference[groupMember], wan.Options.Support.HorizontalPosition, wan.Options.Support.VerticalPosition)
            else
                framePool[playerFrameID]:SetPoint("CENTER", frameReference[playerFrameID], wan.Options.PlayerSupport.HorizontalPosition, wan.Options.PlayerSupport.VerticalPosition)
            end
        end
    end

    if event == "NAME_TEXT_TOGGLE" then
        for groupMember, _ in pairs(framePool) do
            wan.SetText1(framePool[groupMember], wan.Options.ShowName.Toggle, wan.Options.Support.AlphaSlider)
        end
    end
end)

SLASH_WANSVALUE1 = "/wansv"
SlashCmdList["WANSVALUE"] = function()
    for groupMember, _ in pairs(framePool) do
        wan.SetText2(framePool[groupMember])
    end
end

groupSupportFrame:RegisterEvent("ADDON_LOADED")
groupSupportFrame:SetScript("OnEvent", OnEvent)