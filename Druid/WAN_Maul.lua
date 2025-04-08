local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nMaulDmg, nMaulDmgAoE, nMaulSoftCap = 0, 0, 0

-- Init trait data
local nVulnerableFlesh = 0
local nUrsocsFury = 0
local nRazeMaxRange = 8
local nDreadfulWoundDmg, nDreadfulWoundHeal, nDreadfulWoundDR = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.Maul.id)
    then
        wan.UpdateAbilityData(wan.spellData.Maul.basename)
        wan.UpdateMechanicData(wan.spellData.Maul.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Maul.id, nRazeMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Maul.basename)
        wan.UpdateMechanicData(wan.spellData.Maul.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cMaulInstantDmg = 0
    local cMaulDotDmg = 0
    local cMaulInstantDmgAoE = 0
    local cMaulDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    if wan.traitData.VulnerableFlesh.known then
        critChanceMod = critDamageMod + nVulnerableFlesh
    end

    local cRazeInstantDmgAoE = 0
    if wan.spellData.Maul.name == "Raze" and not wan.CheckUnitBuff(nil, wan.traitData.Ravage.traitkey) then
        local cRazeUnitOverflow = wan.SoftCapOverflow(nMaulSoftCap, countValidUnit)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cRazeInstantDmgAoE = cRazeInstantDmgAoE + (nMaulDmgAoE * checkPhysicalDR * cRazeUnitOverflow)
            end
        end
    end

    local cRavageInstantDmgAoE = 0
    local cRavageDotDmgAoE = 0
    if wan.traitData.Ravage.known and wan.CheckUnitBuff(nil, wan.traitData.Ravage.traitkey) then
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local cRavageAoE = nMaulDmgAoE
                local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cRavageInstantDmgAoE = cRavageInstantDmgAoE + (cRavageAoE * checkPhysicalDR)
            end

            local cDreadfulWoundDmg = 0
            if wan.traitData.DreadfulWound.known then
                local checkDreadfulWoundDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.DreadfulWound.traitkey]
                if not checkDreadfulWoundDebuff then
                    local checkDotPotency = wan.CheckDotPotency(nMaulDmgAoE, nameplateUnitToken)
                    cDreadfulWoundDmg = cDreadfulWoundDmg + (nDreadfulWoundDmg * checkDotPotency)
                end
            end

            cRavageDotDmgAoE = cMaulDotDmgAoE + cDreadfulWoundDmg
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cMaulCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cMaulDotCritValue = wan.ValueFromCritical(wan.CritChance)

    cMaulInstantDmg = cMaulInstantDmg
        + (nMaulDmg * checkPhysicalDR * cMaulCritValue)

    cMaulDotDmg = cMaulDotDmg

    cMaulInstantDmgAoE = cMaulInstantDmgAoE
        + (cRazeInstantDmgAoE * cMaulCritValue)
        + (cRavageInstantDmgAoE * cMaulCritValue)

    cMaulDotDmgAoE = cMaulDotDmgAoE
        + (cRavageDotDmgAoE * cMaulDotCritValue)



    local cMaulDmg = cMaulInstantDmg + cMaulInstantDmgAoE + cMaulDotDmgAoE
    local cMaulHeal = 0

    -- Ursoc's Fury
    if wan.traitData.UrsocsFury.known then
        local cUrsocsFury = cMaulDmg * nUrsocsFury
        cMaulHeal = cMaulHeal + cUrsocsFury
    end

    -- Threat situation
    local isTanking = wan.IsTanking()

    -- Update ability data
    local damageValue = not isTanking and math.floor(cMaulDmg) or 0
    local healValue = isTanking and math.floor(cMaulHeal) or 0

    wan.UpdateMechanicData(wan.spellData.Maul.basename, healValue, wan.spellData.Maul.icon, wan.spellData.Maul.name)
    wan.UpdateAbilityData(wan.spellData.Maul.basename, damageValue, wan.spellData.Maul.icon, wan.spellData.Maul.name)
end

-- Init frame 
local frameMaul = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMaulValues = wan.GetSpellDescriptionNumbers(wan.spellData.Maul.id, { 1, 2, 3 })
            nMaulDmg = nMaulValues[1]
            nMaulDmgAoE = nMaulValues[2]
            nMaulSoftCap = nMaulValues[3]

            local nDreadfulWoundValues = wan.GetTraitDescriptionNumbers(wan.traitData.DreadfulWound.entryid, { 1, 3 })
            nDreadfulWoundDmg = nDreadfulWoundValues[1]
            nDreadfulWoundDR = nDreadfulWoundValues[2]
            nDreadfulWoundHeal = wan.AbilityPercentageToValue(nDreadfulWoundDR)
        end
    end)
end
frameMaul:RegisterEvent("ADDON_LOADED")
frameMaul:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Maul.known and wan.spellData.Maul.id
        wan.BlizzardEventHandler(frameMaul, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMaul, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nVulnerableFlesh = wan.GetTraitDescriptionNumbers(wan.traitData.VulnerableFlesh.entryid, { 1 }, wan.traitData.VulnerableFlesh.rank)

        nUrsocsFury = wan.GetTraitDescriptionNumbers(wan.traitData.UrsocsFury.entryid, { 1 }) / 100
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMaul, CheckAbilityValue, abilityActive)
    end
end)
