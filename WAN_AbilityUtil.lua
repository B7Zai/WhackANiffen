local _, wan = ...

wan.AbilityData = {}
wan.MechanicData = {}
wan.HealingData = {}
wan.HotValue = {}

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

---- Checks if player is missing enough health
function wan.AbilityPercentageToValue(percentValue)
    local percentage = percentValue or 100
    local unitMaxHealth = UnitHealthMax("player")
    return unitMaxHealth * (percentage / 100)
end

-- Check on player's specialization 
function wan.GetTraitInfo()
    local currentSpec = GetSpecialization()
    local id, name, description, icon, role, primaryStat = GetSpecializationInfo(currentSpec)
    return id, name, description, icon, role, primaryStat 
end

-- Checks if a spell is usable and not on cooldown
function wan.IsSpellUsable(spellIdentifier)
    local isReady = C_Spell.IsSpellUsable(spellIdentifier)
    if not isReady then return false end
    local _, gcdMS = GetSpellBaseCooldown(spellIdentifier)
    local getGCD = gcdMS and gcdMS / 1000 or 0
    local getCooldown = C_Spell.GetSpellCooldown(spellIdentifier)
    return (getCooldown.duration <= getGCD)
end

-- Checks critical chance and critical damage weights for ability values
function wan.ValueFromCritical(critChance, critMod, critDamageMod)
    local critChance = critChance or GetCritChance()
    local critMod = critMod or 0
    local critDamageMod = critDamageMod or 0
    local critValue = 1 + (critChance / 100) + (critMod / 100)
    local critDamageValue = (critDamageMod / 100) + 1
    return critValue * critDamageValue
end

-- Checks spell cost
function wan.GetSpellCost(spellIndentifier, powerType)
    local costTable = C_Spell.GetSpellPowerCost(spellIndentifier)
    for _, spellPower in ipairs(costTable) do
        if spellPower.type == powerType then
            return spellPower.cost
        end
    end
end

-- Checks cast efficiency against gcd
function wan.CheckCastEfficiency(spellID, spellCastTime)
    local _, gcdMS = GetSpellBaseCooldown(spellID)

    if not gcdMS or not spellCastTime then
        return 1
    end

    local gcdValue = gcdMS / 1000
    local castTime = spellCastTime / 1000

    if gcdValue and castTime > 0 then
        return math.min(gcdValue / castTime, 1)
    end

    return 1
end

-- Reduce damage for "beyond x target abilities"
function wan.AdjustSoftCapUnitOverflow(capStart, numTargets)
    local maxTargets = math.min(numTargets, 20)
    if numTargets > capStart then
        return numTargets * math.sqrt(capStart / maxTargets)
    end

    return numTargets
end

---- checks if any valid unit is targeting the player
function wan.IsTanking()
    local isTanking = UnitDetailedThreatSituation("player", wan.TargetUnitID) or false
    if isTanking then
        return true  
    end

    for i = 1, 40 do
        local unit = "nameplate" .. i

        if UnitExists(unit) and UnitCanAttack("player", unit) then
            local inCombat = UnitAffectingCombat(unit)

            if inCombat or not C_QuestLog.UnitIsRelatedToActiveQuest(unit) 
            and wan.CheckRange(unit, 40, "<=")
            then
                isTanking = UnitDetailedThreatSituation("player", unit) or false
                return isTanking
            end
        end
    end
    
    return false
end
