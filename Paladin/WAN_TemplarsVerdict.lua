local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nTemplarsVerdict = 0

-- Init trait data
local nGreaterJudgment = 0
local nJudgeJuryandExecutionerUnitCap, nJudgeJuryandExecutioner = 0, 0
local nDivineArbiterStacks, nDivineArbiter, nDivineArbiterAoE = 0, 0, 0
local nFinalReckoning = 0
local checkHammerofLight = false
local nEmpyreanHammer = 0
local nWrathfulDescent = 0
local nDawnlightDotDmg, nDawnlightDotDmgAoE, nDawnlightSoftCap = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or checkHammerofLight
        or not wan.IsSpellUsable(wan.spellData.TemplarsVerdict.id)
    then
        wan.UpdateAbilityData(wan.spellData.TemplarsVerdict.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.TemplarsVerdict.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.TemplarsVerdict.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cTemplarsVerdictInstantDmg = nTemplarsVerdict
    local cTemplarsVerdictDotDmg = 0
    local cTemplarsVerdictInstantDmgAoE = 0
    local cTemplarsVerdictDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cGreaterJudgment = 1
    local cGreaterJudgmentAoE = 1
    if wan.traitData.GreaterJudgment.known then
        local formattedDebuffName = wan.spellData.Judgment.basename
        local checkGreaterJudgmentDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)

        if checkGreaterJudgmentDebuff then
            cGreaterJudgment = cGreaterJudgment + nGreaterJudgment
        end

        if wan.traitData.JudgeJuryandExecutioner.known then
            local formattedBuffName = wan.traitData.JudgeJuryandExecutioner.traitkey
            local checkJudgeJuryandExecutionerBuff = wan.CheckUnitBuff(nil, formattedBuffName)

            if checkJudgeJuryandExecutionerBuff then
                local nGreaterJudgmentUnits = math.max(countValidUnit - 1, 0)
                local countJudgeJuryandExecutionerUnit = 0
                local countGreaterJudgmentDebuff = 0

                for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then
                        countJudgeJuryandExecutionerUnit = countJudgeJuryandExecutionerUnit + 1
                        local checkUnitGreaterJudgmentDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
                        if checkUnitGreaterJudgmentDebuff then
                            countGreaterJudgmentDebuff = countGreaterJudgmentDebuff + 1
                        end

                        if countJudgeJuryandExecutionerUnit >= nJudgeJuryandExecutionerUnitCap then break end
                    end
                end

                cGreaterJudgmentAoE = cGreaterJudgmentAoE + (nGreaterJudgment * (countGreaterJudgmentDebuff / nGreaterJudgmentUnits))
            end
        end
    end

    ---- RETRIBUTION TRAITS ----

    local cEmpyreanLegacy = 0
    if wan.traitData.EmpyreanLegacy.known then
        local formattedBuffName = wan.traitData.EmpyreanLegacy.traitkey
        local checkEmpyreanLegacyBuff = wan.CheckUnitBuff(nil, formattedBuffName)

        if checkEmpyreanLegacyBuff then
            local checkDivineStorm = wan.AbilityData[wan.spellData.DivineStorm.basename]
            if checkDivineStorm and checkDivineStorm.value then
                cEmpyreanLegacy = cEmpyreanLegacy + checkDivineStorm.value
            end
        end
    end

    local cJudgeJuryandExecutionerInstantDmgAoE = 0
    if wan.traitData.JudgeJuryandExecutioner.known then
        local formattedBuffName = wan.traitData.JudgeJuryandExecutioner.traitkey
        local checkJudgeJuryandExecutionerBuff = wan.CheckUnitBuff(nil, formattedBuffName)

        if checkJudgeJuryandExecutionerBuff then
            local countJudgeJuryandExecutionerUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cJudgeJuryandExecutionerInstantDmgAoE = cJudgeJuryandExecutionerInstantDmgAoE + (nTemplarsVerdict * nJudgeJuryandExecutioner)
                    countJudgeJuryandExecutionerUnit = countJudgeJuryandExecutionerUnit + 1

                    if countJudgeJuryandExecutionerUnit >= nJudgeJuryandExecutionerUnitCap then break end
                end
            end
        end
    end

    local cDivineArbiterInstantDmg = 0
    local cDivineArbiterInstantDmgAoE = 0
    if wan.traitData.DivineArbiter.known then
        local formattedBuffName = wan.traitData.DivineArbiter.traitkey
        local checkDivineArbiterBuff = wan.CheckUnitBuff(nil, formattedBuffName)

        if checkDivineArbiterBuff and checkDivineArbiterBuff.applications >= nDivineArbiterStacks then
            cDivineArbiterInstantDmg = cDivineArbiterInstantDmg + nDivineArbiter

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cDivineArbiterInstantDmgAoE = cDivineArbiterInstantDmgAoE + nDivineArbiterAoE
                end
            end
        end
    end

    local cFinalReckoning = 1
    local cFinalReckoningAoE = 1
    if wan.traitData.FinalReckoning.known then
        local formattedDebuffName = wan.traitData.FinalReckoning.traitkey
        local checkFinalReckoningDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)

        if checkFinalReckoningDebuff then
            cFinalReckoning = cFinalReckoning + nFinalReckoning
        end

        if wan.traitData.JudgeJuryandExecutioner.known then
            local formattedBuffName = wan.traitData.JudgeJuryandExecutioner.traitkey
            local checkJudgeJuryandExecutionerBuff = wan.CheckUnitBuff(nil, formattedBuffName)

            if checkJudgeJuryandExecutionerBuff then
                local nFinalReckoningUnits = math.max(countValidUnit - 1, 0)
                local countJudgeJuryandExecutionerUnit = 0
                local countFinalReckoningDebuff = 0

                for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then
                        countJudgeJuryandExecutionerUnit = countJudgeJuryandExecutionerUnit + 1
                        local checkUnitFinalReckoningDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                        if checkUnitFinalReckoningDebuff then
                            countFinalReckoningDebuff = countFinalReckoningDebuff + 1
                        end

                        if countJudgeJuryandExecutionerUnit >= nJudgeJuryandExecutionerUnitCap then break end
                    end
                end

                if countFinalReckoningDebuff > 0 then
                    cFinalReckoningAoE = cFinalReckoningAoE + (nFinalReckoning * (countFinalReckoningDebuff / nFinalReckoningUnits))
                end
            end
        end
    end

    ---- HERALD OF THE SUN TRAITS ----

    local cDawnlightDotDmg = 0
    local cDawnlightDotDmgAoE = 0
    if wan.traitData.Dawnlight.known then
        local formattedBuffName = wan.traitData.Dawnlight.traitkey
        local checkDawnlightBuff = wan.CheckUnitBuff(nil, formattedBuffName)
        local checkDawnlightDebuff = wan.CheckUnitDebuff(nil, formattedBuffName)
        local nDawnlightUnitOverflow = wan.AdjustSoftCapUnitOverflow(nDawnlightSoftCap, countValidUnit)

        if checkDawnlightBuff and not checkDawnlightDebuff then
            local dotPotency = wan.CheckDotPotency(nTemplarsVerdict, targetUnitToken)

            cDawnlightDotDmg = cDawnlightDotDmg + (nDawnlightDotDmg * dotPotency)
            cDawnlightDotDmgAoE = cDawnlightDotDmgAoE + (nDawnlightDotDmg * dotPotency * nDawnlightDotDmgAoE * nDawnlightUnitOverflow)
        end
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

    local cTemplarsVerdictCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cTemplarsVerdictInstantDmg = (cTemplarsVerdictInstantDmg * cTemplarsVerdictCritValue * cGreaterJudgment * cFinalReckoning)
        + (cDivineArbiterInstantDmg * cTemplarsVerdictCritValue)
        + (cEmpyreanHammerInstantDmg * cTemplarsVerdictCritValue)

    cTemplarsVerdictDotDmg = cTemplarsVerdictDotDmg
        + (cDawnlightDotDmg * cTemplarsVerdictCritValue)

    cTemplarsVerdictInstantDmgAoE = cTemplarsVerdictInstantDmgAoE
        + (cJudgeJuryandExecutionerInstantDmgAoE * cTemplarsVerdictCritValue * cGreaterJudgmentAoE * cFinalReckoningAoE)
        + (cDivineArbiterInstantDmgAoE * cTemplarsVerdictCritValue)
        + cEmpyreanLegacy

    cTemplarsVerdictDotDmgAoE = cTemplarsVerdictDotDmgAoE
        + (cDawnlightDotDmgAoE * cTemplarsVerdictCritValue)
        
    local cTemplarsVerdictDmg = cTemplarsVerdictInstantDmg + cTemplarsVerdictDotDmg + cTemplarsVerdictInstantDmgAoE + cTemplarsVerdictDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cTemplarsVerdictDmg)
    wan.UpdateAbilityData(wan.spellData.TemplarsVerdict.basename, abilityValue, wan.spellData.TemplarsVerdict.icon, wan.spellData.TemplarsVerdict.name)
