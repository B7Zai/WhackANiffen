local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nDivineStormDmg, nDivineStormSoftCap, nDivineStormMaxRange = 0, 0, 11

-- Init trait data
local nGreaterJudgment = 0
local nTempestoftheLightbringer = 0
local nHolyFlames, nHolyFlamesUnitCap, nExpurgation  = 0, 0, 0
local nFinalReckoning = 0
local nLuminosity = 0
local nSunSearDotDmg, nSunSearProcChance = 0, 0
local nSecondSunriseProcChance, nSecondSunrise = 0, 0
local checkHammerofLight = false
local nEmpyreanHammer = 0
local nWrathfulDescent = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or checkHammerofLight
        or not wan.IsSpellUsable(wan.spellData.DivineStorm.id)
    then
        wan.UpdateAbilityData(wan.spellData.DivineStorm.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nDivineStormMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.DivineStorm.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cDivineStormInstantDmg = 0
    local cDivineStormDotDmg = 0
    local cDivineStormInstantDmgAoE = 0
    local cDivineStormDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cGreaterJudgmentAoE = 1
    if wan.traitData.GreaterJudgment.known then
        local formattedDebuffName = wan.spellData.Judgment.basename
        local countGreaterJudgmentDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitGreaterJudgmentDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            if checkUnitGreaterJudgmentDebuff then
                countGreaterJudgmentDebuff = countGreaterJudgmentDebuff + 1
            end
        end

        if countGreaterJudgmentDebuff > 0 then
            cGreaterJudgmentAoE = cGreaterJudgmentAoE + (nGreaterJudgment * (countGreaterJudgmentDebuff / countValidUnit))
        end
    end

    ---- RETRIBUTION TRAITS ----

    local cTempestoftheLightbringer = 1
    if wan.traitData.TempestoftheLightbringer.known then
        cTempestoftheLightbringer = cTempestoftheLightbringer + nTempestoftheLightbringer
    end

    local cHolyFlamesAoE = 1
    local cHolyFlamesDotDmgAoE = 0
    if wan.traitData.HolyFlames.known then
        local formattedDebuffName = wan.traitData.Expurgation.traitkey

        local checkExpurgationDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)
        local countExpurgationDebuff = 0
        if checkExpurgationDebuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    local checkExpurgationUnitDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                    if not checkExpurgationUnitDebuff then
                        local unitDotPotency = wan.CheckDotPotency(nDivineStormDmg, nameplateUnitToken)

                        cHolyFlamesDotDmgAoE = cHolyFlamesDotDmgAoE + (nExpurgation * unitDotPotency)

                        countExpurgationDebuff = countExpurgationDebuff + 1

                        if countExpurgationDebuff >= nHolyFlamesUnitCap then break end
                    end
                end
            end
        end

        local countHolyFlames = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkExpurgationDebuffAoE = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            if checkExpurgationDebuffAoE then
                countHolyFlames = countHolyFlames + 1
            end
        end

        if countHolyFlames > 0 then
            cHolyFlamesAoE = cHolyFlamesAoE + (nHolyFlames * (countHolyFlames / countValidUnit))
        end
    end

    local cFinalReckoningAoE = 1
    if wan.traitData.FinalReckoning.known then
        local formattedDebuffName = wan.traitData.FinalReckoning.traitkey
        local countFinalReckoningDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkFinalReckoningDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            if checkFinalReckoningDebuff then
                countFinalReckoningDebuff = countFinalReckoningDebuff + 1
            end
        end

        if countFinalReckoningDebuff > 0 then
            cFinalReckoningAoE = cFinalReckoningAoE + (nFinalReckoning * (countFinalReckoningDebuff / countValidUnit))
        end
    end

    ---- HERALD OF THE SUN TRAITS ----

    if wan.traitData.Luminosity.known then
        critChanceMod = critChanceMod + nLuminosity
    end

    local cSunSearDotDmgAoE = 0
    if wan.traitData.SunSear.known then
        cSunSearDotDmgAoE = cSunSearDotDmgAoE + (nSunSearDotDmg * nSunSearProcChance * countValidUnit)
    end

    local cSecondSunriseInstantDmgAoE = 0
    if wan.traitData.SecondSunrise.known then
        cSecondSunriseInstantDmgAoE = cSecondSunriseInstantDmgAoE + (nDivineStormDmg * nSecondSunriseProcChance * nSecondSunrise)
    end

    --- TEMPLAR TRAITS ----

    local cEmpyreanHammerInstantDmg = 0
    if wan.traitData.LightsGuidance.known then

        local cWrathfulDescent = 1
        if wan.traitData.WrathfulDescent.known then
            local nWrathfulDescentUnits = math.max(countValidUnit - 1, 0)
            local nWrathfulDescentProcChance = wan.CritChance * 0.01
            cWrathfulDescent = cWrathfulDescent + (nWrathfulDescent * nWrathfulDescentUnits * nWrathfulDescentProcChance)
        end

        cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * cWrathfulDescent)

        if wan.traitData.Hammerfall.known then
            local formattedBuffName = wan.traitData.ShaketheHeavens.traitkey
            local checkShaketheHeavensBuff = wan.CheckUnitBuff(nil, formattedBuffName)

            if checkShaketheHeavensBuff then
                cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg + (nEmpyreanHammer * cWrathfulDescent)
            end
        end
    end

    local cDivineStormUnitOverflow = wan.AdjustSoftCapUnitOverflow(nDivineStormSoftCap, countValidUnit)
    local cDivineStormCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cDivineStormCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cDivineStormInstantDmg = cDivineStormInstantDmg
        + (cEmpyreanHammerInstantDmg * cDivineStormCritValueBase)

    cDivineStormDotDmg = cDivineStormDotDmg

    cDivineStormInstantDmgAoE = cDivineStormInstantDmgAoE
        + (nDivineStormDmg * cDivineStormUnitOverflow * cGreaterJudgmentAoE * cTempestoftheLightbringer * cHolyFlamesAoE * cFinalReckoningAoE * cDivineStormCritValue)
        + (cSecondSunriseInstantDmgAoE * cDivineStormUnitOverflow * cGreaterJudgmentAoE * cTempestoftheLightbringer * cFinalReckoningAoE * cDivineStormCritValue)

    cDivineStormDotDmgAoE = cDivineStormDotDmgAoE
        + (cHolyFlamesDotDmgAoE * cDivineStormCritValueBase)
        + (cSunSearDotDmgAoE * cDivineStormCritValueBase)

    local cDivineStormDmg = cDivineStormInstantDmg + cDivineStormDotDmg + cDivineStormInstantDmgAoE + cDivineStormDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cDivineStormDmg)
    wan.UpdateAbilityData(wan.spellData.DivineStorm.basename, abilityValue, wan.spellData.DivineStorm.icon, wan.spellData.DivineStorm.name)
