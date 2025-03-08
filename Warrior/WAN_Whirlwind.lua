local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWhirlwindDmg, nWhirlwindSoftCap, nWhirlwindMaxRange = 0, 0, 0

-- Init trait data
local nBarbaricTraining = 0
local nMasteryDeepWounds, nMasteryDeepWoundsDotDmg = 0, 0
local nSeismicReverberationThreshold, nSeismicReverberation = 0, 0
local nFervorofBattleThreshold = 0
local nColossusSmash = 0
local nImpale = 0
local nSharpenedBladesCritChance, nSharpenedBladesCritDamage = 0, 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nReaptheStormThreshold, nReaptheStormProcChance, nReaptheStormDmg, nReaptheStormSoftCap = 0, 0, 0, 0
local nOneAgainstMany, nOneAgainstManyUnitCap = 0, 0
local nDominanceoftheColossus = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind = 0, 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Whirlwind.id)
        or (wan.PlayerState.Role == "TANK" and wan.spellData.IgnorePain.known and not wan.IsSpellUsable(wan.spellData.IgnorePain.id))
    then
        
        wan.UpdateAbilityData(wan.spellData.Whirlwind.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nWhirlwindMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Whirlwind.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cWhirlwindInstantDmg = 0
    local cWhirlwindDotDmg = 0
    local cWhirlwindInstantDmgAoE = 0
    local cWhirlwindDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cWhirlwindInstantDmgBaseAoE = 0
    local cWhirlwindUnitOverflow = wan.SoftCapOverflow(nWhirlwindSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cWhirlwindInstantDmgBaseAoE = cWhirlwindInstantDmgBaseAoE + (nWhirlwindDmg * cWhirlwindUnitOverflow * checkUnitPhysicalDR)
    end

    ---- WARRIOR TRAITS ----

    if wan.traitData.BarbaricTraining.known then
        critDamageMod = critDamageMod + nBarbaricTraining
    end

    local cSeismicReverberation = 1
    if wan.traitData.SeismicReverberation.known then
        if countValidUnit >= nSeismicReverberationThreshold then
            cSeismicReverberation = cSeismicReverberation + nSeismicReverberation
        end
    end

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cMasteryDeepWoundsAoE = 1
    local cMasteryDeepWoundsDotDmgAoE = 0
    if wan.spellData.MasteryDeepWounds.known then
        local countMasteryDeepWoundsDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "DeepWounds")

            if checkUnitMasteryDeepWoundsDebuff then
                countMasteryDeepWoundsDebuff = countMasteryDeepWoundsDebuff + 1
            end

            if wan.spellData.Whirlwind.name == "Cleave" then

                if not checkUnitMasteryDeepWoundsDebuff then
                    local checkDotPotency = wan.CheckDotPotency(nWhirlwindDmg, nameplateUnitToken)

                    cMasteryDeepWoundsDotDmgAoE = cMasteryDeepWoundsDotDmgAoE + (nMasteryDeepWoundsDotDmg * checkDotPotency)
                end
            end
        end

        if countMasteryDeepWoundsDebuff > 0 then
            cMasteryDeepWoundsAoE = cMasteryDeepWoundsAoE + ((nMasteryDeepWounds * countMasteryDeepWoundsDebuff) / countValidUnit)
        end
    end

    local cFervorofBattleInstantDmg = 0
    if wan.traitData.FervorofBattle.known then
        if countValidUnit >= nFervorofBattleThreshold then
            local checkSlam = wan.AbilityData[wan.spellData.Slam.basename]
            if checkSlam and checkSlam.value then
                cFervorofBattleInstantDmg = cFervorofBattleInstantDmg + checkSlam.value
            end
        end
    end

    local cColossusSmashAoE = 1
    if wan.traitData.ColossusSmash.known then
        local formattedDebuffName = wan.traitData.ColossusSmash.traitkey

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitColossusSmashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkUnitColossusSmashDebuff then
                cColossusSmashAoE = cColossusSmashAoE + (nColossusSmash / countValidUnit)
            end
        end
    end

    if wan.traitData.Impale.known then
        critDamageMod = critDamageMod + nImpale
    end

    if wan.traitData.SharpenedBlades.known and wan.spellData.Whirlwind.name == "Cleave" then
        critChanceMod = critChanceMod + nSharpenedBladesCritChance
        critDamageMod = critDamageMod + nSharpenedBladesCritDamage
    end

    ---- FURY TRAITS ----

    local cImprovedWhirlwindInstantDmgAoE = 0
    if wan.traitData.ImprovedWhirlwind.known then
        local checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if not checkImprovedWhirlwindBuff then
            local countImprovedWhirlwindUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nWhirlwindDmg)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local cOneAgainstMany = 1
    if wan.traitData.OneAgainstMany.known then
        local cOneAgainstManyUnitCap = math.min(countValidUnit, nOneAgainstManyUnitCap)
        cOneAgainstMany = cOneAgainstMany + (nOneAgainstMany * cOneAgainstManyUnitCap)
    end

    local cDominanceoftheColossusAoE = 1
    if wan.traitData.DominanceoftheColossus.known then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkWreckedDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Wrecked")

            if checkWreckedDebuff then
                local cWreckedStacks = checkWreckedDebuff.applications
                cDominanceoftheColossusAoE = cDominanceoftheColossusAoE + ((nDominanceoftheColossus * cWreckedStacks) / countValidUnit)
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


        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "Overwhelmed")

            if checkUnitOverwhelmingBladesDebuff then
                local cUnitOverwhelmingBladesStacks = checkUnitOverwhelmingBladesDebuff.applications
                cOverwhelmingBladesAoE = cOverwhelmingBladesAoE + (nOverwhelmingBlades * cUnitOverwhelmingBladesStacks)
            end
        end
    end

    local cReaptheStormInstantDmgAoE = 0
    if wan.traitData.ReaptheStorm.known then

        if countValidUnit >= nReaptheStormThreshold then
            local cReaptheStormUnitOverflow = wan.SoftCapOverflow(nReaptheStormSoftCap, countValidUnit)
            local cProcChanceUnitOverflow = wan.AdjustSoftCapUnitOverflow(3, countValidUnit)
            local cReaptheStormProcChance = nReaptheStormProcChance * cProcChanceUnitOverflow

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cReaptheStormInstantDmgAoE = cReaptheStormInstantDmgAoE + (nReaptheStormDmg * cReaptheStormProcChance * cReaptheStormUnitOverflow * checkUnitPhysicalDR)
            end
        end
    end

    local cWhirlwindCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cWhirlwindCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cWhirlwindInstantDmg = cWhirlwindInstantDmg
        + (cFervorofBattleInstantDmg * cDominanceoftheColossusAoE * cOverwhelmingBlades)

    cWhirlwindDotDmg = cWhirlwindDotDmg

    cWhirlwindInstantDmgAoE = cWhirlwindInstantDmgAoE
        + (cWhirlwindInstantDmgBaseAoE * cWhirlwindCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cSeismicReverberation * cOneAgainstMany * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)
        + (cImprovedWhirlwindInstantDmgAoE * cWhirlwindCritValue * cSeismicReverberation * cOverwhelmingBladesAoE)
        + (cReaptheStormInstantDmgAoE * cWhirlwindCritValueBase * cMasteryDeepWoundsAoE * cColossusSmashAoE * cOverwhelmingBladesAoE)

    cWhirlwindDotDmgAoE = cWhirlwindDotDmgAoE
        + (cMasteryDeepWoundsDotDmgAoE * cWhirlwindCritValueBase * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)

    local cWhirlwindDmg = cWhirlwindInstantDmg + cWhirlwindDotDmg + cWhirlwindInstantDmgAoE + cWhirlwindDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cWhirlwindDmg)
    wan.UpdateAbilityData(wan.spellData.Whirlwind.basename, abilityValue, wan.spellData.Whirlwind.icon, wan.spellData.Whirlwind.name)
