local _, wan = ...

function wan.UpdateMechanicData(abilityName, value, icon, name, desaturation)
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

-- Counts the number of group members in range
function wan.ValidGroupMembers()
    if not IsInGroup() then return 1, 1, {} end

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
    local nDamageScaler = wan.AdjustSoftCapUnitOverflow(1, count)

    return nDamageScaler, nGroupMembersInRange, inRangeUnits
end

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

function wan.UnitAbilityHealValue(unitToken, abilityValue, unitPercentHealth)
    if not unitToken or not abilityValue or abilityValue == 0 or not unitPercentHealth then return 0 end
    local value = 0
    local unitHotValues = wan.GetUnitHotValues(unitToken)
    local maxHealth = wan.UnitState.MaxHealth[unitToken]
    local abilityPercentageValue = (abilityValue / maxHealth) or 0
    local hotPercentageValue = (unitHotValues / maxHealth) or 0
    local thresholdValue = 0.5

    if thresholdValue > unitPercentHealth and (unitPercentHealth + abilityPercentageValue) < 1 then
        value = math.floor(abilityValue)
        return value
    end

    if abilityPercentageValue < hotPercentageValue then
        return value
    end

    if (unitPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
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

-- Check and convert defensive cooldown to values
function wan.DefensiveCooldownToValue(spellIndentifier)
    local cooldownMS, _ = GetSpellBaseCooldown(spellIndentifier)
    local maxCooldown = math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = wan.UnitState.MaxHealth.player
    local healthThresholds = maxHealth * 0.1
    local cooldownValue = (maxCooldown <= 1 and healthThresholds * 3)
    or (maxCooldown > 1 and maxCooldown <= 2 and healthThresholds * 5)
    or (maxCooldown >= 2 and healthThresholds * 7)
    or healthThresholds
    return cooldownValue or math.huge
end

-- Check and convert defensive cooldown to values
function wan.UnitDefensiveCooldownToValue(spellIndentifier, unitToken)
    local cooldownMS, _ = GetSpellBaseCooldown(spellIndentifier)
    local maxCooldown = math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = wan.UnitState.MaxHealth[unitToken]
    if not maxHealth then return math.huge end

    local healthThresholds = maxHealth * 0.1
    local cooldownValue = (maxCooldown <= 1 and healthThresholds * 3)
    or (maxCooldown > 1 and maxCooldown <= 2 and healthThresholds * 5)
    or (maxCooldown >= 2 and healthThresholds * 7)
    or healthThresholds
    return cooldownValue or math.huge
end

-- Counts units that have a specific debuff
function wan.CheckClassBuff(buffName)
    local currentTime = GetTime()
    local aura = wan.auraData.player["buff_" .. buffName]
    local remainingDuration = aura and (aura.expirationTime - currentTime)

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

        if nGroupSize == nGroupMembersInRange then
            for groupUnitToken, _ in pairs(idValidGroupMember) do
                local buffed = wan.auraData[groupUnitToken]["buff_" .. buffName]
                if buffed then
                    countBuffed = countBuffed + 1
                end
            end
            return (nGroupUnits > 0 and nGroupMembersInRange > countBuffed)
        end
    end
    
    if not aura or remainingDuration < 360 then return true end
end

function wan.CheckDispelType(spellIdentifier)
    local spellDesc = C_Spell.GetSpellDescription(spellIdentifier)
    local playerDispelTypes = {}

    if not spellDesc or spellDesc == "" then
        return playerDispelTypes
    end

    local dispelTypes = { "Curse", "Disease", "Magic", "Poison", "Enrage" }

    for _, dispelType in pairs(dispelTypes) do
        if string.find(spellDesc, dispelType) then
            playerDispelTypes[dispelType] = dispelType
        end
    end

    return playerDispelTypes
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