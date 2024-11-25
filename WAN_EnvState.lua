local _, wan = ...

wan.TargetUnitID = wan.TargetUnitID or "target"
wan.PlayerState = wan.PlayerState or {}
wan.PlayerState.Class = UnitClassBase("player")
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

    if event == "PLAYER_ENTERING_WORLD" or (event == "CVAR_UPDATE" and ... == "SoftTargetEnemy") then
        local targetSetting = C_CVar.GetCVar("SoftTargetEnemy")
        wan.TargetUnitID = tonumber(targetSetting) == 3 and "softenemy" or "target"
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
    "PLAYER_REGEN_ENABLED"
)
stateFrame:SetScript("OnEvent", OnEvent)
