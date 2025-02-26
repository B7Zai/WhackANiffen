local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nWakeofAshesDmg, nWakeofAshesMaxRange, nWakeofAshesDotDmg = 0, 14, 0
local formattedDebuffName = "TruthsWake"

-- Init trait data
local nSeethingFlamesHits, nSeethingFlamesDmg, nSeethingFlamesReduction = 0, 0, 0
local checkHammerofLight, nHammerofLightDmg, nHammerofLightDmgAoE, nHammerofLightUnitCap = false, 0, 0, 0
local nEmpyreanHammer, nEmpyreanHammerTicks = 0, 0
local nShaketheHeavensProcRate, nShaketheHeavensDuration, nShaketheHeavensTicks = 0, 0, 0
local nWrathfulDescent = 0
local nFinalReckoning = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.WakeofAshes.id)
    then
        wan.UpdateAbilityData(wan.spellData.WakeofAshes.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nWakeofAshesMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.WakeofAshes.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cWakeofAshesInstantDmg = 0
    local cWakeofAshesDotDmg = 0
    local cWakeofAshesInstantDmgAoE = 0
    local cWakeofAshesDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    if not checkHammerofLight then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if not checkUnitDebuff then
                local dotUnitPotency = wan.CheckDotPotency(nWakeofAshesDmg, nameplateUnitToken)

                cWakeofAshesDotDmgAoE = cWakeofAshesDotDmgAoE + (nWakeofAshesDotDmg * dotUnitPotency)
            end
        end
    end

    ---- RETRIBUTION TRAITS ----

    local cFinalReckoning = 1
    if wan.traitData.FinalReckoning.known then
        local formattedDebuffName = wan.traitData.FinalReckoning.traitkey
        local checkFinalReckoningDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

        if checkFinalReckoningDebuff then
            cFinalReckoning = cFinalReckoning + nFinalReckoning
        end
    end

    local cSeethingFlames = 1
    local cSeethingFlamesInstantDmgAoE = 0
    if wan.traitData.SeethingFlames.known and not checkHammerofLight then
        cSeethingFlamesInstantDmgAoE = cSeethingFlamesInstantDmgAoE + (nSeethingFlamesDmg * nSeethingFlamesHits)

        local nSeethingFlamesUnits = math.max(countValidUnit - 1, 0)
        if 0 < nSeethingFlamesUnits then
            cSeethingFlamesInstantDmgAoE = cSeethingFlamesInstantDmgAoE + (nSeethingFlamesDmg * nSeethingFlamesHits * (1 - nSeethingFlamesReduction) * nSeethingFlamesUnits)
            cSeethingFlames = cSeethingFlames - (nSeethingFlamesReduction * (nSeethingFlamesUnits / countValidUnit))
        end
    end

    ---- TEMPLAR TRAITS ----

    local cHammerofLightInstantDmg = 0
    local cHammerofLightInstantDmgAoE = 0
    if wan.traitData.LightsGuidance.known and checkHammerofLight then
        cHammerofLightInstantDmg = cHammerofLightInstantDmg + nHammerofLightDmg

        local countHammerofLightUnit = 0
        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                cHammerofLightInstantDmgAoE = cHammerofLightInstantDmgAoE + nHammerofLightDmgAoE
                countHammerofLightUnit = countHammerofLightUnit + 1

                if countHammerofLightUnit >= nHammerofLightUnitCap then break end
            end
        end
    end

    local cEmpyreanHammerInstantDmg = 0
    if wan.traitData.LightsGuidance.known and checkHammerofLight then

        local cWrathfulDescent = 1
        if wan.traitData.WrathfulDescent.known then
            local nWrathfulDescentUnits = math.max(countValidUnit - 1, 0)
            local nWrathfulDescentProcChance = wan.CritChance * 0.01
            cWrathfulDescent = cWrathfulDescent + (nWrathfulDescent * nWrathfulDescentUnits * nWrathfulDescentProcChance)
        end

        cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * nEmpyreanHammerTicks * cWrathfulDescent)

        if wan.traitData.ShaketheHeavens.known then
            local formattedBuffName = wan.traitData.ShaketheHeavens.traitkey
            local checkShaketheHeavensBuff = wan.CheckUnitBuff(nil, formattedBuffName)

            if not checkShaketheHeavensBuff then
                cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * nShaketheHeavensTicks * cWrathfulDescent)
            end
        end
    end

    local cWakeofAshesCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cWakeofAshesInstantDmg = cWakeofAshesInstantDmg
        + (cHammerofLightInstantDmg * cWakeofAshesCritValue * cFinalReckoning)
        + (cEmpyreanHammerInstantDmg * cWakeofAshesCritValue)

    cWakeofAshesDotDmg = cWakeofAshesDotDmg

    cWakeofAshesInstantDmgAoE = cWakeofAshesInstantDmgAoE
        + (nWakeofAshesDmg * countValidUnit * cWakeofAshesCritValue * cSeethingFlames)
        + (cSeethingFlamesInstantDmgAoE * cWakeofAshesCritValue)
        + (cHammerofLightInstantDmgAoE * cWakeofAshesCritValue)

    cWakeofAshesDotDmgAoE = cWakeofAshesDotDmgAoE * cWakeofAshesCritValue

    local cWakeofAshesDmg = cWakeofAshesInstantDmg + cWakeofAshesDotDmg + cWakeofAshesInstantDmgAoE + cWakeofAshesDotDmgAoE

    local abilityValue = math.floor(cWakeofAshesDmg)
    wan.UpdateAbilityData(wan.spellData.WakeofAshes.basename, abilityValue, wan.spellData.WakeofAshes.icon, wan.spellData.WakeofAshes.name)
