local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nMortalStrikeDmg = 0

-- Init trait data
local nCrushingForce = 0
local nMasteryDeepWounds, nMasteryDeepWoundsDotDmg = 0, 0
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 0, 0
local nColossusSmash = 0
local nImpale = 0
local nSharpenedBladesCritChance, nSharpenedBladesCritDamage = 0, 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nBloodlettingThreshold = 0
local nExecutionersPrecision = 0
local nDominanceoftheColossus = 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.MortalStrike.id) then
        wan.UpdateAbilityData(wan.spellData.MortalStrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.MortalStrike.id, nSweepingStrikesMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.MortalStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cMortalStrikeInstantDmg = 0
    local cMortalStrikeDotDmg = 0
    local cMortalStrikeInstantDmgAoE = 0
    local cMortalStrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WARRIOR TRAITS ----

    if wan.traitData.CrushingForce.known then
        critDamageMod = critDamageMod + nCrushingForce
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
        checkSweepingStrikesBuff = wan.CheckUnitBuff(nil, wan.spellData.SweepingStrikes.formattedName)
        local countSweepingStrikesUnit = 0

        if checkSweepingStrikesBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + (nMortalStrikeDmg * nSweepingStrikes * checkUnitPhysicalDR)
                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end
    end

    local cMasteryDeepWounds = 1
    local cMasteryDeepWoundsAoE = 1
    local cMasteryDeepWoundsDotDmg = 0
    local cMasteryDeepWoundsDotDmgAoE = 0
    if wan.spellData.MasteryDeepWounds.known then
        local checkMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nil, "DeepWounds")

        if checkMasteryDeepWoundsDebuff then
            cMasteryDeepWounds = cMasteryDeepWounds + nMasteryDeepWounds
        else 
            local checkDotPotency = wan.CheckDotPotency(nMortalStrikeDmg)

            cMasteryDeepWoundsDotDmg = cMasteryDeepWoundsDotDmg + (nMasteryDeepWoundsDotDmg * checkDotPotency)
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
                    else
                        local checkUnitDotPotency = wan.CheckDotPotency(nMortalStrikeDmg)

                        cMasteryDeepWoundsDotDmgAoE = cMasteryDeepWoundsDotDmgAoE + (nMasteryDeepWoundsDotDmg * checkUnitDotPotency)
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
        local checkColossusSmashDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ColossusSmash.traitkey)

        if checkColossusSmashDebuff then
            cColossusSmash = cColossusSmash + nColossusSmash
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countColossusSmashDebuff = 0
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitColossusSmashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.ColossusSmash.traitkey)

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

    local cBloodlettingDotDmg = 0
    if wan.traitData.Bloodletting.known and wan.spellData.Rend.known then
        local checkHealthPercentage = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if checkHealthPercentage < nBloodlettingThreshold then
            local checkRend = wan.AbilityData[wan.spellData.Rend.basename]

            if checkRend and checkRend.value then
                cBloodlettingDotDmg = cBloodlettingDotDmg + checkRend.value
            end
        end
    end

    if wan.traitData.SharpenedBlades.known then
        critChanceMod = critChanceMod + nSharpenedBladesCritChance
        critDamageMod = critDamageMod + nSharpenedBladesCritDamage
    end

    local cExecutionersPrecision = 1
    local cExecutionersPrecisionAoE = 1
    if wan.traitData.ExecutionersPrecision.known then
        local formattedDebuffName = wan.traitData.ExecutionersPrecision.traitkey
        local checkExecutionersPrecisionDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

        if checkExecutionersPrecisionDebuff then
            local cExecutionersPrecisionStacks = checkExecutionersPrecisionDebuff.applications
            cExecutionersPrecision = cExecutionersPrecision + (nExecutionersPrecision * cExecutionersPrecisionStacks)
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countSweepingStrikesUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitExecutionersPrecisionDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

                    if checkUnitExecutionersPrecisionDebuff then
                        local cUnitExecutionersPrecisionStacks = checkUnitExecutionersPrecisionDebuff.applications

                        cExecutionersPrecisionAoE = cExecutionersPrecisionAoE + (nExecutionersPrecision * cUnitExecutionersPrecisionStacks)

                        countSweepingStrikesUnit = countSweepingStrikesUnit + 1
                    end

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end

            if countSweepingStrikesUnit > 0 then
                cExecutionersPrecisionAoE = cExecutionersPrecisionAoE / cSweepingStrikesUnit
            end
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

    ---- SLAYER TRAITS ----

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
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cMortalStrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cMortalStrikeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cMortalStrikeInstantDmg = cMortalStrikeInstantDmg
        + (nMortalStrikeDmg * checkPhysicalDR * cMortalStrikeCritValue * cMasteryDeepWounds * cColossusSmash * cExecutionersPrecision * cDominanceoftheColossus * cOverwhelmingBlades)

    cMortalStrikeDotDmg = cMortalStrikeDotDmg
        + (cMasteryDeepWoundsDotDmg * cMortalStrikeCritValueBase * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)
        + (cBloodlettingDotDmg * cMortalStrikeCritValueBase * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cMortalStrikeInstantDmgAoE = cMortalStrikeInstantDmgAoE
        + (cSweepingStrikesInstantDmgAoE * cMortalStrikeCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cExecutionersPrecisionAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)

    cMortalStrikeDotDmgAoE = cMortalStrikeDotDmgAoE
        + (cMasteryDeepWoundsDotDmgAoE * cMortalStrikeCritValueBase * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)

    local cMortalStrikeDmg = cMortalStrikeInstantDmg + cMortalStrikeDotDmg + cMortalStrikeInstantDmgAoE + cMortalStrikeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMortalStrikeDmg)
    wan.UpdateAbilityData(wan.spellData.MortalStrike.basename, abilityValue, wan.spellData.MortalStrike.icon, wan.spellData.MortalStrike.name)
end

-- Init frame 
local frameMortalStrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMortalStrikeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.MortalStrike.id, { 1 })

            local nMasteryDeepWoundsValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 1, 3 }) 
            nMasteryDeepWoundsDotDmg = nMasteryDeepWoundsValues[1]
            nMasteryDeepWounds = nMasteryDeepWoundsValues[2] * 0.01
        end
    end)
end
frameMortalStrike:RegisterEvent("ADDON_LOADED")
frameMortalStrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MortalStrike.known and wan.spellData.MortalStrike.id
        wan.BlizzardEventHandler(frameMortalStrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMortalStrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nCrushingForce = wan.GetTraitDescriptionNumbers(wan.traitData.CrushingForce.entryid, { 2 }, wan.traitData.CrushingForce.rank)

        local nSweepingStrikesValues = wan.GetSpellDescriptionNumbers(wan.spellData.SweepingStrikes.id, { 2, 3, 4 })
        nSweepingStrikesUnitCap = nSweepingStrikesValues[1]
        nSweepingStrikesMaxRange = nSweepingStrikesValues[2]
        nSweepingStrikes = nSweepingStrikesValues[3] * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        local nSharpenedBladesValues = wan.GetTraitDescriptionNumbers(wan.traitData.SharpenedBlades.entryid, { 1, 2 })
        nSharpenedBladesCritChance = nSharpenedBladesValues[1]
        nSharpenedBladesCritDamage = nSharpenedBladesValues[2]

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nBloodlettingThreshold = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodletting.entryid, { 3 }) * 0.01

        nExecutionersPrecision = wan.GetTraitDescriptionNumbers(wan.traitData.ExecutionersPrecision.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMortalStrike, CheckAbilityValue, abilityActive)
    end
end)