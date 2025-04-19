local _, wan = ...

local framePool = {}
local resizePool = {}
local unitTokensInFrames = {}
local frameReference = {}
local raidHealingFrame = CreateFrame("Frame")

local function GroupFrame_CompactRaidFrame()

    local groupUIParent = "CompactRaidFrame"
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

                    wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                    wan.Options.Heal.FrameSize.width = wan.Options.Heal.FrameSize.width or 30
                    wan.Options.Heal.FrameSize.height = wan.Options.Heal.FrameSize.height or 30
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

local function GroupFrame_CompactRaidGroup()
    local parentFrame = "CompactRaidGroup"
    local groupUIParent = "Member"
    for raidGroupIndex = 1, 8 do
        local raidGroups = _G[parentFrame .. raidGroupIndex]
        if raidGroups then
            local groupIndex = parentFrame .. raidGroupIndex
            for raidSubGroupIndex = 1, 5 do
                local groupMemberIndex = groupIndex .. groupUIParent .. raidSubGroupIndex
                local groupTag = "group_" .. groupMemberIndex
                local groupUIMember = _G[groupMemberIndex]
                local groupUnitToken = groupUIMember and groupUIMember.unit
                if groupUnitToken then
                    frameReference[groupTag] = groupUIMember
                    unitTokensInFrames[groupUnitToken] = groupTag

                    if not framePool[groupTag] then
                        framePool[groupTag] = CreateFrame("Frame", nil, groupUIMember)
                        resizePool[groupTag] = CreateFrame("Button", nil, framePool[groupTag])

                        wan.Options.Heal.FrameSize = wan.Options.Heal.FrameSize or {}
                        wan.Options.Heal.FrameSize.width = wan.Options.Heal.FrameSize.width or 30
                        wan.Options.Heal.FrameSize.height = wan.Options.Heal.FrameSize.height or 30
                        wan.SetResizableIconGroupFrame(
                            framePool[groupTag],
                            wan.Options.Heal.HorizontalPosition,
                            wan.Options.Heal.VerticalPosition,
                            wan.Options.Heal.Toggle,
                            wan.Options.Heal.FrameSize,
                            groupUIMember
                        )
                        wan.SetClickThroughFrame(framePool[groupTag], wan.Options.Heal.Toggle)
                        wan.SetDragFrameGroup(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal,
                            groupUIMember)
                        wan.SetText1(framePool[groupTag], wan.Options.ShowName.Toggle)

                        framePool[groupTag].texture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].texture:SetAllPoints(framePool[groupTag])

                        framePool[groupTag].testtexture = framePool[groupTag]:CreateTexture(nil, "BACKGROUND", nil, 0)
                        framePool[groupTag].testtexture:SetAllPoints(framePool[groupTag])
                        framePool[groupTag].testtexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        wan.SetTesterAlpha(framePool[groupTag], wan.Options.Heal.Toggle, wan.Options.Heal
                        .AlphaSlider)

                        resizePool[groupTag]:SetPoint("BOTTOMRIGHT")
                        resizePool[groupTag]:SetSize(10, 10)
                        resizePool[groupTag]:SetHighlightTexture(
                        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
                        resizePool[groupTag]:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
                        wan.SetResize(resizePool[groupTag], wan.Options.Heal.Toggle)
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
end

local function GroupFrames()
    if EditModeManagerFrame:ShouldRaidFrameShowSeparateGroups() then
        GroupFrame_CompactRaidGroup()
    else
        GroupFrame_CompactRaidFrame()
    end
end

local function OnEvent(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    wan.RegisterBlizzardEvents(
        raidHealingFrame,
        "GROUP_ROSTER_UPDATE",
        "UPDATE_INSTANCE_INFO"
    )

    raidHealingFrame:SetScript("OnEvent", GroupFrames)
    hooksecurefunc(EditModeManagerFrame, "OnSystemSettingChange", GroupFrames)

    -- Icon Updater
    local last = 0
    local updateThrottle = 0.2
    self:SetScript("OnUpdate", function(self)
        if not last or last < GetTime() - updateThrottle then
            last = GetTime()
            updateThrottle = wan.UpdateFrameThrottle()
            if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode and wan.PlayerState.InRaid then
                local alphaValue = (wan.PlayerState.Combat and wan.Options.Heal.AlphaSlider) or wan.Options.Heal.CombatAlphaSlider
                local highestSpellData = wan.GetHighestHealingValues()
                for validGroupUnitToken, topSpellData in pairs(highestSpellData) do
                    local topValue, topIcon, topName, topDesat = topSpellData.value, topSpellData.icon, topSpellData.name, topSpellData.desat
                    local frameID = unitTokensInFrames[validGroupUnitToken]
                    if frameID then
                        wan.IconUpdater(framePool[frameID], topIcon, topDesat, alphaValue)
                        wan.TextUpdater1(framePool[frameID], topName, wan.Options.Heal.AlphaSlider)
                        wan.TextUpdater2(framePool[frameID], topValue, wan.Options.Heal.AlphaSlider)
                    end
                end
            end
        end
    end)
end

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
            wan.UpdatePositionGroup(
                framePool[groupMember],
                frameReference[groupMember],
                wan.Options.Heal.HorizontalPosition,
                wan.Options.Heal.VerticalPosition,
                wan.Options.Heal.FrameSize
            )
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

SLASH_WANRHVALUE1 = "/wanhv"
SlashCmdList["WANRHVALUE"] = function()
    for groupMember, _ in pairs(framePool) do
        wan.SetText2(framePool[groupMember])
    end
end

raidHealingFrame:RegisterEvent("ADDON_LOADED")
raidHealingFrame:SetScript("OnEvent", OnEvent)