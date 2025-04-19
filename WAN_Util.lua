local _, wan = ...

---- INIT ARRAYS ----

wan.AbilityData = {}    -- used for displaying damage values for player
wan.MechanicData = {}   -- used for displaying defensive cooldowns, healing for player
wan.HealingData = {}    -- used for displaying healing values in a group
wan.SupportData = {}    -- used for displaying support values in a group
wan.HotValue = {}       -- used for storing hot values over all valid group units
wan.HealUnitCountAoE = {}  -- used for storing valid group unit count for aoe healing spells

-- used for determining physical resistances of mobs
wan.ClassificationData = {
    worldboss = 0.68,
    rareelite = 0.70,
    elite = 0.70,
    rare = 0.70,
    normal = 0.72,
    minus = 0.74,
    trivial  = 0.90,
}

-- used for checking what type of control affects the player
wan.LossOfControlData = {
    Blind = "STUN",
    Sap = "STUN",
    Stun = "STUN_MECHANIC",
    Horrify = "FEAR",
    Fear = "FEAR_MECHANIC",
    Incapacitate = "CONFUSE",
    Silence = "SILENCE",
    Root = "ROOT"
}

---- DATA UPDATE ----

function wan.UpdateAbilityData(abilityName, value, icon, name, desaturation)
    if value == 0 then wan.AbilityData[abilityName] = nil return end
    wan.AbilityData[abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

function wan.UpdateMechanicData(abilityName, value, icon, name, desaturation)
    if not abilityName then return end
    if value == 0 then wan.MechanicData[abilityName] = nil return end
    wan.MechanicData[abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

function wan.UpdateHealingData(unitToken, abilityName, value, icon, name, desaturation)
    if not unitToken then
        for unitID, _ in pairs(wan.HealingData) do
            if wan.HealingData[unitID] then
                wan.HealingData[unitID][abilityName] = {}
            end
        end
        return
    end

    wan.HealingData[unitToken] = wan.HealingData[unitToken] or {}
    if value == 0 then wan.HealingData[unitToken][abilityName] = {} return end
    wan.HealingData[unitToken][abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

function wan.UpdateSupportData(unitToken, abilityName, value, icon, name, desaturation)
    if not unitToken then
        for unitID, _ in pairs(wan.SupportData) do
            if wan.SupportData[unitID] then
                wan.SupportData[unitID][abilityName] = {}
            end
        end
        return
    end

    wan.SupportData[unitToken] = wan.SupportData[unitToken] or {}
    if value == 0 then wan.SupportData[unitToken][abilityName] = {} return end
    wan.SupportData[unitToken][abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

---- AURAS ----

-- returns buff data on units
function wan.CheckUnitBuff(unitToken, formattedBuffName, buffID)
    if not formattedBuffName then return nil end

    local unit = unitToken or "player"
    local checkBuff = wan.auraData[unit] and wan.auraData[unit]["buff_" .. formattedBuffName]

    if checkBuff then
        --- check for spellID when multiple buffs run under the same name
        if buffID and checkBuff.spellId ~= buffID then
            return nil
        end

        --- cleans any stale aura data that wasnt updated or cought by the addon
        local currentTime = GetTime()
        local checkExpiration = checkBuff.expirationTime - currentTime
        if checkBuff.duration > 0 and checkExpiration <= 0 then checkBuff = nil end
    end

    return checkBuff
end

-- returns debuff data on units
function wan.CheckUnitDebuff(unitToken, formattedDebuffName, debuffID)
    local unit = unitToken or wan.TargetUnitID
    local checkDebuff = wan.auraData[unit] and wan.auraData[unit]["debuff_" .. formattedDebuffName]
    
    if checkDebuff and debuffID and checkDebuff.spellID ~= debuffID then
         return nil
    end

    if checkDebuff then return checkDebuff end

    return nil
end

-- checks if unit has any of the debuffs listed in an array
function wan.CheckUnitAnyDebuff(unitToken, arrayFormattedDebuffNames, debuffID)
    if not unitToken then return nil end

    for _, formattedDebuffName in pairs(arrayFormattedDebuffNames) do
        local checkDebuff = wan.auraData[unitToken] and wan.auraData[unitToken]["debuff_" .. formattedDebuffName]

        if not debuffID and checkDebuff then
            return checkDebuff
        end

        if debuffID and checkDebuff and checkDebuff.spellID == debuffID then
            return checkDebuff
        end
    end

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

-- Checks if a buff on the unit matches the given aura types
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

-- same as the purge bool but used for buffs with a longer duration
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

-- checks if the player is missing a buff or has buff but with less then 6 minutes remaining
function wan.CheckSelfBuff(buffName)
    local currentTime = GetTime()
    local aura = wan.CheckUnitBuff(nil, buffName)
    local remainingDuration = aura and (aura.expirationTime - currentTime)

    if not aura or remainingDuration < 360 then return true end
end

-- Checks if a debuff on the unit matches the given aura types
function wan.GetDispelValue(unitToken, dispelTypes)
    local dispelValue = 0
    local currentTime = GetTime()
    for auraKey, aura in pairs(wan.auraData[unitToken]) do
        if auraKey:find("debuff_") then
            local debuffType = aura.dispelName
            local expirationTimeBool = (aura.expirationTime - currentTime) > 2 or false
            if expirationTimeBool and dispelTypes[debuffType] then
                local stacks = aura.applications
                if stacks == 0 then stacks = 1 end
                dispelValue = dispelValue + 1
            end
        end
    end

    if dispelValue > 0 then
        local roleValue = 0
        if wan.UnitState.Role[unitToken] == "TANK" then
            roleValue = 2
        elseif wan.UnitState.Role[unitToken] == "HEALER" then
            roleValue = 1.5
        elseif wan.UnitState.Role[unitToken] == "DAMAGER" then
            roleValue = 1
        end
        dispelValue = dispelValue + roleValue
    end

    return dispelValue
end

---- HEALING ----

--- checks the overall healing value of hots from the player present on a given unit
--- counts the number of hots from the player on a given unit
function wan.GetUnitHotValues(unitToken)
    if not unitToken or not wan.HotValue[unitToken] or not wan.auraData[unitToken] then return 0, 0 end
    local totalHotValues = 0
    local countHots = 0
    local currentTime = GetTime()
    for formattedHotName, hotValue in pairs(wan.HotValue[unitToken]) do
        local aura = wan.auraData[unitToken]["buff_" .. formattedHotName]
        if aura then 
            local reminingDuration = aura.expirationTime - currentTime
            local remainingValueMod = math.max(reminingDuration, 0) / aura.duration
            if reminingDuration < 0 then wan.auraData[unitToken]["buff_" .. formattedHotName] = nil end
            totalHotValues = totalHotValues + (hotValue * remainingValueMod)
            countHots = countHots + 1
        end
    end
    return totalHotValues, countHots
end

--- returns an effective healing value of an ability based on health, healing absorb and present hot values
function wan.UnitAbilityHealValue(unitToken, abilityValue, unitPercentHealth)
    if not unitToken or not abilityValue or abilityValue == 0 or not unitPercentHealth or unitPercentHealth == 0 then return 0 end
    local value = 0
    local unitHotValues = wan.GetUnitHotValues(unitToken)
    local maxHealth = wan.UnitState.MaxHealth[unitToken]
    local cAbilityPercentageValue = (abilityValue / maxHealth) or 0
    local cHotPercentageValue = (unitHotValues / maxHealth) or 0
    local cHealthAbsorbPercentageValue = wan.GetUnitHealAbsorb(unitToken) / maxHealth
    local cUnitPercentHealth = math.max((unitPercentHealth - cHealthAbsorbPercentageValue), 0)
    local thresholdValue = 0.5

    if thresholdValue > cUnitPercentHealth and (cUnitPercentHealth + cAbilityPercentageValue) < 1 then
        value = math.floor(abilityValue)
        return value
    end

    if cAbilityPercentageValue < cHotPercentageValue then
        return value
    end

    if (cUnitPercentHealth + cAbilityPercentageValue + cHotPercentageValue) < 1 then
        value = math.floor(abilityValue)
        return value
    end

    return value
end

function wan.HotPotency(unitToken, unitPercentHealth, initialValue)
    local currentPercentHealth = unitPercentHealth or 0
    local baseValue = ((initialValue or 0) + wan.GetUnitHotValues(unitToken)) or 0
    local maxHealth = (wan.UnitState.MaxHealth[unitToken]) or 0
    local thresholdValue = maxHealth * 0.5
    local targetHealth = (maxHealth * currentPercentHealth)

    if targetHealth + baseValue > thresholdValue then return 1 end

    local healPotency = ((targetHealth + baseValue) / thresholdValue)

    return math.min(healPotency, 1)
end

---- PHYSICAL DAMAGE REDUCTION ----

-- Checks classification and returns the damage reduction values of unit
function wan.CheckUnitPhysicalDamageReduction(unitToken)
    local unit = unitToken or wan.TargetUnitID
    local classification = wan.UnitState.Classification[unit]
    if wan.ClassificationData[classification] then
        return wan.ClassificationData[classification]
    end
    return 1
end

---- SCALING ----

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

---- Checks if player is missing enough health
function wan.AbilityPercentageToValue(percentValue)
    local percentage = percentValue or 100
    local maxHealth = wan.UnitState.MaxHealth.player or 0
    return maxHealth * (percentage / 100)
end

---- Checks if player is missing enough health
function wan.UnitAbilityPercentageToValue(unitToken, percentValue)
    local unit = unitToken or "player"
    local percentage = percentValue or 100
    local unitMaxHealth = wan.UnitState.MaxHealth[unit] or wan.UnitState.MaxHealth.player or 0
    return unitMaxHealth * (percentage / 100)
end

--- checks damage reduction when an ability has a soft cap
--- return value is a replacement for raw unit count
function wan.AdjustSoftCapUnitOverflow(capStart, numTargets)
    local maxTargets = math.min(numTargets, 20)
    if numTargets > capStart then
        return numTargets * math.sqrt(capStart / maxTargets)
    end

    return numTargets
end

--- checks damage reduction when an ability has a soft cap
--- return value is used as a damage modifier when looping over each unit
--- also, blizzard loves this math when it comes to AoE situations for damage and proc chance values
function wan.SoftCapOverflow(capStart, numTargets)
    local maxTargets = math.min(numTargets, 20)
    if numTargets > capStart  then
        return math.sqrt(capStart / maxTargets)
    end

    return 1
end

--- math for traits that have dimishing returns and have no ceiling
function wan.UncappedDamageOverflow(instanceNumber, Damage)
    local value = 0

    for x = 1, instanceNumber do
        value = value + math.sqrt(2 / x)
    end

    return value * Damage
end