end

-- Init frame 
local frameTemplarsVerdict = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nTemplarsVerdict = wan.GetSpellDescriptionNumbers(wan.spellData.TemplarsVerdict.id, { 1 })

            local nDivineArbiterValues = wan.GetTraitDescriptionNumbers(wan.traitData.DivineArbiter.entryid, { 1, 2, 3 })
            nDivineArbiterStacks = nDivineArbiterValues[1]
            nDivineArbiter = nDivineArbiterValues[2]
            nDivineArbiterAoE = nDivineArbiterValues[3]

            checkHammerofLight = wan.spellData.WakeofAshes.name == "Hammer of Light"

            nEmpyreanHammer = wan.GetTraitDescriptionNumbers(wan.traitData.LightsGuidance.entryid, { 8 })

            local nDawnlightValues = wan.GetTraitDescriptionNumbers(wan.traitData.Dawnlight.entryid, { 2, 5, 6 })
            nDawnlightDotDmg = nDawnlightValues[1]
            nDawnlightDotDmgAoE = nDawnlightValues[2] * 0.01
            nDawnlightSoftCap = nDawnlightValues[3]
        end
    end)
end
frameTemplarsVerdict:RegisterEvent("ADDON_LOADED")
frameTemplarsVerdict:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TemplarsVerdict.known and wan.spellData.TemplarsVerdict.id
        wan.BlizzardEventHandler(frameTemplarsVerdict, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameTemplarsVerdict, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nGreaterJudgment = wan.GetTraitDescriptionNumbers(wan.traitData.GreaterJudgment.entryid, { 1 }) * 0.01

        local nJudgeJuryandExecutionerValues = wan.GetTraitDescriptionNumbers(wan.traitData.JudgeJuryandExecutioner.entryid, { 1, 2 })
        nJudgeJuryandExecutionerUnitCap = nJudgeJuryandExecutionerValues[1]
        nJudgeJuryandExecutioner = nJudgeJuryandExecutionerValues[2] * 0.01

        nFinalReckoning = wan.GetTraitDescriptionNumbers(wan.traitData.FinalReckoning.entryid, { 2 }) * 0.01

        nWrathfulDescent = wan.GetTraitDescriptionNumbers(wan.traitData.WrathfulDescent.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTemplarsVerdict, CheckAbilityValue, abilityActive)
    end
end)