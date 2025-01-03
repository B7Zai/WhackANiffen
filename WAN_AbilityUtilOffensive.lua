local _, wan = ...

wan.classificationData = {
    worldboss = 0.68,
    rareelite = 0.70,
    elite = 0.70,
    rare = 0.70,
    normal = 0.72,
    minus = 0.74,
    trivial  = 0.90,
}

function wan.UpdateAbilityData(abilityName, value, icon, name, desaturation)
    if value == 0 then wan.AbilityData[abilityName] = nil return end
    wan.AbilityData[abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

local LibRangeCheck = LibStub("LibRangeCheck-3.0")
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

-- Checks for a valid unit
function wan.ValidUnitInRange(spellIdentifier, maxRange)
    if not UnitExists(wan.TargetUnitID) or not UnitCanAttack("player", wan.TargetUnitID) then
        return false
    end

    local inCombat = UnitAffectingCombat(wan.TargetUnitID) or UnitCanAttack(wan.TargetUnitID, "player")
    if not inCombat then
        return false
    end
    
    local spellID = spellIdentifier or 61304
    local maxSpellRange = maxRange or 0
    return C_Spell.IsSpellInRange(spellID, wan.TargetUnitID)
        or wan.CheckRange(wan.TargetUnitID, maxSpellRange, "<=")
end

-- Checks for valid units
function wan.ValidUnitInRangeAoE(unit, spellIdentifier, maxRange)
    if not UnitExists(unit) or not UnitCanAttack("player", unit) then
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

    for unitTokenNameplate, unitGUID in pairs(wan.NameplateUnitID) do
        if wan.ValidUnitInRangeAoE(unitTokenNameplate, spellIdentifier, maxRange) then
            count = count + 1
            inRangeUnits[unitTokenNameplate] = unitGUID
        end
    end

    if count == 0 and wan.ValidUnitInRange(spellIdentifier, maxRange) then
        count = 1
    end

    return count > 0, count, inRangeUnits
end


-- Checks classification and returns the damage reduction values of unit
function wan.CheckUnitPhysicalDamageReduction(unitToken)
    local unit = unitToken or wan.TargetUnitID
    local classification = wan.UnitState.Classification[unit]
    if wan.classificationData[classification] then
        return wan.classificationData[classification]
    end
    return 1
end

-- Checks classification and returns the damage reduction values of units
function wan.CheckUnitPhysicalDamageReductionAoE(unitTokensInRange)
    local totalDamageReduction = 0
    local count = 0

    for unitTokenNameplate, _ in pairs(unitTokensInRange) do
        local unitClassification = wan.UnitState.Classification[unitTokenNameplate]
        if wan.classificationData[unitClassification] then
            totalDamageReduction = totalDamageReduction + wan.classificationData[unitClassification]
            count = count + 1
        end
    end

    if count > 0 then
        return totalDamageReduction / count
    else
        return 1
    end
end

-- Check and convert cooldown to values
function wan.OffensiveCooldownToValue(spellIndentifier)
    local cooldownMS, gcdMS = GetSpellBaseCooldown(spellIndentifier)
    if cooldownMS <= 1000 then cooldownMS = cooldownMS * 100 end
    if cooldownMS == 0 then cooldownMS = 120000 end
    local maxCooldown = cooldownMS / 1000 / 60
    local maxHealth = wan.UnitState.MaxHealth.player
    return (maxHealth * maxCooldown) or math.huge
end

-- Checks if units have enough health to use an offensive cooldown
function wan.CheckOffensiveCooldownPotency(spellDamage, validUnit, unitIDAoE)
    local abilityDamage = spellDamage or 0
    local targetHealth = wan.UnitState.Health[wan.TargetUnitID] or 0
    local validGroupMembers = wan.ValidGroupMembers()
    local damagePotency = abilityDamage * validGroupMembers

    if validUnit and (
            targetHealth >= damagePotency
            or (UnitInRaid("player") and UnitIsBossMob(wan.TargetUnitID))
            or UnitIsPlayer(wan.TargetUnitID)
        ) then
        return true
    end

    local totalNameplateHealth = 0
    for nameplates, _ in pairs(unitIDAoE or {}) do
        local nameplateHealth = wan.UnitState.Health[nameplates] or 0
        totalNameplateHealth = totalNameplateHealth + nameplateHealth
        if totalNameplateHealth >= damagePotency 
        or (UnitInRaid("player") and UnitIsBossMob(nameplates))
        or UnitIsPlayer(nameplates) then
            return true
        end
    end

    return false
end

-- Adjust ability dot value to non debuffed unit healths
function wan.CheckAoEPotency(validUnitIDs)
    local totalNameplateHealth = 0

    for unitID, _ in pairs(validUnitIDs) do
        local targetHealth = wan.UnitState.Health[unitID]
        totalNameplateHealth = totalNameplateHealth + targetHealth
    end

    local maxHealth = wan.UnitState.MaxHealth.player
    local damagePotency = (totalNameplateHealth / maxHealth)
    local validGroupMembers = wan.ValidGroupMembers()
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

-- Adjust ability dot value to unit health
function wan.CheckDotPotency(initialValue, unitToken)
    local unit = unitToken or wan.TargetUnitID
    local baseValue = initialValue or 0
    local maxHealth = wan.UnitState.MaxHealth.player or 0
    local targetHealth = math.max((wan.UnitState.Health[unit] - baseValue), 0)
    local damagePotency = (targetHealth / maxHealth)
    local validGroupMembers = (wan.PlayerState.InGroup and wan.ValidGroupMembers()) or 1
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

-- Adjust ability dot value to non debuffed unit healths
function wan.CheckDotPotencyAoE(auraData, validUnitIDs, debuffName, maxStacks, initialValue)
    local totalNameplateHealth = 0
    local baseValue = initialValue or 0
    local setMaxStacks = (maxStacks and maxStacks > 0) and maxStacks or 1

    for unitToken, _ in pairs(validUnitIDs) do
        if debuffName then
            local aura = auraData[unitToken]["debuff_" .. debuffName]

            if not aura or aura.applications < setMaxStacks then
                local targetHealth = math.max((wan.UnitState.Health[unitToken] - baseValue), 0)
                totalNameplateHealth = totalNameplateHealth + targetHealth
            end
        end
    end

    local maxHealth = wan.UnitState.MaxHealth.player or 0
    local damagePotency = (totalNameplateHealth / maxHealth)
    local validGroupMembers = wan.ValidGroupMembers()
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

-- Checks if a debuff is on a unit
function wan.CheckForDebuff(auraData, debuffName, unitID)
    local auras = auraData[unitID]
    if not auras then return false end

    local debuffName = debuffName
    if debuffName and auras["debuff_" .. debuffName] then
        return true
    end
    return false
end

-- Counts units that have a specific debuff
function wan.CheckForDebuffAoE(auraData, validUnitIDs, debuffName, maxStacks)
    local debuffCount = 0
    local setMaxStacks = (maxStacks and maxStacks > 0) and maxStacks or 1
    
    for unitToken, _ in pairs(validUnitIDs) do
        local aura = auraData[unitToken]["debuff_" .. debuffName]

        if aura and aura.applications < setMaxStacks then
            debuffCount = debuffCount + 1
        end
    end

    return debuffCount
end


-- Checks if unit has any of the debuffs listed
function wan.CheckForAnyDebuff(auraData, debuffData, unitID)
    local auras = auraData[unitID]
    if not auras then return false end

    for _, debuffName in pairs(debuffData) do
        if auras["debuff_" .. debuffName] then
            return true
        end
    end

    return false
end

-- Counts units that has any of the debuffs listed
function wan.CheckForAnyDebuffAoE(auraData, debuffData, validUnitIDs)
    local debuffCount = 0

    for unitID, _ in pairs(validUnitIDs) do
        local auras = auraData[unitID]
        if auras then
            for _, debuffName in pairs(debuffData) do
                if auras["debuff_" .. debuffName] then
                    debuffCount = debuffCount + 1
                    break
                end
            end
        end
    end

    return debuffCount
end

-- Checks if a debuff on the unit matches the given aura types
function wan.CheckPurgeBool(auraData, unitID)
    if auraData[unitID] then
        for auraName, aura in pairs(auraData[unitID]) do
            if auraName:find("buff_") then
                if aura.isStealable then
                    local hasDuration = aura.expirationTime and (aura.expirationTime > 3 or aura.expirationTime == 0)
                    local hasStacks = aura.applications and aura.applications >= 3
                    if hasDuration or hasStacks then return true end
                end
            end
        end
    end
    return false
end