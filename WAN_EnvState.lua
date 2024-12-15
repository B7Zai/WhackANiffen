local _, wan = ...

-- Init unitID arrays
wan.TargetUnitID = {}
wan.NameplateUnitID = {}
wan.GroupUnitID = {}

-- Init status arrays
wan.PlayerState = {}
wan.PlayerState.InHealerMode = false
wan.PlayerState.Class = UnitClassBase("player") or "UNKNOWN"
wan.PlayerState.InGroup = false
wan.PlayerState.Status = false
wan.PlayerState.Combat = false
wan.PlayerState.GUID = "guid"
wan.CritChance = GetCritChance() or 0
wan.Haste = GetHaste() or 0

wan.UnitState = {}
wan.UnitState.MaxHealth = {}
wan.UnitState.IsAI = {}
wan.UnitState.Level = {}
wan.UnitState.LevelScale = {}

local isDeadOrGhost, isMounted, inVehicle
local function OnEvent(self, event, ...)

    if event == "PLAYER_ENTERING_WORLD" then
        wan.UnitState.Level.player = UnitLevel("player")
        wan.UnitState.LevelScale.player = 1
        wan.PlayerState.GUID = UnitGUID("player")
        wan.UnitState.MaxHealth.player = UnitHealthMax("player") or 0
    end

    -- sets unit token for targeting
    if event == "PLAYER_ENTERING_WORLD" or (event == "CVAR_UPDATE" and ... == "SoftTargetEnemy") then
        local targetSetting = C_CVar.GetCVar("SoftTargetEnemy")
        wan.TargetUnitID = tonumber(targetSetting) == 3 and "softenemy" or "target"
    end

    -- adds and removes nameplate unit tokens
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitID = ...
        wan.NameplateUnitID[unitID] = unitID
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitID = ...
        wan.NameplateUnitID[unitID] = nil
    end

    -- assigns group unit tokens for group
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        print("group update")
        local groupType = UnitInRaid("player") and "raid" or "party"
        local nGroupUnits = GetNumGroupMembers()
        local _, _, _, difficultyName = GetInstanceInfo()
        local isLevelScaling = difficultyName and difficultyName == "Timewalking" or false
        local activeUnits = {}

        -- noticable performance drop when the game assigns group unit tokens en masse
        -- haven't found a way to go around this yet...
        if nGroupUnits > 0 then
            wan.PlayerState.InGroup = true
            for i = 1, nGroupUnits do
                local unit = groupType .. i
                local groupGUID = UnitGUID(unit)
                if groupGUID then
                    local unitToken = UnitTokenFromGUID(groupGUID)
                    if unitToken ~= "player" then
                        if not unitToken:find("^" .. groupType) then
                            local unitNumber = unitToken:match("%d+")
                            unitToken = unitNumber and groupType .. unitNumber
                        end

                        local isAI = UnitInPartyIsAI(unitToken) or false
                        local maxHealth = UnitHealthMax(unitToken) or 0
                        local unitLevel = UnitLevel(unitToken) or wan.UnitState.Level.player

                        wan.GroupUnitID[unitToken] = groupGUID
                        activeUnits[groupGUID] = unitToken

                        wan.UnitState.LevelScale[unitToken] = 1
                        wan.UnitState.MaxHealth[unitToken] = maxHealth
                        wan.UnitState.Level[unitToken] = unitLevel
                        wan.UnitState.IsAI[unitToken] = isAI

                        if isLevelScaling then
                            if wan.UnitState.Level[unitToken] ~= wan.UnitState.Level.player then
                                local levelScaleValue = wan.UnitState.MaxHealth[unitToken] / wan.UnitState.MaxHealth.player
                                wan.UnitState.LevelScale[unitToken] = levelScaleValue
                            end
                        end
                    end
                end
            end
            local playerGUID = wan.PlayerState.GUID
            local playerUnitToken = "player"
            if playerGUID then
                wan.GroupUnitID[playerUnitToken] = playerGUID
                activeUnits[playerGUID] = playerUnitToken
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

                wan.auraData[unitToken] = nil
                wan.instanceIDMap[unitToken] = nil
                wan.instanceIDThrottler[unitToken] = nil

                wan.HealingData[unitToken] = nil
                wan.SupportData[unitToken] = nil
                wan.HotValue[unitToken] = nil

                wan.UnitState.IsAI[unitToken] = nil
                wan.UnitState.MaxHealth[unitToken] = nil
                wan.UnitState.Level[unitToken] = nil
                wan.UnitState.LevelScale[unitToken] = nil
            end
        end
    end

    if event == "UPDATE_INSTANCE_INFO" or event == "UNIT_LEVEL"then
        print("updating instance info")
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

    if (event == "UNIT_MAXHEALTH" and ... == "player") or (event == "UNIT_MAXHEALTH" and wan.GroupUnitID[...]) then
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
        local _, _, _, _, role = wan.GetTraitInfo()
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
    "UNIT_MAXHEALTH",
    "UNIT_LEVEL"
)
stateFrame:SetScript("OnEvent", OnEvent)