end

-- Init frame 
local frameWakeofAshes = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            checkHammerofLight = wan.spellData.WakeofAshes.name == "Hammer of Light"

            local nWakeofAshesValues = wan.GetSpellDescriptionNumbers(wan.spellData.WakeofAshes.id, { 1, 3 })
            nWakeofAshesDmg = not checkHammerofLight and nWakeofAshesValues[1] or 0
            nWakeofAshesDotDmg = not checkHammerofLight  and nWakeofAshesValues[2] or 0

            local nHammerofLightValues = wan.GetTraitDescriptionNumbers(wan.traitData.LightsGuidance.entryid, { 4, 5, 6, 7, 8 })
            nHammerofLightDmg = nHammerofLightValues[1]
            nHammerofLightDmgAoE = nHammerofLightValues[2]
            nHammerofLightUnitCap = nHammerofLightValues[3]
            nEmpyreanHammerTicks = nHammerofLightValues[4]
            nEmpyreanHammer = nHammerofLightValues[5]
        end
    end)
end
frameWakeofAshes:RegisterEvent("ADDON_LOADED")
frameWakeofAshes:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WakeofAshes.known and wan.spellData.WakeofAshes.id
        wan.BlizzardEventHandler(frameWakeofAshes, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWakeofAshes, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        local nSeethingFlamesValues = wan.GetTraitDescriptionNumbers(wan.traitData.SeethingFlames.entryid, { 1, 2 })
        nSeethingFlamesHits = nSeethingFlamesValues[1]
        nSeethingFlamesDmg = nSeethingFlamesValues[2]
        nSeethingFlamesReduction = 0.4

        local nShaketheHeavensValues = wan.GetTraitDescriptionNumbers(wan.traitData.ShaketheHeavens.entryid, { 1, 2 })
        nShaketheHeavensProcRate = nShaketheHeavensValues[1]
        nShaketheHeavensDuration = nShaketheHeavensValues[2]
        nShaketheHeavensTicks = nShaketheHeavensDuration / nShaketheHeavensProcRate

        nWrathfulDescent = wan.GetTraitDescriptionNumbers(wan.traitData.WrathfulDescent.entryid, { 1 }) * 0.01

        nFinalReckoning = wan.GetTraitDescriptionNumbers(wan.traitData.FinalReckoning.entryid, { 3 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWakeofAshes, CheckAbilityValue, abilityActive)
    end
end)