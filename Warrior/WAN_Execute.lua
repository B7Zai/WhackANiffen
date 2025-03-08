local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nExecuteDmg, nExecuteMaxRange = 0, 0
local nColossusSmash = 0
local checkMinCost, checkCost, checkMedianCost = 0, 0, 0
local currentRage = 0
local maxRageMod = 0.1

-- Init trait data
local nBarbaricTraining = 0
local nCruelStrikes = 0
local nMasteryDeepWounds = 0
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 0, 0
local nSuddentDeath = maxRageMod
local nImpale = 0
local nSharpenedBladesCritChance, nSharpenedBladesCritDamage = 0, 0
local nMartialExpertCritDamage = 0
local nFatalityThreshold, nFatalityDmg = 0, 0
local nSlayersDominance = 0
local nShowNoMercy = 0
local nOverwhelmingBlades = 0
local nDominanceoftheColossus = 0
local nAshenJuggernautCritChance = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nRecklessnessCritChance = 0
local nLightningStrikesProcChance, nLightningStrikesDmg, nLightningStrikesProcModAvatar = 0, 0, 0
local nGroundCurrentDmg, nGroundCurrentSoftCap = 0, 0
local nGatheringCloudsProcMod = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Execute.id)
        or (wan.PlayerState.Role == "TANK" and wan.spellData.IgnorePain.known and not wan.IsSpellUsable(wan.spellData.IgnorePain.id))
    then
        wan.UpdateAbilityData(wan.spellData.Execute.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Execute.id, nExecuteMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Execute.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cExecuteInstantDmg = 0
    local cExecuteDotDmg = 0
    local cExecuteInstantDmgAoE = 0
    local cExecuteDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cExecuteRageMod = 1
    local cRageMod = math.min((currentRage - checkMedianCost) * 0.01, maxRageMod)
    cExecuteRageMod = cExecuteRageMod + cRageMod

    ---- WARRIOR TRAITS ----

    if wan.traitData.BarbaricTraining.known then
        critDamageMod = critDamageMod + nBarbaricTraining
    end

    if wan.traitData.CruelStrikes.known then
        critDamageMod = critDamageMod + nCruelStrikes
    end

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cSweepingStrikesInstantDmgAoE = 0
    local checkSweepingStrikesBuff = nil
    if wan.spellData.SweepingStrikes.known then
        local countSweepingStrikesUnit = 0
        checkSweepingStrikesBuff = wan.CheckUnitBuff(nil, wan.spellData.SweepingStrikes.formattedName)

        if checkSweepingStrikesBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + (nExecuteDmg * nSweepingStrikes * checkUnitPhysicalDR)
                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end
    end

    local cMasteryDeepWounds = 1
    local cMasteryDeepWoundsAoE = 1
    if wan.spellData.MasteryDeepWounds.known then
        local checkMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nil, "DeepWounds")
        if checkMasteryDeepWoundsDebuff then
            cMasteryDeepWounds = cMasteryDeepWounds + nMasteryDeepWounds
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countSweepingStrikesUnit = 0
            local countMasteryDeepWoundsDebuff = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "DeepWounds")

                    if checkUnitMasteryDeepWoundsDebuff then
                        countMasteryDeepWoundsDebuff = countMasteryDeepWoundsDebuff + 1
                    end

                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end

            if countMasteryDeepWoundsDebuff > 0 then
                cMasteryDeepWoundsAoE = cMasteryDeepWoundsAoE + ((nMasteryDeepWounds * countMasteryDeepWoundsDebuff) / cSweepingStrikesUnit)
            end
        end
    end

    local cColossusSmash = 1
    local cColossusSmashAoE = 1
    if wan.traitData.ColossusSmash.known then
        local formattedDebuffName = wan.traitData.ColossusSmash.traitkey
        local checkColossusSmashDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

        if checkColossusSmashDebuff then
            cColossusSmash = cColossusSmash + nColossusSmash
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countColossusSmashDebuff = 0
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitColossusSmashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                    if checkUnitColossusSmashDebuff then
                        countColossusSmashDebuff = countColossusSmashDebuff + 1
                    end

                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end

            if countColossusSmashDebuff > 0 then
                cColossusSmashAoE = cColossusSmashAoE + ((nColossusSmash * countColossusSmashDebuff) / cSweepingStrikesUnit)
            end
        end
    end

    if wan.traitData.Impale.known then
        critDamageMod = critDamageMod + nImpale
    end

    if wan.traitData.SuddenDeath.known then
        local checkSuddenDeathBuff = wan.CheckUnitBuff(nil, wan.traitData.SuddenDeath.traitkey)
        if checkSuddenDeathBuff then
            cExecuteRageMod = 1 + nSuddentDeath
        end
    end

    if wan.traitData.SharpenedBlades.known then
        critChanceMod = critChanceMod + nSharpenedBladesCritChance
        critDamageMod = critDamageMod + nSharpenedBladesCritDamage
    end

    local cFatalityInstantDmg = 0
    local cFatalityInstantDmgAoE = 0
    if wan.traitData.Fatality.known then
        local checkHealthPercentage = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if checkHealthPercentage < nFatalityThreshold then
            local checkFatalityDebuff = wan.CheckUnitDebuff(nil, "FatalMark")

            if checkFatalityDebuff then
                local cFatalityStacks = checkFatalityDebuff.applications
                cFatalityInstantDmg = cFatalityInstantDmg + (nFatalityDmg * cFatalityStacks)
            end
        end

        if checkSweepingStrikesBuff then
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitHealthPercentage = UnitPercentHealthFromGUID(nameplateUnitToken) or 1

                    if checkUnitHealthPercentage < nFatalityThreshold then
                        local checkUnitFatalityDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "FatalMark")

                        if checkUnitFatalityDebuff then
                            local cUnitFatalityStacks = checkUnitFatalityDebuff.applications
                            cFatalityInstantDmgAoE = cFatalityInstantDmgAoE + (nFatalityDmg * cUnitFatalityStacks)
                        end
                    end

                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end
    end

    ---- FURY TRAITS ----

    if wan.traitData.ImprovedExecute.known then
        cExecuteRageMod = 1
    end

    local cImprovedWhirlwindInstantDmgAoE = 0
    local checkImprovedWhirlwindBuff = nil
    local countImprovedWhirlwindUnit = 0
    if wan.traitData.ImprovedWhirlwind.known then
        checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if checkImprovedWhirlwindBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nExecuteDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    if wan.traitData.AshenJuggernaut.known then
        local checkAshenJuggernautBuff = wan.CheckUnitBuff(nil, wan.traitData.AshenJuggernaut.traitkey)
        if checkAshenJuggernautBuff then
            local cAshenJuggernautStacks = checkAshenJuggernautBuff.applications
            critChanceMod = critChanceMod + (nAshenJuggernautCritChance * cAshenJuggernautStacks)
        end
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local cDominanceoftheColossus = 1
    local cDominanceoftheColossusAoE = 1
    if wan.traitData.DominanceoftheColossus.known then
        local checkWreckedDebuff = wan.CheckUnitDebuff(nil, "Wrecked")

        if checkWreckedDebuff then
            local cWreckedStacks = checkWreckedDebuff.applications
            cDominanceoftheColossus = cDominanceoftheColossus + (nDominanceoftheColossus * cWreckedStacks)
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitWreckedDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Wrecked")

                    if checkUnitWreckedDebuff then
                        local cUnitWreckedStacks = checkUnitWreckedDebuff.applications

                        cDominanceoftheColossusAoE = cDominanceoftheColossusAoE + ((nDominanceoftheColossus * cUnitWreckedStacks) / cSweepingStrikesUnit)
                    end

                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end
    end

    ---- MOUNTAIN THANE ----

    local cLightningStrikesInstantDmg = 0
    local cLightningStrikesInstantDmgAoE = 0
    if wan.traitData.LightningStrikes.known then
        local cLightningStrikesProcChance = nLightningStrikesProcChance

        local checkAvatarBuff = wan.CheckUnitBuff(nil, wan.spellData.Avatar.formattedName)
        if checkAvatarBuff then
            cLightningStrikesProcChance = cLightningStrikesProcChance * nLightningStrikesProcModAvatar
        end

        if wan.traitData.GatheringClouds.known then
            cLightningStrikesProcChance = cLightningStrikesProcChance * nGatheringCloudsProcMod
        end

        cLightningStrikesInstantDmg = cLightningStrikesInstantDmg + (nLightningStrikesDmg * cLightningStrikesProcChance)

        if wan.traitData.GroundCurrent.known then
            local cGroundCurrentUnitOverflow = wan.SoftCapOverflow(nGroundCurrentSoftCap, countValidUnit)

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cLightningStrikesInstantDmgAoE = cLightningStrikesInstantDmgAoE + (nGroundCurrentDmg * cGroundCurrentUnitOverflow * cLightningStrikesProcChance)
                end
            end
        end
    end

    ---- SLAYER TRAITS ----

    local cSlayersDominance = 1
    local cSlayersDominanceAoE = 1
    if wan.traitData.SlayersDominance.known then
        local checkSlayersDominanceDebuff = wan.CheckUnitDebuff(nil, "MarkedforExecution")
        local cShowNoMercyUnitCap = math.min(countValidUnit, (nSweepingStrikesUnitCap + 1))

        if checkSlayersDominanceDebuff then
            local cSlayersDominanceStacks = checkSlayersDominanceDebuff.applications
            cSlayersDominance = cSlayersDominance + (nSlayersDominance * cSlayersDominanceStacks)

            if wan.traitData.ShowNoMercy.known then
                critChanceMod = critChanceMod + (nShowNoMercy / cShowNoMercyUnitCap)
                critDamageMod = critDamageMod + (nShowNoMercy / cShowNoMercyUnitCap)
            end
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitSlayersDominanceDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "MarkedforExecution")

                    if checkUnitSlayersDominanceDebuff then
                        local cUnitSlayersDominanceStacks = checkUnitSlayersDominanceDebuff.applications

                        cSlayersDominanceAoE = cSlayersDominanceAoE + (nSlayersDominance * cUnitSlayersDominanceStacks)

                        if wan.traitData.ShowNoMercy.known then
                            critChanceMod = critChanceMod + (nShowNoMercy / cShowNoMercyUnitCap)
                            critDamageMod = critDamageMod + (nShowNoMercy / cShowNoMercyUnitCap)
                        end

                        countSweepingStrikesUnit = countSweepingStrikesUnit + 1
                    end

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end

            if countSweepingStrikesUnit > 0 then
                cSlayersDominanceAoE = cSlayersDominanceAoE / cSweepingStrikesUnit
            end
        end

        if checkImprovedWhirlwindBuff then
            local countSlayersDominanceUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitSlayersDominanceDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "MarkedforExecution")

                    if checkUnitSlayersDominanceDebuff then
                        local cUnitSlayersDominanceStacks = checkUnitSlayersDominanceDebuff.applications

                        cSlayersDominanceAoE = cSlayersDominanceAoE + ((nSlayersDominance * cUnitSlayersDominanceStacks) / countImprovedWhirlwindUnit)
                    end

                    countSlayersDominanceUnit = countSlayersDominanceUnit + 1

                    if countSlayersDominanceUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local cOverwhelmingBlades = 1
    local cOverwhelmingBladesAoE = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nil, "Overwhelmed")

        if checkOverwhelmingBladesDebuff then
            local cOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
            cOverwhelmingBlades = cOverwhelmingBlades + (nOverwhelmingBlades * cOverwhelmingBladesStacks)
        end


        if checkSweepingStrikesBuff then
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Overwhelmed")

                    if checkUnitOverwhelmingBladesDebuff then
                        local cUnitOverwhelmingBladesStacks = checkUnitOverwhelmingBladesDebuff.applications

                        cOverwhelmingBladesAoE = cOverwhelmingBladesAoE + (nOverwhelmingBlades * cUnitOverwhelmingBladesStacks)
                    end

                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end

        if checkImprovedWhirlwindBuff then
            local countOverwhelmingBladesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Overwhelmed")

                    if checkUnitOverwhelmingBladesDebuff then
                        local cUnitOverwhelmingBladesStacks = checkUnitOverwhelmingBladesDebuff.applications

                        cOverwhelmingBladesAoE = cOverwhelmingBladesAoE + ((nOverwhelmingBlades * cUnitOverwhelmingBladesStacks) / countImprovedWhirlwindUnit)
                    end

                    countOverwhelmingBladesUnit = countOverwhelmingBladesUnit + 1

                    if countOverwhelmingBladesUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cExecuteCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cExecuteCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cExecuteInstantDmg = cExecuteInstantDmg
        + (nExecuteDmg * cExecuteRageMod * checkPhysicalDR * cExecuteCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cSlayersDominance * cOverwhelmingBlades)
        + (cFatalityInstantDmg * cExecuteRageMod * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)
        + (cLightningStrikesInstantDmg * cExecuteCritValueBase)

    cExecuteDotDmg = cExecuteDotDmg

    cExecuteInstantDmgAoE = cExecuteInstantDmgAoE
        + (cSweepingStrikesInstantDmgAoE * cExecuteRageMod * cExecuteCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cDominanceoftheColossusAoE * cSlayersDominanceAoE * cOverwhelmingBladesAoE)
        + (cFatalityInstantDmgAoE * cExecuteRageMod * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)
        + (cImprovedWhirlwindInstantDmgAoE * cExecuteRageMod * cExecuteCritValue * cSlayersDominanceAoE * cOverwhelmingBladesAoE)
        + (cLightningStrikesInstantDmgAoE * cExecuteCritValueBase)

    cExecuteDotDmgAoE = cExecuteDotDmgAoE

    local cExecuteDmg = cExecuteInstantDmg + cExecuteDotDmg + cExecuteInstantDmgAoE + cExecuteDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cExecuteDmg)
    wan.UpdateAbilityData(wan.spellData.Execute.basename, abilityValue, wan.spellData.Execute.icon, wan.spellData.Execute.name)