end

-- Init frame 
local frameWhirlwind = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nWhirlwindValues = wan.GetSpellDescriptionNumbers(wan.spellData.Whirlwind.id, { 1, 2 })
            nWhirlwindDmg = nWhirlwindValues[1]
            nWhirlwindSoftCap = nWhirlwindValues[2]
            nWhirlwindMaxRange = 11

            local nMasteryDeepWoundsValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 1, 3 }) 
            nMasteryDeepWoundsDotDmg = nMasteryDeepWoundsValues[1]
            nMasteryDeepWounds = nMasteryDeepWoundsValues[2] * 0.01

            local nReaptheStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.ReaptheStorm.entryid, { 1, 2, 3, 4 })
            nReaptheStormThreshold = nReaptheStormValues[1]
            nReaptheStormProcChance = nReaptheStormValues[2] * 0.01
            nReaptheStormDmg = nReaptheStormValues[3]
            nReaptheStormSoftCap = nReaptheStormValues[4]
        end
    end)
end
frameWhirlwind:RegisterEvent("ADDON_LOADED")
frameWhirlwind:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Whirlwind.known and wan.spellData.Whirlwind.id
        wan.BlizzardEventHandler(frameWhirlwind, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWhirlwind, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nSeismicReverberationValues = wan.GetTraitDescriptionNumbers(wan.traitData.SeismicReverberation.entryid, { 1, 2, 3 })
        nSeismicReverberationThreshold = nSeismicReverberationValues[1]
        nSeismicReverberation = (nSeismicReverberationValues[3] * nSeismicReverberationValues[2]) * 0.01

        nFervorofBattleThreshold = wan.GetTraitDescriptionNumbers(wan.traitData.FervorofBattle.entryid, { 1 })

        nBarbaricTraining = wan.GetTraitDescriptionNumbers(wan.traitData.BarbaricTraining.entryid, { 2 })

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        local nSharpenedBladesValues = wan.GetTraitDescriptionNumbers(wan.traitData.SharpenedBlades.entryid, { 1, 2 })
        nSharpenedBladesCritChance = nSharpenedBladesValues[1]
        nSharpenedBladesCritDamage = nSharpenedBladesValues[2]

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        local nOneAgainstManyValues = wan.GetTraitDescriptionNumbers(wan.traitData.OneAgainstMany.entryid, { 1, 2 })
        nOneAgainstMany = nOneAgainstManyValues[1] * 0.01
        nOneAgainstManyUnitCap = nOneAgainstManyValues[2]

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWhirlwind, CheckAbilityValue, abilityActive)
    end
end)