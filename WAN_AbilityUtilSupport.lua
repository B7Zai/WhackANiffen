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

    if unitToken == "allGroupUnitTokens" then
        local unitsNeedHeal = wan.HealUnitCountAoE[abilityName] or 1
            for unitID, _ in pairs(wan.SupportData) do
                if not value or value == 0 then wan.SupportData[unitID][abilityName] = {} return end
                wan.SupportData[unitID][abilityName] = {
                    value = value * unitsNeedHeal,
                    icon = icon,
                    name = name,
                    desat = desaturation,
                }
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
    local nDamageScaler = wan.AdjustSoftCapUnitOverflow(4, count)

    return nDamageScaler, nGroupMembersInRange, inRangeUnits
end

function wan.GetUnitHotValues(unitToken, hotData)
    if not unitToken or not hotData then return 0, 0 end
    local totalHotValues = 0
    local countHots = 0
    local currentTime = GetTime()
    for formattedHotName, hotValue in pairs(hotData) do
        local aura = wan.auraData[unitToken]["buff_" .. formattedHotName]
        if aura then 
            local reminingHotValueMod = math.max(((aura.expirationTime - currentTime) / aura.duration), 0)
            totalHotValues = totalHotValues + (hotValue * reminingHotValueMod)
            countHots = countHots + 1
        end
    end
    return totalHotValues, countHots
end

function wan.UnitAbilityHealValue(unitToken, abilityValue, unitPercentHealth)
    if not unitToken or not abilityValue or not unitPercentHealth or abilityValue == 0 then return 0 end
    local value = 0
    local unitHotValues = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
    local maxHealth = wan.UnitState.MaxHealth[unitToken]
    local abilityPercentageValue = (abilityValue / maxHealth) or 0
    local hotPercentageValue = (unitHotValues / maxHealth) or 0

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
    local baseValue = ((initialValue or 0) + wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])) or 0
    local maxHealth = (wan.UnitState.MaxHealth[unitToken]) or 0
    local thresholdValue = maxHealth * 0.6
    local targetHealth = (maxHealth * currentPercentHealth)

    if targetHealth + baseValue > thresholdValue then return 1 end

    local healPotency = ((targetHealth + baseValue) / thresholdValue)

    return math.min(healPotency, 1)
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
    local unitMaxHealth = wan.UnitState.MaxHealth.player
    return unitMaxHealth - unitHealth
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
    local unit = unitToken or "player"
    local cooldownMS, _ = GetSpellBaseCooldown(spellIndentifier)
    local maxCooldown = math.ceil(cooldownMS / 1000 / 60)
    local maxHealth = wan.UnitState.MaxHealth[unit]
    local healthThresholds = maxHealth * 0.1
    local cooldownValue = (maxCooldown <= 1 and healthThresholds * 3)
    or (maxCooldown > 1 and maxCooldown <= 2 and healthThresholds * 5)
    or (maxCooldown >= 2 and healthThresholds * 7)
    or healthThresholds
    return cooldownValue or math.huge
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