end

-- Init frame 
local frameDivineStorm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nDivineStormValues = wan.GetSpellDescriptionNumbers(wan.spellData.DivineStorm.id, { 1, 2 })
            nDivineStormDmg = nDivineStormValues[1]
            nDivineStormSoftCap = nDivineStormValues[2]

            nExpurgation = wan.GetTraitDescriptionNumbers(wan.traitData.Expurgation.entryid, { 1 })

            nSunSearDotDmg = wan.GetTraitDescriptionNumbers(wan.traitData.SunSear.entryid, { 1 })
            nSunSearProcChance = wan.CritChance * 0.01

            checkHammerofLight = wan.spellData.WakeofAshes.name == "Hammer of Light"

            nEmpyreanHammer = wan.GetTraitDescriptionNumbers(wan.traitData.LightsGuidance.entryid, { 8 })
        end
    end)
end
frameDivineStorm:RegisterEvent("ADDON_LOADED")
frameDivineStorm:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DivineStorm.known and wan.spellData.DivineStorm.id
        wan.BlizzardEventHandler(frameDivineStorm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDivineStorm, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nGreaterJudgment = wan.GetTraitDescriptionNumbers(wan.traitData.GreaterJudgment.entryid, { 1 }) * 0.01

        nTempestoftheLightbringer = wan.GetTraitDescriptionNumbers(wan.traitData.TempestoftheLightbringer.entryid, { 2 }) * 0.01

        local nHolyFlamesValues= wan.GetTraitDescriptionNumbers(wan.traitData.HolyFlames.entryid, { 2, 3 })
        nHolyFlamesUnitCap = nHolyFlamesValues[1]
        nHolyFlames = nHolyFlamesValues[2] * 0.01

        nFinalReckoning = wan.GetTraitDescriptionNumbers(wan.traitData.FinalReckoning.entryid, { 3 }) * 0.01

        nLuminosity = wan.GetTraitDescriptionNumbers(wan.traitData.Luminosity.entryid, { 1 })

        local nSecondSunriseValues = wan.GetTraitDescriptionNumbers(wan.traitData.SecondSunrise.entryid, { 1, 2 })
        nSecondSunriseProcChance = nSecondSunriseValues[1] * 0.01
        nSecondSunrise = nSecondSunriseValues[2] * 0.01

        nWrathfulDescent = wan.GetTraitDescriptionNumbers(wan.traitData.WrathfulDescent.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDivineStorm, CheckAbilityValue, abilityActive)
    end
end)