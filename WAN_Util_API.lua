local _, wan = ...

---- EVENTS & FRAMES ----

-- Register multiple events at once
function wan.RegisterBlizzardEvents(frame, ...)
    for _, event in pairs({ ... }) do
        frame:RegisterEvent(event)
    end
end

-- Unregister multiple events at once
function wan.UnregisterBlizzardEvents(frame, ...)
    for _, event in pairs({ ... }) do
        frame:UnregisterEvent(event)
    end
end


function wan.BlizzardEventHandler(frame, spellBool, ...)
    for _, event in pairs({...}) do
        if spellBool then
            frame:RegisterEvent(event)
        else
            frame:UnregisterEvent(event)
        end
    end
end

-- Sets the update rate for tickers or throttles
local sliderValue = 0
function wan.SetUpdateRate(frame, callback, spellID)
    if not callback or not spellID then
        if wan.UpdateRate[frame] then
            wan.UpdateRate[frame]:Cancel()
            wan.UpdateRate[frame] = nil
        end

        frame:SetScript("OnUpdate", nil)
        return
    end

    local gcdValue = wan.GetSpellGcdValue(spellID)
    local updateThrottle = gcdValue / (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider or 4)

    if wan.Options.UpdateRate.Toggle then
        if wan.UpdateRate[frame] then
            wan.UpdateRate[frame]:Cancel()
            wan.UpdateRate[frame] = nil
        end

        local lastUpdate = 0
        if sliderValue ~= wan.Options.UpdateRate.Slider or not frame:GetScript("OnUpdate", 1) then
            frame:SetScript("OnUpdate", function(_, elapsed)
                lastUpdate = lastUpdate + elapsed
                if lastUpdate >= updateThrottle then
                    lastUpdate = 0
                    callback()
                end
            end)
            sliderValue = wan.Options.UpdateRate.Slider
        end
    else
        frame:SetScript("OnUpdate", nil)
        if not wan.UpdateRate[frame] then
            wan.UpdateRate[frame] = C_Timer.NewTicker(updateThrottle, function()
                callback()
            end)
        end
    end
end

local setTimer = nil
wan.IsTimerRunning = false
function wan.SetTimer(time)
    if not setTimer then
        setTimer = C_Timer.NewTimer(time, function()
            setTimer = nil
            wan.IsTimerRunning = false
        end)
        wan.IsTimerRunning = true
        return true
    else
        return false
    end
end

---- RANGE CHECKING ----

local LibRangeCheck = LibStub("LibRangeCheck-3.0") -- callback for range check library

---- Checks if unit is in range
function wan.CheckRange(unit, range, operator)
    local min, max = LibRangeCheck:GetRange(unit, true);

    if (type(range) ~= "number") then
        range = tonumber(range);
    end

    if (not range) then
        return
    end

    if (operator == "<=") then
        return (max or 999) <= range;
    else
        return (min or 0) >= range;
    end
end

---- Returns estimated min and max range from unit
function wan.GetRangeBracket(unitToken)
    if not unitToken then return 0, 0 end

    local min, max = LibRangeCheck:GetRange(unitToken, true);
    return min or 0, max or 999
end

-- Checks for a valid enemy unit
function wan.ValidUnitInRange(spellIdentifier, maxRange)
    local unit = wan.TargetUnitID
    if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
        return false
    end

    local inCombat = UnitAffectingCombat(unit) or UnitCanAttack(unit, "player")
    if not inCombat then
        return false
    end
    
    local spellID = spellIdentifier or 61304
    local maxSpellRange = maxRange or 0
    return C_Spell.IsSpellInRange(spellID, unit)
        or wan.CheckRange(unit, maxSpellRange, "<=")
end

-- Checks for valid enemy units
function wan.ValidUnitInRangeAoE(unit, spellIdentifier, maxRange)
    if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
        return false
    end

    local spellID = spellIdentifier or 61304
    local maxSpellRange = maxRange or 0

    local unitInCombat = UnitAffectingCombat(unit)
    if unitInCombat or (UnitReaction("player", unit) == 4 and not C_QuestLog.UnitIsRelatedToActiveQuest(unit)) then
        return C_Spell.IsSpellInRange(spellID, unit)
            or wan.CheckRange(unit, maxSpellRange, "<=")
    end

    return false
