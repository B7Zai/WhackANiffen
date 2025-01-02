local _, wan = ...

-- Init unitID arrays
wan.TargetUnitID = "target"
wan.NameplateUnitID = {}
wan.GroupUnitID = {}

-- Init status arrays
wan.PlayerState = {}
wan.PlayerState.InHealerMode = false
wan.PlayerState.Class = UnitClassBase("player") or "UNKNOWN"
wan.PlayerState.InGroup = false
wan.PlayerState.InRaid = false
wan.PlayerState.Status = false
wan.PlayerState.Combat = false
wan.PlayerState.GUID = UnitGUID("player")
wan.PlayerState.Role = "DAMAGER"
wan.PlayerState.SpecializationName = "specName"
wan.CritChance = GetCritChance() or 0
wan.Haste = GetHaste() or 0

wan.TargetUnitID = "target"
wan.UnitState = {}
wan.UnitState.GUID = {}
wan.UnitState.Health = {}
wan.UnitState.MaxHealth = {}
wan.UnitState.IsAI = {}
wan.UnitState.Level = {}
wan.UnitState.LevelScale = {}
wan.UnitState.Role = {}
wan.UnitState.Classification = {}

setmetatable(wan.UnitState.Health, {
    __index = function(t, key)
        local default = 0
        t[key] = default
        return default
    end
})

