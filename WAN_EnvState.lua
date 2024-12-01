local _, wan = ...

-- Init unitID arrays
wan.TargetUnitID = {}
wan.NameplateUnitID = {}
wan.GroupUnitID = {}
wan.GUIDMap = {}

-- Init player status arrays
wan.PlayerState = {}
wan.PlayerState.InHealerMode = false
wan.PlayerState.Class = UnitClassBase("player") or "UNKNOWN"
wan.PlayerState.InGroup = false
wan.PlayerState.Status = false
wan.PlayerState.Combat = false
wan.CritChance = GetCritChance() or 0
wan.Haste = GetHaste() or 0
local isDeadOrGhost, isMounted, inVehicle


local function OnEvent(self, event, ...)

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
        local groupType = UnitInRaid("player") and "raid" or "party"
        local nGroupUnits = GetNumGroupMembers()
        local activeUnits = {}

        -- noticable performance drop when the game assigns group unit tokens en masse
        -- haven't found a way to go around this yet...
        if nGroupUnits > 0 then
            wan.PlayerState.InGroup = true
            for i = 1, nGroupUnits do
                local unit = groupType .. i
                local groupGUID = UnitGUID(unit)
                if groupGUID then
                    local validToken = wan.GUIDMap[groupGUID]
                    if not validToken or validToken ~= unit then
                        local unitToken = groupGUID and UnitTokenFromGUID(groupGUID)
                        if unitToken and not unitToken:find("^" .. groupType) then
                            local unitNumber = unitToken:match("%d+")
                                unitToken = unitNumber and groupType .. unitNumber
                        end
                        if groupGUID and unitToken then
                            wan.GroupUnitID[unitToken] = groupGUID
                            wan.GUIDMap[groupGUID] = unitToken
                            activeUnits[groupGUID] = unitToken
                        end
                    end
                end
            end
        else
            wan.PlayerState.InGroup = false
            wan.GroupUnitID = {}
            wan.GUIDMap = {}
        end

        -- wipe data on removed group units
        for guid, unitToken in pairs(activeUnits) do
            if not wan.GroupUnitID[unitToken] then
                wan.GroupUnitID[unitToken] = nil
                wan.GUIDMap[guid] = nil
                wan.auraData[unitToken] = nil
                wan.instanceIDMap[unitToken] = nil
                wan.instanceIDThrottler[unitToken] = nil
            end
        end
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

    if event == "VEHICLE_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
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
        wan.TargetUnitID = nil
        wan.NameplateUnitID = nil
        wan.GroupUnitID = nil
        wan.GUIDMap = nil

        wan.PlayerState.Class = nil
        wan.PlayerState.InHealerMode = nil
        wan.PlayerState.Status = nil
        wan.PlayerState.Combat = nil
        wan.PlayerState.InGroup = nil
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
    "VEHICLE_UPDATE",
    "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_LOGOUT",
    "UNIT_AURA",
    "PLAYER_ENTERING_WORLD",
    "CVAR_UPDATE",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "GROUP_ROSTER_UPDATE",
    "GROUP_FORMED",
    "GROUP_JOINED",
    "GROUP_LEFT"
)
stateFrame:SetScript("OnEvent", OnEvent)