end

-- Checking, counting and returning UnitIDs that are in range
function wan.ValidUnitBoolCounter(spellIdentifier, maxRange)
    local count = 0
    local inRangeUnits = {}

    for nameplateUnitToken, nameplateGUID in pairs(wan.NameplateUnitID) do
        if wan.ValidUnitInRangeAoE(nameplateUnitToken, spellIdentifier, maxRange) then
            count = count + 1
            inRangeUnits[nameplateUnitToken] = nameplateGUID
        end
    end

    if count == 0 and wan.ValidUnitInRange(spellIdentifier, maxRange) then
        count = 1
    end

    return count > 0, count, inRangeUnits
end

--- returns an arbitrary damage modifier based on the amount of nearby group members
--- count the number of group members in range
--- returns all nearby group member's unit token and GUID in an array
function wan.ValidGroupMembers()
    if not wan.PlayerState.InGroup then return 1, 1, {} end

    local inRangeUnits = {}
    local count = 0
    for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
        if not UnitIsDeadOrGhost(groupUnitToken)
            and UnitIsConnected(groupUnitToken)
            and UnitInRange(groupUnitToken)
        then
            count = count + 1
            inRangeUnits[groupUnitToken] = groupUnitGUID
        end
    end

    local nGroupMembersInRange = count
    local nDamageScaler = wan.AdjustSoftCapUnitOverflow(3, count)

    return nDamageScaler, nGroupMembersInRange, inRangeUnits
end

--- returns an arbitrary damage modifier based on the number of group members in spell range
--- count the number of group members in spell range
--- returns all group member's unit token and GUID that are in spell range in an array
function wan.ValidGroupMembersInSpellRange(spellIndentifier, maxRange)
    if not IsInGroup() then return 1, 1, {} end
    local spellID = spellIndentifier or 61304
    local maxSpellRange = maxRange or 0

    local inRangeUnits = {}
    local count = 0
    for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
        if not UnitIsDeadOrGhost(groupUnitToken)
            and UnitIsConnected(groupUnitToken)
            and (C_Spell.IsSpellInRange(spellID, groupUnitToken)
                or wan.CheckRange(groupUnitToken, maxSpellRange, "<="))
        then
            count = count + 1
            inRangeUnits[groupUnitToken] = groupUnitGUID
        end
    end

    local nGroupMembersInRange = count
    local nDamageScaler = wan.AdjustSoftCapUnitOverflow(3, count)

    return nDamageScaler, nGroupMembersInRange, inRangeUnits
end

---- DESCRIPTIONS ----

-- Parses spell description and converts string numbers to numeric values.
-- Returns specified numbers indexed by `indexes`.
-- Returns 0 if no valid numbers are found for the specified indexes.
function wan.GetSpellDescriptionNumbers(spellIdentifier, indexes)
    local spellDesc = C_Spell.GetSpellDescription(spellIdentifier)
    if not spellDesc then return 0 end

    --needs localization
    local suffixMultipliers = {
        ["thousand"] = 1e3,
        ["million"]  = 1e6,
        ["billion"]  = 1e9,
    }
    local abilityValues = {}

    for number, suffix in spellDesc:gmatch("(%d+[%.,]?%d*)%s*(%a*)") do
        local cleanNumber = tonumber((number:gsub("[,%%]", "")))
        if cleanNumber then
            cleanNumber = cleanNumber * (suffixMultipliers[suffix:lower()] or 1)
            table.insert(abilityValues, cleanNumber)
        end
    end

    if #abilityValues == 0 then abilityValues = { 0 } end

    local selectedNumbers = {}
    for _, index in ipairs(indexes) do
        local num = abilityValues[index] or 0
        table.insert(selectedNumbers, num)
    end

    return #indexes == 1 and selectedNumbers[1] or selectedNumbers
end

