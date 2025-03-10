local _, wan = ...

-- init tables for values
wan.AbilityData = {}    -- used for displaying damage values for player
wan.MechanicData = {}   -- used for displaying defensive cooldowns, healing for player
wan.HealingData = {}    -- used for displaying healing values in a group
wan.SupportData = {}    -- used for displaying support values in a group
wan.HotValue = {}       -- used for storing hot values over all valid group units
wan.HealUnitCountAoE = {}  -- used for storing valid group unit count for aoe healing spells

local LibRangeCheck = LibStub("LibRangeCheck-3.0") -- callback for range check library

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

---- Check unit remaining health in percetage, actual value is between 0 to 1
function wan.CheckUnitPercentHealth(unitGUID)
    local checkUnitPercentHealth = unitGUID and UnitPercentHealthFromGUID(unitGUID) or 1
    return checkUnitPercentHealth
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

-- Check player's specialization 
function wan.GetTraitInfo()
    local currentSpec = GetSpecialization()
    if currentSpec then
        local id, name, description, icon, role, primaryStat = GetSpecializationInfo(currentSpec)
        return id, name, description, icon, role, primaryStat
    end
end

--- checks if a spell is usable and not on cooldown
function wan.IsSpellUsable(spellIdentifier)
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

--- checks if given unit is casting or channeling a spell
function wan.UnitIsCasting(unitToken, spellIndentifier)
    local unit = unitToken or "player"
    local castName, _, _, _, _, _, _, _, castSpellID = UnitCastingInfo(unit)

    if spellIndentifier == castName or spellIndentifier == castSpellID then
        return true
    end

    local channelName, _, _, _, _, _, _, channelSpellID = UnitChannelInfo(unitToken)

    if spellIndentifier == channelName or spellIndentifier == channelSpellID then
        return true
    end

    return false
end

--- checks the amount of absorb the given unit has
function wan.CheckUnitAbsorb(unitToken)
    local totalAbsorbs = unitToken and UnitGetTotalAbsorbs(unitToken) or 0

    return totalAbsorbs
end

--- check how much stacks / charges a spell holds
function wan.CheckSpellCharges(spellIdentifier)
    if not spellIdentifier then return 0 end

    local chargeInfo = C_Spell.GetSpellCharges(spellIdentifier)

    if chargeInfo then
        return chargeInfo.currentCharges, chargeInfo.maxCharges
    end

    return 0
end
