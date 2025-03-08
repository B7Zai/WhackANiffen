local _, wan = ...

wan.ClassificationData = {
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


-- Checks classification and returns the damage reduction values of unit
function wan.CheckUnitPhysicalDamageReduction(unitToken)
    local unit = unitToken or wan.TargetUnitID
    local classification = wan.UnitState.Classification[unit]
    if wan.ClassificationData[classification] then
        return wan.ClassificationData[classification]
    end
    return 1
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

-- Adjust ability dot value to unit health
function wan.CheckDotPotency(initialValue, unitToken)
    local unit = unitToken or wan.TargetUnitID
    local unitHealth = wan.UnitState.Health[unit]
    if not unitHealth then return 1 end

    local baseValue = initialValue or 0
    local playerMaxHealth = wan.UnitState.MaxHealth.player
    local targetHealth = math.max((unitHealth - baseValue), 0)
    local damagePotency = (targetHealth / playerMaxHealth)
    local validGroupMembers = (wan.PlayerState.InGroup and wan.ValidGroupMembers()) or 1
    local calcPotency = damagePotency / validGroupMembers

    return math.min(calcPotency, 1)
end

function wan.CheckUnitDebuff(unitToken, formattedDebuffName, debuffID)
    local unit = unitToken or wan.TargetUnitID
    local checkDebuff = wan.auraData[unit] and wan.auraData[unit]["debuff_" .. formattedDebuffName]
    
    if checkDebuff and debuffID and checkDebuff.spellID ~= debuffID then
         return nil
    end

    if checkDebuff then return checkDebuff end

    return nil
end


-- Checks if unit has any of the debuffs listed
function wan.CheckForAnyDebuff(unitToken, debuffData)
    if not wan.auraData[unitToken] then return false end
    for _, debuffName in pairs(debuffData) do
        if wan.auraData[unitToken]["debuff_" .. debuffName] then
            return true
        end
    end

    return false
end

-- Counts number of specified debuffs on a unit
function wan.CountUnitDebuff(unitToken, debuffData)
    if not wan.auraData[unitToken] then return 0 end
    local countDebuff = 0
    for _, debuffName in pairs(debuffData) do
        if wan.auraData[unitToken]["debuff_" .. debuffName] then
            countDebuff = countDebuff + 1
        end
    end

    return countDebuff
end

-- Checks if a debuff on the unit matches the given aura types
function wan.CheckPurgeBool(unitToken)
    local unit = unitToken or wan.TargetUnitID
    if not wan.auraData[unit] then return false end

    local currentTime = GetTime()
    for auraName, aura in pairs(wan.auraData[unit]) do
        if auraName:find("buff_") then
            if aura.isStealable then
                local expirationTime = aura.expirationTime - currentTime
                local hasDuration = expirationTime > 3 or aura.expirationTime == 0
                local hasStacks = aura.applications and aura.applications >= 3
                if hasDuration or hasStacks then return true end
            end
        end
    end

    return false
end

function wan.CheckStealBool(unitToken)
    local unit = unitToken or wan.TargetUnitID
    if not wan.auraData[unit] then return false end

    local currentTime = GetTime()
    for auraName, aura in pairs(wan.auraData[unit]) do
        if auraName:find("buff_") then
            if aura.isStealable then
                local expirationTime = aura.expirationTime - currentTime
                local hasDuration = expirationTime > 10 or aura.expirationTime == 0
                local hasStacks = aura.applications and aura.applications >= 3
                if hasDuration or hasStacks then return true end
            end
        end
    end

    return false
end