-- Parses trait description and converts string numbers to numeric values.
-- Returns specified numbers indexed by `indexes`.
-- Returns 0 if no valid numbers are found for the specified indexes.
function wan.GetTraitDescriptionNumbers(entryID, indexes, rank)
    if not entryID then
        local result = {}
        for _, index in ipairs(indexes) do
            result[#result + 1] = 0
        end
        return #indexes == 1 and result[1] or result
    end

    local traitRank = rank or 0
    local traitDesc = C_Traits.GetTraitDescription(entryID, traitRank)

    if not traitDesc then
        local result = {}
        for _, index in ipairs(indexes) do
            result[#result + 1] = 0
        end
        return #indexes == 1 and result[1] or result
    end

    local suffixMultipliers = { thousand = 1e3, million = 1e6, billion = 1e9 }
    local traitValues = {}
    for number, suffix in traitDesc:gmatch("(%d+[%.,]?%d*)%s*(%a*)") do
        local cleanNumber = tonumber((number:gsub("[,%%]", ""))) or 0
        traitValues[#traitValues + 1] = cleanNumber * (suffixMultipliers[suffix:lower()] or 1)
    end

    local results = {}
    for _, index in ipairs(indexes) do
        results[#results + 1] = traitValues[index] or 0
    end

    return #indexes == 1 and results[1] or results
end

--- check ability description for dispel types, returns an array
function wan.CheckDispelType(spellIdentifier)
    local spellDesc = C_Spell.GetSpellDescription(spellIdentifier)
    local playerDispelTypes = {}

    if not spellDesc or spellDesc == "" then
        return playerDispelTypes
    end

    local dispelTypes = { "Curse", "Disease", "Magic", "Poison", "Enrage", "Stun", "Fear", "Blind", "Sap", "Incapacitate" }

    for _, dispelType in pairs(dispelTypes) do
        if string.find(spellDesc, dispelType) then
            playerDispelTypes[dispelType] = dispelType
        end
    end

    return playerDispelTypes
end

---- COOLDOWNS ----

-- Checks gcd value
function wan.GetSpellGcdValue(spellID)
    local gcdValue = 1.5
    if spellID then
        local _, gcdMS = GetSpellBaseCooldown(spellID)
        if gcdMS and gcdMS >= 0 then
            if gcdMS == 0 then
                gcdValue = 1
            else
                gcdValue = gcdMS / 1000
            end
        end
    end
    return gcdValue
end

--- checks if a spell is usable and not on cooldown
function wan.IsSpellUsable(spellIdentifier)
    if not spellIdentifier then return end
    
    local isUsable, insufficientPower = C_Spell.IsSpellUsable(spellIdentifier)
    if not isUsable then return isUsable, insufficientPower end

    local cooldownMS, gcdMS = GetSpellBaseCooldown(spellIdentifier)
    if cooldownMS > gcdMS then
        local _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player")
        if spellId == spellIdentifier then
            return false
        end
    end

    local getCooldown = C_Spell.GetSpellCooldown(spellIdentifier)
    local getGCD = gcdMS and gcdMS / 1000 or 0

    --- this part is a check for weird cooldown duration only present while an ability is on GCD
    --- only happens with only a few abilities like maul, minuscule but annoying non the less
    if getCooldown.duration > getGCD and getCooldown.duration == wan.PlayerState.BaseCooldown.duration then
        getCooldown.duration = getGCD
    end

    return getCooldown.duration <= getGCD, insufficientPower
end

--- check how much stacks / charges a spell holds
function wan.CheckSpellCharges(spellIdentifier)
    if not spellIdentifier then return 0, 0 end

    local chargeInfo = C_Spell.GetSpellCharges(spellIdentifier)

    if chargeInfo then
        return chargeInfo.currentCharges, chargeInfo.maxCharges
    end

    return 0, 0
end

--- check how much stacks / charges a spell holds
function wan.CheckSpellCount(spellIdentifier)
    if not spellIdentifier then return 0 end

    local castCount  = C_Spell.GetSpellCastCount(spellIdentifier)

    if castCount then
        return castCount
    end

    return 0
end

---- UNIT STATE ----

---- Check unit remaining health in percetage, actual value is between 0 to 1
function wan.CheckUnitPercentHealth(unitGUID)

    local checkUnitPercentHealth = unitGUID and UnitPercentHealthFromGUID(unitGUID) or 1
    return checkUnitPercentHealth
end

--- checks the amount of absorb the given unit has
function wan.CheckUnitAbsorb(unitToken)
    local totalAbsorbs = unitToken and UnitGetTotalAbsorbs(unitToken) or 0

    return totalAbsorbs
end

--- check heal absorb value of a given unit
function wan.GetUnitHealAbsorb(unitToken)
    local totalHealAbsorbs = unitToken and UnitGetTotalHealAbsorbs(unitToken) or 0

    return totalHealAbsorbs
end

-- Checks critical chance and critical damage weights for ability values
function wan.ValueFromCritical(critChance, critMod, critDamageMod)
    local critChance = critChance or GetCritChance()
    local critMod = critMod or 0
    local critDamageMod = critDamageMod or 0
    local critValue = math.min((1 + (critChance * 0.01) + (critMod * 0.01)), 2)
    local critDamageValue =  1 + (critDamageMod * 0.01)

    return (critValue * critDamageValue)
end

--- checks spell (max) cost, and min cost
function wan.GetSpellCost(spellIndentifier, powerType)
    local costTable = C_Spell.GetSpellPowerCost(spellIndentifier)
    
    if costTable then
        for _, spellPower in ipairs(costTable) do
            if spellPower.type == powerType then
                return spellPower.cost, spellPower.minCost
            end
        end
    end
end

--- checks cast efficiency against gcd, value is a damage modifier
local lastStationary = 0
function wan.CheckCastEfficiency(spellID, spellCastTime, canMoveCast)
    local valueModifier = 1
    local castTime = spellCastTime / 1000

    if castTime <= 0 then
        return valueModifier
    end

    --- checks player speed for the Movement Detection feature
    if wan.Options.DetectMovement.Toggle and wan.PlayerState.Combat then
        local movingCast = canMoveCast or false
        local playerSpeed = GetUnitSpeed("player") or 0
        local currentTime = GetTime()

        if playerSpeed == 0 or not wan.PlayerState.Combat then lastStationary = currentTime end

        if not movingCast and currentTime - lastStationary > wan.Options.DetectMovement.Slider then
            return 0
        end
    end

    local _, gcdMS = GetSpellBaseCooldown(spellID)
    local gcdValue = gcdMS / 1000

    if gcdValue and castTime > 0 then
        valueModifier = math.min(gcdValue / castTime, 1)
    end

    return valueModifier
end

--- checks if given unit is casting or channeling a spell
function wan.UnitIsCasting(unitToken, spellIndentifier)
    local unit = unitToken or "player"
    local castName, _, _, _, _, _, _, _, castSpellID = UnitCastingInfo(unit)

    if spellIndentifier == castName or spellIndentifier == castSpellID then
        return true
    end

    local channelName, _, _, _, _, _, _, channelSpellID = UnitChannelInfo(unit)

    if spellIndentifier == channelName or spellIndentifier == channelSpellID then
        return true
    end

    return false
end

--- checks if any valid unit is targeting the player
function wan.IsTanking()
    local isTanking = UnitDetailedThreatSituation("player", wan.TargetUnitID) or false
    if isTanking then return true end

    for nameplateUnitToken, _ in pairs(wan.NameplateUnitID) do
        local isTankingUnit = UnitDetailedThreatSituation("player", nameplateUnitToken) or false
        local inRange = wan.CheckRange(nameplateUnitToken, 40, "<=")

        if inRange and isTankingUnit then return true end
    end

    return false
end

--- checks if given unit is tanking any of the nameplate unit
function wan.IsUnitTanking(unitToken)

    for nameplateUnitToken, _ in pairs(wan.NameplateUnitID) do
        local isTankingUnit = UnitDetailedThreatSituation(unitToken, nameplateUnitToken) or false
        local inRange = wan.CheckRange(nameplateUnitToken, 60, "<=")

        if inRange and isTankingUnit then return true end
    end

    return false
end

--- checks if the player can remove a loss of control effect from itself
function wan.CheckPlayerLossOfControl(dispelTypes)
    for i = 1, 10 do
        local checkLossOfControlData = C_LossOfControl.GetActiveLossOfControlData(i)

        if not checkLossOfControlData then
            return false
        end

        local checkLosType = checkLossOfControlData and checkLossOfControlData.locType
        local checkLosExpirationTime = checkLossOfControlData and checkLossOfControlData.timeRemaining
        for dispelType, _ in pairs(dispelTypes) do
            if wan.LossOfControlData[dispelType] == checkLosType and (not checkLosExpirationTime or checkLosExpirationTime > 2) then
                return true
            end
        end
    end

    return false
end

function wan.CheckUnitMaxPower(unit, nPowerType)
    local powerMax = UnitPowerMax(unit, nPowerType)

    return powerMax
end

function wan.CheckUnitPower(unit, nPowerType)
    local currentPower = UnitPower(unit, nPowerType)

    return currentPower
end

-- Checks damage reduction from armor gain
function wan.GetArmorDamageReductionFromSpell(armorValue)
    local unitLevel = wan.UnitState.Level[wan.TargetUnitID] or wan.UnitState.Level.player
    local playerLevel = wan.UnitState.Level.player
    local targetLevel = math.max(unitLevel, playerLevel)
    local _, _, armor = UnitArmor("player")
    local buffedArmor = armor + armorValue
    local currentEffectiveness = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(armor) or C_PaperDollInfo.GetArmorEffectiveness(armor, targetLevel)
    local buffedEffectiveness = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(buffedArmor) or C_PaperDollInfo.GetArmorEffectiveness(buffedArmor, targetLevel)

    return (buffedEffectiveness - currentEffectiveness) * 100
end

-- Check player's specialization 
function wan.GetTraitInfo()
    local currentSpec = C_SpecializationInfo.GetSpecialization()
    if currentSpec then
        local id, name, description, icon, role, primaryStat = C_SpecializationInfo.GetSpecializationInfo(currentSpec)
        return id, name, description, icon, role, primaryStat, currentSpec
    end
end

--- check if the player's pet is summoned or dead
function wan.IsPetUsable()
    return IsPetActive() or UnitIsDead("pet")
end

---- AURAS ----

-- Counts units that have a specific debuff
function wan.CheckClassBuff(buffName)
    local currentTime = GetTime()
    local aura = wan.CheckUnitBuff(nil, buffName)
    local remainingDuration = aura and (aura.expirationTime - currentTime)

    if wan.PlayerState.InGroup then
        local nGroupUnits = GetNumGroupMembers()
        local _, nGroupMembersInRange, idValidGroupMember = wan.ValidGroupMembers()
        local nDisconnected = 0

        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            local isOnline = UnitIsConnected(groupUnitToken)
            local checkFaction = UnitFactionGroup(groupUnitToken)
            if not isOnline then
                nDisconnected = nDisconnected + 1
            end
        end

        local nGroupSize = (nGroupUnits - nDisconnected)

        if nGroupSize == nGroupMembersInRange then
            for groupUnitToken, _ in pairs(idValidGroupMember) do
                local hasClassBuff = wan.CheckUnitBuff(groupUnitToken, buffName)
                if not hasClassBuff then
                    return true
                end
            end
        end
    end
    
    if not aura or remainingDuration < 360 then return true end
end

---- SCALING ----

-- Check and convert cooldown to values
function wan.OffensiveCooldownToValue(spellIndentifier)
    local cooldownMS, gcdMS = GetSpellBaseCooldown(spellIndentifier)
    if cooldownMS <= 1000 then cooldownMS = cooldownMS * 100 end
    if cooldownMS == 0 then cooldownMS = 120000 end
    local maxCooldown = cooldownMS / 1000 / 60
    local maxHealth = wan.UnitState.MaxHealth.player
    return (maxHealth * maxCooldown) or math.huge
end

-- Check and convert defensive cooldown to values
function wan.DefensiveCooldownToValue(spellIndentifier, customCooldown)
    local minThreshold = customCooldown or 30000
    local cooldownMS = GetSpellBaseCooldown(spellIndentifier)
    
    if customCooldown and cooldownMS < minThreshold then cooldownMS = minThreshold end
    local maxCooldown =  math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = wan.UnitState.MaxHealth.player
    local healthThresholds = maxHealth * 0.1

    local cooldownValue = (maxCooldown <= 0.5 and healthThresholds * 2)
    or (0.5 < maxCooldown and maxCooldown <= 1 and healthThresholds * 3)
    or (1 < maxCooldown and maxCooldown <= 2 and healthThresholds * 5)
    or (2 < maxCooldown and healthThresholds * 7)
    or healthThresholds

    return cooldownValue or math.huge
end

-- Check and convert defensive cooldown to values
function wan.UnitDefensiveCooldownToValue(spellIndentifier, unitToken, customCooldown)
    local minThreshold = customCooldown or 30000
    local cooldownMS = GetSpellBaseCooldown(spellIndentifier)

    if customCooldown and cooldownMS < minThreshold then cooldownMS = minThreshold end
    local maxCooldown = math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = wan.UnitState.MaxHealth[unitToken]
    if not maxHealth then return math.huge end

    local healthThresholds = maxHealth * 0.1
    local cooldownValue = (maxCooldown <= 0.5 and healthThresholds * 2)
    or (0.5 < maxCooldown and maxCooldown <= 1 and healthThresholds * 3)
    or (1 < maxCooldown and maxCooldown <= 2 and healthThresholds * 5)
    or (2 < maxCooldown and healthThresholds * 7)
    or healthThresholds

    return cooldownValue or math.huge
end

-- Checks if units have enough health to use an offensive cooldown
function wan.CheckOffensiveCooldownPotency(spellDamage, validUnit, unitIDAoE)
    local abilityDamage = spellDamage or 0
    local unitToken = wan.TargetUnitID
    local targetHealth = wan.UnitState.Health[unitToken] or 0
    local validGroupMembers = wan.ValidGroupMembers()
    local damagePotency = abilityDamage * validGroupMembers

    if validUnit and (
            targetHealth >= damagePotency
            or (UnitInRaid("player") and UnitIsBossMob(unitToken))
            or UnitIsPlayer(unitToken)
        ) then
        return true
    end

    local totalNameplateHealth = 0
    for nameplateUnitToken, _ in pairs(unitIDAoE or {}) do
        local nameplateHealth = wan.UnitState.Health[nameplateUnitToken] or 0
        totalNameplateHealth = totalNameplateHealth + nameplateHealth
        if totalNameplateHealth >= damagePotency 
        or (UnitInRaid("player") and UnitIsBossMob(nameplateUnitToken))
        or UnitIsPlayer(nameplateUnitToken) then
            return true
        end
    end

    return false
end

---- GROUPS ----

function wan.AssignUnitState(frameCallback, isLevelScaling)
    local activeUnits = {}
    local unitToken = frameCallback and frameCallback.unit
    local unitGUID = unitToken and UnitGUID(unitToken)
    if unitGUID and unitToken then
        local maxHealth = UnitHealthMax(unitToken) or 0
        local unitLevel = UnitLevel(unitToken) or wan.UnitState.Level[wan.PlayerState.GUID]
        local role = UnitGroupRolesAssigned(unitToken) or "DAMAGER"
        local isAI = UnitInPartyIsAI(unitToken) or false

        wan.GroupUnitID[unitToken] = unitGUID
        activeUnits[unitGUID] = unitToken

        wan.UnitState.LevelScale[unitToken] = 1
        wan.UnitState.MaxHealth[unitToken] = maxHealth
        wan.UnitState.Level[unitToken] = unitLevel
        wan.UnitState.IsAI[unitToken] = isAI
        wan.UnitState.Role[unitToken] = role

        if isLevelScaling then
            if wan.UnitState.Level[unitToken] ~= wan.UnitState.Level["player"] then
                local levelScaleValue = wan.UnitState.MaxHealth[unitToken] / wan.UnitState.MaxHealth["player"]
                wan.UnitState.LevelScale[unitToken] = levelScaleValue
            end
        end
    end

    return activeUnits
end