local isDeadOrGhost, isMounted, inVehicle
local function OnEvent(self, event, ...)

    if event == "PLAYER_ENTERING_WORLD" then
        wan.UnitState.Level.player = UnitLevel("player")
        wan.UnitState.LevelScale.player = 1
        
        local playerGUID = wan.PlayerState.GUID
        if playerGUID then
            wan.UnitState.MaxHealth[playerGUID] = UnitHealthMax("player") or 0
        end
    end

    -- sets unit token for targeting
    if event == "PLAYER_ENTERING_WORLD" or (event == "CVAR_UPDATE" and ... == "SoftTargetEnemy") then
        local targetSetting = C_CVar.GetCVar("SoftTargetEnemy")
        wan.TargetUnitID = tonumber(targetSetting) == 3 and "softenemy" or "target"
    end

    if event == "PLAYER_SOFT_ENEMY_CHANGED" then
        wan.UnitState.Health[wan.TargetUnitID] = nil
        wan.UnitState.GUID[wan.TargetUnitID] = nil

        local health = UnitHealth(wan.TargetUnitID) or 0
        local unitGUID = UnitGUID(wan.TargetUnitID)

        wan.UnitState.Health[wan.TargetUnitID] = health
        wan.UnitState.GUID[wan.TargetUnitID] = unitGUID

        wan.CustomEvents("TARGET_UNITID_ASSIGNED")
    end

    -- adds and removes nameplate unit tokens
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...
        local unitClassification = UnitClassification(unitToken)
        local health = UnitHealth(unitToken) or 0
        local unitGUID = UnitGUID(unitToken)

        wan.NameplateUnitID[unitToken] = unitGUID
        wan.UnitState.Health[unitToken] = health

        if unitClassification then
            wan.UnitState.Classification[unitToken] = unitClassification
        end

        wan.CustomEvents("NAMEPLATE_UNITID_ASSIGNED", unitToken)
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        local unitToken = ...
        local unitGUID = wan.NameplateUnitID[unitToken]

        wan.auraData[unitGUID] = nil
        wan.instanceIDMap[unitGUID] = nil
        wan.NameplateUnitID[unitToken] = nil
        wan.UnitState.Classification[unitToken] = nil
        wan.UnitState.Health[unitToken] = nil
    end

    -- assigns group unit tokens for group
    if event == "GROUP_ROSTER_UPDATE" or event == "ROLE_CHANGED_INFORM" or event == "PLAYER_ENTERING_WORLD" then
        local groupType = UnitInRaid("player") and "raid" or "party"
        wan.PlayerState.InRaid = groupType == "raid" or false
        local _, _, _, difficultyName = GetInstanceInfo()
        local isLevelScaling = difficultyName and difficultyName == "Timewalking" or false
        local nGroupMembers = GetNumGroupMembers()
        local activeUnits = {}

        if nGroupMembers > 0 then
            wan.PlayerState.InGroup = true
            if groupType == "raid" then
                if EditModeManagerFrame:ShouldRaidFrameShowSeparateGroups() then
                    local parentFrame = "CompactRaidGroup"
                    local groupUIParent = "Member"
                    for raidGroupIndex = 1, 8 do
                        local raidGroups = _G[parentFrame .. raidGroupIndex]
                        if raidGroups then
                            local groupIndex = parentFrame .. raidGroupIndex
                            for raidSubGroupIndex = 1, 5 do
                                local groupMemberIndex = groupIndex .. groupUIParent .. raidSubGroupIndex
                                local groupUIMember = _G[groupMemberIndex]
                                if groupUIMember then
                                    local active = wan.AssignUnitState(groupUIMember, isLevelScaling)
                                    for guid, token in pairs(active) do
                                        activeUnits[guid] = token
                                    end
                                end
                            end
                        end
                    end
                else
                    local groupUIParent = "CompactRaidFrame"
                    for i = 1, nGroupMembers do
                        local frameName = groupUIParent .. i
                        local groupUIMember = _G[frameName]
                        if groupUIMember then
                            local active = wan.AssignUnitState(groupUIMember, isLevelScaling)
                            for guid, token in pairs(active) do
                                activeUnits[guid] = token
                            end
                        end
                    end
                end
            elseif groupType == "party" then
                if EditModeManagerFrame:UseRaidStylePartyFrames() then
                    local groupUIParent = "CompactPartyFrameMember"
                    for i = 1, nGroupMembers do
                        local frameName = groupUIParent .. i
                        local groupUIMember = _G[frameName]
                        if groupUIMember then
                            local active = wan.AssignUnitState(groupUIMember, isLevelScaling)
                            for guid, token in pairs(active) do
                                activeUnits[guid] = token
                            end
                        end
                    end
                else
                    local playerUIParent = _G["PlayerFrame"]
                    if playerUIParent then
                        local active = wan.AssignUnitState(playerUIParent, isLevelScaling)
                        for guid, token in pairs(active) do
                            activeUnits[guid] = token
                        end
                    end

                    local parentFrame = _G["PartyFrame"]
                    local groupUIParent = "MemberFrame"
                    for i = 1, nGroupMembers do
                        local groupUIMember = parentFrame[groupUIParent .. i]
                        if groupUIMember then
                            local active = wan.AssignUnitState(playerUIParent, isLevelScaling)
                            for guid, token in pairs(active) do
                                activeUnits[guid] = token
                            end
                        end
                    end
                end
            end
        else
            wan.PlayerState.InGroup = false
            wan.HotValue = {}
            wan.GroupUnitID = {}
            wan.UnitState.IsAI = {}
        end

        -- wipe data on removed group units
        for unitToken, unitGUID in pairs(wan.GroupUnitID) do
            if not activeUnits[unitGUID] then
                wan.GroupUnitID[unitToken] = nil

                wan.auraData[unitGUID] = nil
                wan.instanceIDMap[unitGUID] = nil

                wan.HealingData[unitToken] = nil
                wan.SupportData[unitToken] = nil
                wan.HotValue[unitToken] = nil

                wan.UnitState.IsAI[unitToken] = nil
                wan.UnitState.MaxHealth[unitToken] = nil
                wan.UnitState.Level[unitToken] = nil
                wan.UnitState.LevelScale[unitToken] = nil
                wan.UnitState.Role[unitToken] = nil
            end
        end

        wan.CustomEvents("GROUP_UNITID_ASSIGNED")
    end

    if event == "UPDATE_INSTANCE_INFO" or event == "UNIT_LEVEL" then
        local _, _, _, difficultyName = GetInstanceInfo()
        local isLevelScaling = difficultyName and difficultyName == "Timewalking" or false
        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            if isLevelScaling then
                if wan.UnitState.Level[groupUnitToken] ~= wan.UnitState.Level.player then
                    local levelScaleValue = wan.UnitState.MaxHealth[groupUnitToken] / wan.UnitState.MaxHealth.player
                    wan.UnitState.LevelScale[groupUnitToken] = levelScaleValue
                end
            else
                wan.UnitState.LevelScale[groupUnitToken] = 1
            end
        end
    end

    if event == "UNIT_HEALTH" and (wan.NameplateUnitID[...] or ... == wan.TargetUnitID) then
        local unitToken = ...
        local health = UnitHealth(unitToken) or 0
        wan.UnitState.Health[unitToken] = health
    end

    if event == "UNIT_MAXHEALTH" and (wan.GroupUnitID[...] or ... == "player")  then
        local unitToken = ...
        local maxHealth = UnitHealthMax(unitToken) or 0
        wan.UnitState.MaxHealth[unitToken] = maxHealth
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_DEAD" or event == "PLAYER_ENTERING_WORLD" then
        isDeadOrGhost = UnitIsDeadOrGhost("player")
        wan.PlayerState.Status = not (isDeadOrGhost or isMounted or inVehicle)
    end

    if (event == "UNIT_AURA" and ... == "player") or event == "PLAYER_ENTERING_WORLD" or
        (event == "UPDATE_SHAPESHIFT_FORM" and wan.PlayerState.Class == "DRUID") then
        isMounted = IsMounted() or GetShapeshiftForm() == 3
        wan.PlayerState.Status = not (isDeadOrGhost or isMounted or inVehicle)
    end

    if (event == "UNIT_ENTERING_VEHICLE" and ... == "player") or (event == "UNIT_EXITING_VEHICLE" and ... == "player")
    or event == "PLAYER_ENTERING_WORLD" then
        inVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")
        wan.PlayerState.Status = not (isDeadOrGhost or isMounted or inVehicle)
    end

    if event == "PLAYER_REGEN_DISABLED" then
        wan.PlayerState.Combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        wan.PlayerState.Combat = false
    end

    if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        wan.CritChance = GetCritChance()
        wan.Haste = GetHaste()
    end

    if event == "PLAYER_LOGOUT" then
        wan.traitData = nil
        wan.spellData = nil
        wan.auraData = nil

        wan.TargetUnitID = nil
        wan.NameplateUnitID = nil
        wan.GroupUnitID = nil

        wan.PlayerState = nil
        wan.UnitState = nil
        wan.CritChance = nil
        wan.Haste = nil
    end
end

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "TRAIT_DATA_READY" or event == "HEALERMODE_FRAME_TOGGLE" then
        local _, name, _, _, role = wan.GetTraitInfo()
        wan.PlayerState.SpecializationName = name
        wan.PlayerState.Role = role
        wan.PlayerState.InHealerMode = role == "HEALER" or wan.Options.HealerMode.Toggle
    end
end)

local stateFrame = CreateFrame("Frame")
wan.RegisterBlizzardEvents(stateFrame,
    "PLAYER_ALIVE",
    "PLAYER_DEAD",
    "UNIT_ENTERING_VEHICLE",
    "UNIT_EXITING_VEHICLE",
    "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_LOGOUT",
    "UNIT_AURA",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_INSTANCE_INFO",
    "CVAR_UPDATE",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "GROUP_ROSTER_UPDATE",
    "ROLE_CHANGED_INFORM",
    "UNIT_MAXHEALTH",
    "UNIT_HEALTH",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_SOFT_ENEMY_CHANGED",
    "UNIT_LEVEL"
)
stateFrame:SetScript("OnEvent", OnEvent)
