local _, wan = ...

wan.classificationData = {
    WorldBoss = { classification = "worldboss", dmgreduc = 0.68 },
    RareElite = { classification = "rareelite", dmgreduc = 0.70 },
    Elite = { classification = "elite", dmgreduc = 0.70 },
    Rare = { classification = "rare", dmgreduc = 0.70 },
    Normal = { classification = "normal", dmgreduc = 0.72 },
    Minus = { classification = "minus", dmgreduc = 0.74 },
    Trivial = { classification = "trivial", dmgreduc = 0.90 },
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

    for nameplateUnitID, _ in pairs(wan.NameplateUnitID) do
        if wan.ValidUnitInRangeAoE(nameplateUnitID, spellIdentifier, maxRange) then
            count = count + 1
            inRangeUnits[nameplateUnitID] = true
        end
    end

    if count == 0 and wan.ValidUnitInRange(spellIdentifier, maxRange) then
        count = 1
    end

    return count > 0, count, inRangeUnits
end


-- Checks classification and returns the damage reduction values of unit
function wan.CheckUnitPhysicalDamageReduction(classificationDataArray)
    local unitClassification = UnitClassification(wan.TargetUnitID)
    for _, data in pairs(classificationDataArray) do
        if unitClassification == data.classification then
            return data.dmgreduc
        end
    end
    return 1
end

-- Checks classification and returns the damage reduction values of units
function wan.CheckUnitPhysicalDamageReductionAoE(classificationDataArray, spellIndentifier, maxRange)
    local totalDamageReduction = 0
    local count = 0

    for i = 1, 40 do
        local unit = "nameplate" .. i

        if wan.ValidUnitInRangeAoE(unit, spellIndentifier, maxRange) then
            local unitClassification = UnitClassification(unit)

            for _, data in pairs(classificationDataArray) do
                if unitClassification == data.classification then
                    totalDamageReduction = totalDamageReduction + data.dmgreduc
                    count = count + 1
                end
            end
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
    local maxHealth = UnitHealthMax("player")
    return (maxHealth * maxCooldown) or math.huge
end

-- Checks if units have enough health to use an offensive cooldown
function wan.CheckOffensiveCooldownPotency(spellDamage, validUnit, unitIDAoE)
    local abilityDamage = spellDamage or 0
    local targetHealth = UnitHealth(wan.TargetUnitID) or 0
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
        local nameplateHealth = UnitHealth(nameplates) or 0
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
        local targetHealth = UnitHealth(unitID)
        totalNameplateHealth = totalNameplateHealth + targetHealth
    end

    local maxHealth = UnitHealthMax("player")
    local damagePotency = (totalNameplateHealth / maxHealth)
    local validGroupMembers = wan.ValidGroupMembers()
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

-- Counts units that have a specific debuff
function wan.CheckClassBuff(buffName)
    if wan.PlayerState.InHealerMode then
        local nGroupUnits = GetNumGroupMembers()
        local _, nGroupMembersInRange, idValidGroupMember = wan.ValidGroupMembers()
        local countBuffed = 0
        local nDisconnected = 0

        for groupUnitID, _ in pairs(wan.GroupUnitID) do
            local isOnline = UnitIsConnected(groupUnitID)
            if not isOnline then
                nDisconnected = nDisconnected + 1
            end
        end

        local nGroupSize = (nGroupUnits - nDisconnected)

        if nGroupSize ~= nGroupMembersInRange then
            local aura = wan.auraData.player["buff_" .. buffName]
            local remainingDuration = aura and (aura.expirationTime - GetTime())
            return not aura or remainingDuration < 360 
        else
            for unitID, _ in pairs(idValidGroupMember or {}) do
                local buffed = wan.auraData[unitID]["buff_" .. buffName]
                if buffed then
                    countBuffed = countBuffed + 1
                end
            end
            return (nGroupUnits > 0 and nGroupMembersInRange > countBuffed)
        end
    end
    local aura = wan.auraData.player["buff_" .. buffName]
    local remainingDuration = aura and (aura.expirationTime - GetTime())
    return not aura or remainingDuration < 360
end

-- Adjust ability dot value to unit health
function wan.CheckDotPotency(initialValue)
    local baseValue = initialValue or 0
    local maxHealth = wan.UnitMaxHealth.player or 0
    local targetHealth = math.max((UnitCanAttack("player", wan.TargetUnitID) and UnitHealth(wan.TargetUnitID) or 0)- baseValue, 0)
    local damagePotency = (targetHealth / maxHealth)
    local validGroupMembers = wan.ValidGroupMembers()
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

-- Adjust ability dot value to non debuffed unit healths
function wan.CheckDotPotencyAoE(auraData, validUnitIDs, debuffName, maxStacks, initialValue)
    local totalNameplateHealth = 0
    local baseValue = initialValue or 0
    local setMaxStacks = (maxStacks and maxStacks > 0) and maxStacks or 1

    for unitID, _ in pairs(validUnitIDs) do
        if debuffName then
            local auras = auraData[unitID]
            local debuff = auras and auras["debuff_" .. debuffName]

            if not debuff or debuff.applications < setMaxStacks then
                local targetHealth = math.max((UnitHealth(unitID) - baseValue), 0)
                totalNameplateHealth = totalNameplateHealth + targetHealth
            end
        end
    end

    local maxHealth = wan.UnitMaxHealth.player or 0
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
    
    for unitID, _ in pairs(validUnitIDs) do
        local aura = auraData[unitID]
        local debuff = aura and aura["debuff_" .. debuffName]

        if debuff and debuff.applications < setMaxStacks then
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