end

-- Init frame 
local frameExecute = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            currentRage = UnitPower("player", 1) or 0

            checkMinCost, checkCost = wan.GetSpellCost(wan.spellData.Execute.id, 1)

            checkMedianCost = checkMinCost + ((checkCost - checkMinCost) * 0.5)
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "RAGE" then
                currentRage = UnitPower("player", 1) or 0
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nExecuteDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Execute.id, { 1 })

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01

            local nFatalityValues = wan.GetTraitDescriptionNumbers(wan.traitData.Fatality.entryid, { 2, 3 })
            nFatalityThreshold = nFatalityValues[1] * 0.01
            nFatalityDmg = nFatalityValues[2]

            local nLightningStrikesValues = wan.GetTraitDescriptionNumbers(wan.traitData.LightningStrikes.entryid, { 1, 2, 3 })
            nLightningStrikesProcChance = nLightningStrikesValues[1] * 0.01
            nLightningStrikesDmg = nLightningStrikesValues[2]
            nLightningStrikesProcModAvatar = 1 + (nLightningStrikesValues[3] * 0.01)

            local nGroundCurrentValues = wan.GetTraitDescriptionNumbers(wan.traitData.GroundCurrent.entryid, { 1, 2 })
            nGroundCurrentDmg = nGroundCurrentValues[1]
            nGroundCurrentSoftCap = nGroundCurrentValues[2]
        end
    end)
