local _, wan = ...

-- Init unitID arrays
wan.TargetUnitID = "target"
wan.NameplateUnitID = {}
wan.GroupUnitID = {}

-- Init player status arrays
wan.PlayerState = {}
wan.PlayerState.Class = UnitClassBase("player") or "UNKNOWN"
wan.PlayerState.Combat = false
wan.PlayerState.GUID = UnitGUID("player")
wan.PlayerState.InGroup = false
wan.PlayerState.InHealerMode = false
wan.PlayerState.InRaid = false
wan.PlayerState.InVehicle = false
wan.PlayerState.IsDead = false
wan.PlayerState.Mounted = false
wan.PlayerState.Resting = false
wan.PlayerState.Role = "DAMAGER"
wan.PlayerState.SpecializationName = "specName"
wan.PlayerState.Status = false
wan.CritChance = GetCritChance() or 0
wan.Haste = GetHaste() or 0

-- Init unit status arrays
wan.UnitState = {}
wan.UnitState.Class = {}
wan.UnitState.Classification = {}
wan.UnitState.GUID = {}
wan.UnitState.Health = {}
wan.UnitState.IsAI = {}
wan.UnitState.Level = {}
wan.UnitState.LevelScale = {}
wan.UnitState.MaxHealth = {}
wan.UnitState.Role = {}

