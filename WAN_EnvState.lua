local _, wan = ...

-- Init unitID arrays
wan.TargetUnitID = {}
wan.NameplateUnitID = {}
wan.GroupUnitID = {}
wan.GUIDMap = {}

-- Init player status arrays
wan.PlayerState = wan.PlayerState or {}
wan.PlayerState.Class, wan.PlayerState.ClassID = UnitClassBase("player")
wan.PlayerState.Status = false
wan.PlayerState.Combat = false
wan.CritChance = GetCritChance() or 0
wan.Haste = GetHaste() or 0

local isDeadOrGhost, isMounted, inVehicle
local function UpdatePlayerStatus()
    wan.PlayerState.Status = not (isDeadOrGhost or isMounted or inVehicle)
end

local function OnEvent(self, event, ...)
    local unit = "player"

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
        local nGroupUnits = GetNumGroupMembers() - 1
        local activeUnits = {}

        -- noticable performance drop when the game assigns group unit tokens en masse
        -- haven't found a way to go around this yet...
        if nGroupUnits > 0 and groupType then
            for i = 1, nGroupUnits do
                local unit = groupType .. i
                local groupGUID = UnitGUID(unit)
                if groupGUID then
                    local validToken = wan.GUIDMap[groupGUID]
                    if not validToken or validToken ~= unit then
                        local unitToken = groupGUID and UnitTokenFromGUID(groupGUID)
                        if groupGUID and unitToken and unitToken ~= "player" and unitToken:find("^" .. groupType) then
                            print("Creating unit token: " .. unitToken)
                            wan.GroupUnitID[unitToken] = unitToken
                            wan.GUIDMap[groupGUID] = unitToken
                            activeUnits[groupGUID] = unitToken
                        end
                    end
                end
            end
        end

        for guid, unitToken in pairs(activeUnits) do
            if not wan.GroupUnitID[unitToken] then
                print("Deleting unit token: " .. unitToken)
                wan.GroupUnitID[unitToken] = nil
                wan.GUIDMap[guid] = nil
            end
        end
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_DEAD" or event == "PLAYER_ENTERING_WORLD" then
        isDeadOrGhost = UnitIsDeadOrGhost(unit)
        UpdatePlayerStatus()
    end

    if (event == "UNIT_AURA" and ... == "player") or event == "PLAYER_ENTERING_WORLD" or
        (event == "UPDATE_SHAPESHIFT_FORM" and wan.PlayerState.Class == "DRUID") then
        isMounted = IsMounted() or GetShapeshiftForm() == 3
        UpdatePlayerStatus()
    end

    if event == "VEHICLE_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        inVehicle = UnitInVehicle(unit) or UnitHasVehicleUI(unit)
        UpdatePlayerStatus()
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
        wan.PlayerState.Status = false
        wan.CritChance = 0
        wan.Haste = 0
    end
end

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
    "GROUP_ROSTER_UPDATE"
)
stateFrame:SetScript("OnEvent", OnEvent)