end
frameExecute:RegisterEvent("ADDON_LOADED")
frameExecute:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Execute.known and wan.spellData.Execute.id
        wan.BlizzardEventHandler(frameExecute, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_POWER_UPDATE")
        wan.SetUpdateRate(frameExecute, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nBarbaricTraining = wan.GetTraitDescriptionNumbers(wan.traitData.BarbaricTraining.entryid, { 2 })

        local nSweepingStrikesValues = wan.GetSpellDescriptionNumbers(wan.spellData.SweepingStrikes.id, { 2, 3, 4 })
        nSweepingStrikesUnitCap = nSweepingStrikesValues[1]
        nSweepingStrikesMaxRange = nSweepingStrikesValues[2]
        nSweepingStrikes = nSweepingStrikesValues[3] * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nCruelStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.CruelStrikes.entryid, { 2 }, wan.traitData.CruelStrikes.rank)

        local nSharpenedBladesValues = wan.GetTraitDescriptionNumbers(wan.traitData.SharpenedBlades.entryid, { 1, 2 })
        nSharpenedBladesCritChance = nSharpenedBladesValues[1]
        nSharpenedBladesCritDamage = nSharpenedBladesValues[2]

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nSlayersDominance = wan.GetTraitDescriptionNumbers(wan.traitData.SlayersDominance.entryid, { 2 }) * 0.01

        nShowNoMercy = wan.GetTraitDescriptionNumbers(wan.traitData.ShowNoMercy.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nAshenJuggernautCritChance = wan.GetTraitDescriptionNumbers(wan.traitData.AshenJuggernaut.entryid, { 1 })

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })

        nGatheringCloudsProcMod = wan.GetTraitDescriptionNumbers(wan.traitData.GatheringClouds.entryid, { 1 }) * 0.01 + 1

        nExecuteMaxRange = (wan.spellData.SweepingStrikes.known and nSweepingStrikesMaxRange)
        or (wan.traitData.ImprovedWhirlwind.known and 11)
        or 0
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameExecute, CheckAbilityValue, abilityActive)
    end
end)