local function OnEvent(self, event, ...)

    -- init player data
    if event == "PLAYER_ENTERING_WORLD" then
        local playerUnitToken = "player"
        local petUnitToken = "pet"

        wan.PlayerState.GUID = wan.PlayerState.GUID or UnitGUID(playerUnitToken)
        wan.PlayerState.Resting = IsResting()

        wan.UnitState.Health[playerUnitToken] = UnitHealth(playerUnitToken)
        wan.UnitState.Level[playerUnitToken] = UnitLevel(playerUnitToken)
        wan.UnitState.LevelScale[playerUnitToken] = 1
        wan.UnitState.MaxHealth[playerUnitToken] = UnitHealthMax(playerUnitToken) or 0

        wan.UnitState.GUID[petUnitToken] = UnitGUID(petUnitToken)
        wan.UnitState.MaxHealth[petUnitToken] = UnitHealthMax(petUnitToken) or 0
    end

    -- assign GUID for pets
    if event == "UNIT_PET" then
        local unitToken = "pet"
        local unitGUID = UnitGUID(unitToken)
        local maxHealth = UnitHealthMax(unitToken) or 0
        local unitExists = UnitExists(unitToken)

        if not unitExists then
            wan.auraData[unitToken] = nil
            wan.instanceIDMap[unitToken] = nil
            wan.UnitState.GUID[unitToken] = nil
            wan.UnitState.MaxHealth[unitToken] = nil
        end

        wan.UnitState.GUID[unitToken] = unitGUID
        wan.UnitState.MaxHealth[unitToken] = maxHealth

        wan.CustomEvents("PET_UNITID_ASSIGNED")
    end

    -- assigns unit token for targeting
    if event == "PLAYER_ENTERING_WORLD" or (event == "CVAR_UPDATE" and ... == "SoftTargetEnemy") then
        local targetSetting = C_CVar.GetCVar("SoftTargetEnemy")
        wan.TargetUnitID = tonumber(targetSetting) == 3 and "softenemy" or "target"
    end

    -- adds and removes various data for target
    if event == "PLAYER_SOFT_ENEMY_CHANGED" then
        local unitToken = wan.TargetUnitID
        local unitGUID = UnitGUID(unitToken)
        local health = UnitHealth(unitToken) or 0
        local unitLevel = UnitLevel(unitToken)
        local unitClassification = UnitClassification(unitToken) or "normal"
        local unitExists = UnitExists(unitToken)
        local unitPlayer = UnitIsPlayer(unitToken)

        if not unitExists then
            wan.auraData[unitToken] = nil
            wan.instanceIDMap[unitToken] = nil
            wan.UnitState.GUID[unitToken] = nil
            wan.UnitState.Health[unitToken] = nil
            wan.UnitState.Level[unitToken] = nil
            wan.UnitState.Classification[unitToken] = nil
            wan.UnitState.Class[unitToken] = nil
        end

        wan.UnitState.GUID[unitToken] = unitGUID
        wan.UnitState.Health[unitToken] = health
        wan.UnitState.Level[unitToken] = unitLevel
        wan.UnitState.Classification[unitToken] = unitClassification
        wan.UnitState.Class[unitToken] = unitPlayer and UnitClassBase(unitToken) or false
        
        wan.CustomEvents("TARGET_UNITID_ASSIGNED")
    end

    -- assigns unit tokens and adds various data for nameplates
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...
        local unitClassification = UnitClassification(unitToken) or "normal"
        local health = UnitHealth(unitToken) or 0
        local unitGUID = UnitGUID(unitToken)
        local unitPlayer = UnitIsPlayer(unitToken)

        wan.UnitState.Health[unitToken] = health
        wan.UnitState.Classification[unitToken] = unitClassification
        wan.UnitState.Class[unitToken] = unitPlayer and UnitClassBase(unitToken) or false

        if unitGUID then
            wan.NameplateUnitID[unitToken] = unitGUID
        end

        wan.CustomEvents("NAMEPLATE_UNITID_ASSIGNED", unitToken)
    end

    -- removes unit tokens and wipes various data for nameplates
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local unitToken = ...

        wan.auraData[unitToken] = nil
        wan.instanceIDMap[unitToken] = nil
        wan.UnitState.Health[unitToken] = nil
        wan.UnitState.Classification[unitToken] = nil
        wan.UnitState.Class[unitToken] = nil
        
        wan.NameplateUnitID[unitToken] = nil
    end

    -- assigns group unit tokens and adds various data for each member
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
            if unitToken ~= "player" and not activeUnits[unitGUID] then
                wan.GroupUnitID[unitToken] = nil

                wan.HealingData[unitToken] = nil
                wan.SupportData[unitToken] = nil
                wan.HotValue[unitToken] = nil

                wan.auraData[unitToken] = nil
                wan.instanceIDMap[unitToken] = nil

                wan.UnitState.IsAI[unitToken] = nil
                wan.UnitState.MaxHealth[unitToken] = nil
                wan.UnitState.Level[unitToken] = nil
                wan.UnitState.LevelScale[unitToken] = nil
                wan.UnitState.Role[unitToken] = nil
            end
        end

        wan.CustomEvents("GROUP_UNITID_ASSIGNED")
    end

    -- update group member levels and assigns level scaling value if level scaling is active
    if event == "UPDATE_INSTANCE_INFO" or event == "UNIT_LEVEL" then
        local _, _, _, difficultyName = GetInstanceInfo()
        local isLevelScaling = difficultyName and difficultyName == "Timewalking" or false
        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            wan.UnitState.LevelScale[groupUnitToken] = 1

            if isLevelScaling then
                if wan.UnitState.Level[groupUnitToken] ~= wan.UnitState.Level.player then
                    local levelScaleValue = wan.UnitState.MaxHealth[groupUnitToken] / wan.UnitState.MaxHealth.player
                    wan.UnitState.LevelScale[groupUnitToken] = levelScaleValue
                end
            end
        end
    end

    -- updates current health of tracked units
    if event == "UNIT_HEALTH" and (wan.NameplateUnitID[...] or ... == wan.TargetUnitID or ... == "player") then
        local unitToken = ...
        local health = UnitHealth(unitToken) or 0

        wan.UnitState.Health[unitToken] = health
    end

    -- updates max health of player and group members
    if event == "UNIT_MAXHEALTH" and (wan.GroupUnitID[...] or ... == "player" or ... == "pet") then
        local unitToken = ...
        local maxHealth = UnitHealthMax(unitToken) or 0

        wan.UnitState.MaxHealth[unitToken] = maxHealth
    end

    -- combat state update for the player
    if event == "PLAYER_REGEN_DISABLED" then
        wan.PlayerState.Combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        wan.PlayerState.Combat = false
    end

    if event == "PLAYER_UPDATE_RESTING" then
        wan.PlayerState.Resting = IsResting()
    end

    -- checks if the player is dead or not
    if event == "PLAYER_ALIVE" or event == "PLAYER_DEAD" or event == "PLAYER_ENTERING_WORLD" then
        wan.PlayerState.IsDead = UnitIsDeadOrGhost("player")
        wan.PlayerState.Status = wan.PlayerState.IsDead or not wan.PlayerState.Mounted or wan.PlayerState.InVehicle
    end

    -- checks if the player is in a vehicle
    if (event == "UNIT_ENTERING_VEHICLE" and ... == "player") or (event == "UNIT_EXITING_VEHICLE" and ... == "player")
    or event == "PLAYER_ENTERING_WORLD" then
        wan.PlayerState.InVehicle = UnitInVehicle("player") or UnitHasVehicleUI("player")
        wan.PlayerState.Status = wan.PlayerState.IsDead or not wan.PlayerState.Mounted or wan.PlayerState.InVehicle
    end

    -- checks if the player is mounted
    if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        wan.PlayerState.Mounted = IsMounted() or wan.PlayerState.Class == "DRUID" and GetShapeshiftForm() == 3
        wan.PlayerState.Status = wan.PlayerState.IsDead or not wan.PlayerState.Mounted or wan.PlayerState.InVehicle

        wan.CritChance = GetCritChance()
        wan.Haste = GetHaste()
    end

    -- wipe data tables when the player is logging out
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
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SOFT_ENEMY_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_UPDATE_RESTING",

    "UNIT_AURA",
    "UNIT_ENTERING_VEHICLE",
    "UNIT_EXITING_VEHICLE",
    "UNIT_HEALTH",
    "UNIT_LEVEL",
    "UNIT_MAXHEALTH",
    "UNIT_PET",

    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",

    "GROUP_ROSTER_UPDATE",
    "ROLE_CHANGED_INFORM",
    "UPDATE_INSTANCE_INFO",

    "CVAR_UPDATE",
    "UI_ERROR_MESSAGE"
)
stateFrame:SetScript("OnEvent", OnEvent)
