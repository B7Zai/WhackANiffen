local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nWildfireBombInstantDmg, nWildfireBombDotDmg, nWildfireBombSoftCap, nWildfireBomb = 0, 0, 0, 0

-- Init trait data
local nHowlOfThePack = 0
local nLunarStormDuration, nLunarStormDmg, nLunarStormTickRate, nLunarStorm, nLunarStormICD, cLunarStormLastProc = 0, 0, 0, 0, 0, GetTime()


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.WildfireBomb.id)
    then
        wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.WildfireBomb.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cWildfireBombInstantDmg = nWildfireBombInstantDmg
    local cWildfireBombDotDmg = 0
    local cWildfireBombInstantDmgAoE = 0
    local cWildfireBombDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkWildfireBombDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.WildfireBomb.basename]
    if not checkWildfireBombDebuff then
        local dotPotency = wan.CheckDotPotency(nWildfireBombInstantDmg, targetUnitToken)
        cWildfireBombDotDmg = cWildfireBombDotDmg + (nWildfireBombDotDmg * dotPotency)
    end

    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
        
        if nameplateGUID ~= targetGUID then
            local checkUnitWildfireBombDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.WildfireBomb.basename]
            cWildfireBombInstantDmgAoE = cWildfireBombInstantDmgAoE + nWildfireBombInstantDmg

            if not checkUnitWildfireBombDebuff then
                local dotPotency = wan.CheckDotPotency(nWildfireBombInstantDmg, nameplateUnitToken)
                cWildfireBombDotDmgAoE = cWildfireBombDotDmgAoE + (nWildfireBombDotDmg * dotPotency)
            end
        end
    end

    ---- PACK LEADER TRAITS ----

    if wan.traitData.HowlofthePack.known then
        local checkHowlOfThePackBuff = wan.auraData.player["buff_" .. wan.traitData.HowlofthePack.traitkey]
        if checkHowlOfThePackBuff then
            local stacksHowlOfThePack = checkHowlOfThePackBuff.applications
            critDamageMod = critDamageMod + (nHowlOfThePack * stacksHowlOfThePack)
        end
    end

    ---- SENTINEL TRAITS ----

    local cLunarStorm = 0
    if wan.traitData.LunarStorm.known then
        local currentTime = GetTime()
        local cLunarStormLast = currentTime - cLunarStormLastProc
        if cLunarStormLast > nLunarStormICD then
            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkLunarStormDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.LunarStorm.traitkey]
                if checkLunarStormDebuff then cLunarStormLastProc = GetTime() break end
            end
            cLunarStorm = cLunarStorm + nLunarStorm 
        end
    end
    
    local cWildfireBombUnitOverflow = wan.SoftCapOverflow(nWildfireBombSoftCap, countValidUnit)
    local cWildfireBombCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cWildfireBombInstantDmg = cWildfireBombInstantDmg * nWildfireBomb * cWildfireBombUnitOverflow * cWildfireBombCritValue
    cWildfireBombDotDmg = cWildfireBombDotDmg * nWildfireBomb * cWildfireBombUnitOverflow * cWildfireBombCritValue
    cWildfireBombInstantDmgAoE = cWildfireBombInstantDmgAoE * cWildfireBombUnitOverflow * cWildfireBombCritValue + (cLunarStorm * cWildfireBombCritValue)
    cWildfireBombDotDmgAoE = cWildfireBombDotDmgAoE * cWildfireBombUnitOverflow * cWildfireBombCritValue

    local cWildfireBombDmg = cWildfireBombInstantDmg + cWildfireBombDotDmg + cWildfireBombInstantDmgAoE + cWildfireBombDotDmgAoE

    local abilityValue = math.floor(cWildfireBombDmg)
    wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename, abilityValue, wan.spellData.WildfireBomb.icon, wan.spellData.WildfireBomb.name)
end

-- Init frame 
local frameWildfireBomb = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nWildfireBombValues = wan.GetSpellDescriptionNumbers(wan.spellData.WildfireBomb.id, { 1, 2, 4, 5 })
            nWildfireBombInstantDmg = nWildfireBombValues[1]
            nWildfireBombDotDmg = nWildfireBombValues[2]
            nWildfireBombSoftCap = nWildfireBombValues[3]
            nWildfireBomb = 1 + (nWildfireBombValues[4] * 0.01)

            local nLunarStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.LunarStorm.entryid, { 1, 3, 4, 5 })
            nLunarStormICD = nLunarStormValues[1]
            nLunarStormDuration = nLunarStormValues[2]
            nLunarStormDmg = nLunarStormValues[3]
            nLunarStormTickRate = nLunarStormValues[4]
            nLunarStorm = nLunarStormValues[3] *  (nLunarStormValues[2] / nLunarStormValues[4])
        end
    end)
end
frameWildfireBomb:RegisterEvent("ADDON_LOADED")
frameWildfireBomb:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WildfireBomb.known and wan.spellData.WildfireBomb.id
        wan.BlizzardEventHandler(frameWildfireBomb, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWildfireBomb, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nHowlOfThePack = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePack.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWildfireBomb, CheckAbilityValue, abilityActive)
    end
end)