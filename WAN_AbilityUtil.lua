local _, wan = ...

wan.AbilityData = wan.AbilityData or {}
wan.MechanicData = wan.MechanicData or {}

setmetatable(wan.AbilityData, {
    __index = function(t, key)
        local default = {
            value = 0,
            icon = nil,
            name = nil,
            desat = nil,
        }
        t[key] = default
        return default
    end
})

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
    if value == 0 then value, icon, name, desaturation = nil, nil, nil, nil end
    wan.AbilityData[abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

function wan.UpdateMechanicData(abilityName, value, icon, name, desaturation)
    if value == 0 then value, icon, name, desaturation = nil, nil, nil, nil end
    wan.MechanicData[abilityName] = {
        value = value,
        icon = icon,
        name = name,
        desat = desaturation,
    }
end

-- Reduce damage for "beyond x target abilities"
function wan.AdjustSoftCapUnitOverflow(capStart, numTargets)
    local maxTargets = math.min(numTargets, 20)
    if numTargets > capStart then
        return numTargets * math.sqrt(capStart / maxTargets) 
    end

    return numTargets
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

-- Counts the number of group members in range
function wan.ValidGroupMembers()
    if not IsInGroup() then return 1, 1, {} end

    local inRangeUnits = {}
    local nDamageScaler = 1
    for groupUnitID, _ in pairs(wan.GroupUnitID) do
        if not UnitIsDeadOrGhost(groupUnitID)
            and UnitIsConnected(groupUnitID)
            and UnitInRange(groupUnitID)
        then
            nDamageScaler = nDamageScaler + 1
            inRangeUnits[groupUnitID] = true
        end
    end

    local nGroupMembersInRange = nDamageScaler
    nDamageScaler = wan.AdjustSoftCapUnitOverflow(5, nDamageScaler)

    return nDamageScaler, nGroupMembersInRange, inRangeUnits
end

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

-- Checks damage reduction from armor gain
function wan.GetArmorDamageReductionFromSpell(armorValue)
    local targetLevel = math.max(UnitLevel(wan.TargetUnitID), UnitLevel("player"))
    local _, _, armor = UnitArmor("player")
    local buffedArmor = armor + armorValue
    local currentEffectiveness = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(armor) or C_PaperDollInfo.GetArmorEffectiveness(armor, targetLevel)
    local buffedEffectiveness = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(buffedArmor) or C_PaperDollInfo.GetArmorEffectiveness(buffedArmor, targetLevel)
    
    return (buffedEffectiveness - currentEffectiveness) * 100
end

---- Checks if player is missing enough health
function wan.HealThreshold()
    local unitHealth = UnitHealth("player")
    local unitMaxHealth = UnitHealthMax("player")
    return unitMaxHealth - unitHealth
end

---- Checks if player is missing enough health
function wan.AbilityPercentageToValue(percentValue)
    local percentage = percentValue or 100
    local unitMaxHealth = UnitHealthMax("player")
    return unitMaxHealth * (percentage / 100)
end

-- Check and convert defensive cooldown to values
function wan.DefensiveCooldownToValue(spellIndentifier)
    local cooldownMS, _ = GetSpellBaseCooldown(spellIndentifier)
    local maxCooldown = math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = UnitHealthMax("player")
    local healthThresholds = maxHealth * 0.1
    local cooldownValue = (maxCooldown <= 1 and healthThresholds * 3)
    or (maxCooldown > 1 and maxCooldown <= 2 and healthThresholds * 5)
    or (maxCooldown >= 2 and healthThresholds * 7)
    or healthThresholds
    return cooldownValue or math.huge
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
    if not IsInGroup() then
        return wan.auraData.player["buff_" ..buffName] == nil
    end

    local groupType = UnitInRaid("player") and "raid" or UnitInParty("player") and "party"
    local nGroupUnits = GetNumGroupMembers(groupType)
    local _, nGroupMembersInRange, idValidGroupMember = wan.ValidGroupMembers()
    local countBuffed = wan.auraData.player["buff_" .. buffName] and 1 or 0
    local nDisconnected = 0

    for groupUnitID, _ in pairs(wan.GroupUnitID) do
        local isOnline = UnitIsConnected(groupUnitID)
        if not isOnline then
            nDisconnected = nDisconnected + 1
        end
    end

    local nGroupSize = (nGroupUnits - nDisconnected)

    if nGroupSize == nGroupMembersInRange then
        for unitID, _ in pairs(idValidGroupMember or {}) do
            local buffed = wan.auraData[unitID]["buff_" .. buffName]
            if buffed then
                countBuffed = countBuffed + 1
            end
        end
        return nGroupMembersInRange > countBuffed
    end

    return false
end

-- Adjust ability dot value to unit health
function wan.CheckDotPotency(initialValue)
    local baseValue = initialValue or 0
    local maxHealth = UnitHealthMax("player")
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

    local maxHealth = UnitHealthMax("player")
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


-- Checks if a debuff on the unit matches the given aura types
function wan.CheckDispelBool(auraData, unitID, auraType)
    if auraData[unitID] then
        for auraName, aura in pairs(auraData[unitID]) do
            if auraName:find("debuff_") then
                if aura.dispelName and auraType[aura.dispelName] then
                    local hasDuration = aura.expirationTime and aura.expirationTime > 3
                    local hasStacks = aura.applications and aura.applications >= 3
                    if hasDuration or hasStacks then return true end
                end
            end
        end
    end
    return false
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





