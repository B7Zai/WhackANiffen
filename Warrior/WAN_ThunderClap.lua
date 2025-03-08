local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nThunderClapDmg, nThunderClapSoftCap, nThunderClapMaxRange, nRendThunderClapUnitCap = 0, 0, 0, 0

-- Init trait data
local nBarbaricTraining = 0
local nMasteryDeepWounds = 0
local nSeismicReverberationThreshold, nSeismicReverberation = 0, 0
local nColossusSmash = 0
local nImpale = 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nDominanceoftheColossus = 0
local nRendInstantDmg, nRendDotDmg = 0, 0
local nRecklessnessCritChance = 0
local nLightningStrikesProcChance, nLightningStrikesDmg, nLightningStrikesProcModAvatar = 0, 0, 0
local nGroundCurrentDmg, nGroundCurrentSoftCap = 0, 0
local nGatheringCloudsProcMod = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ThunderClap.id) then
        wan.UpdateAbilityData(wan.spellData.ThunderClap.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nThunderClapMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ThunderClap.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cThunderClapInstantDmg = 0
    local cThunderClapDotDmg = 0
    local cThunderClapInstantDmgAoE = 0
    local cThunderClapDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]



    local cThunderClapInstantDmgBaseAoE = 0
    local cThunderClapUnitOverflow = wan.SoftCapOverflow(nThunderClapSoftCap, countValidUnit)
    local checkThunderBlast = wan.spellData.ThunderClap.name == "Thunder Blast"
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = not checkThunderBlast and wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken) or 1

        cThunderClapInstantDmgBaseAoE = cThunderClapInstantDmgBaseAoE + (nThunderClapDmg * cThunderClapUnitOverflow * checkUnitPhysicalDR)
    end

    ---- WARRIOR TRAITS ----

    local cRendDotDmgAoE = 1
    if wan.spellData.Rend.known then
        local formattedDebuffName = wan.spellData.Rend.formattedName
        local countRendThunderClapUnit = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitRendDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if not checkUnitRendDebuff then
                local checkUnitDotPotency = wan.CheckDotPotency(nThunderClapDmg)

                cRendDotDmgAoE = cRendDotDmgAoE + (nRendDotDmg * checkUnitDotPotency)

                countRendThunderClapUnit = countRendThunderClapUnit + 1

                if countRendThunderClapUnit >= nRendThunderClapUnitCap then break end
            end
        end
    end

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cMasteryDeepWounds = 1
    if wan.spellData.MasteryDeepWounds.known then
        local formattedDebuffName = "DeepWounds"

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkUnitMasteryDeepWoundsDebuff then
                cMasteryDeepWounds = cMasteryDeepWounds + (nMasteryDeepWounds / countValidUnit)
            end
        end
    end

    local cColossusSmash = 1
    if wan.traitData.ColossusSmash.known then
        local formattedDebuffName = wan.traitData.ColossusSmash.traitkey

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitColossusSmashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkUnitColossusSmashDebuff then
                cColossusSmash = cColossusSmash + (nColossusSmash / countValidUnit)
            end
        end
    end

    if wan.traitData.Impale.known then
        critDamageMod = critDamageMod + nImpale
        critDamageModBase = critDamageModBase + nImpale
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
        critDamageModBase = critDamageModBase + nMartialExpertCritDamage
    end

    local cDominanceoftheColossus = 1
    if wan.traitData.DominanceoftheColossus.known then
        local formattedDebuffName = "Wrecked"

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkWreckedDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkWreckedDebuff then
                local cWreckedStacks = checkWreckedDebuff.applications
                cDominanceoftheColossus = cDominanceoftheColossus + ((nDominanceoftheColossus * cWreckedStacks) / countValidUnit)
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

        if wan.traitData.FlashingSkies.known and checkThunderBlast then
            cLightningStrikesProcChance = 1
        end

        cLightningStrikesInstantDmg = cLightningStrikesInstantDmg + (nLightningStrikesDmg * cLightningStrikesProcChance)

        if wan.traitData.GroundCurrent.known then
            local cGroundCurrentUnitOverflow = wan.SoftCapOverflow(nGroundCurrentSoftCap, countValidUnit)

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cLightningStrikesInstantDmgAoE = cLightningStrikesInstantDmgAoE + (nGroundCurrentDmg * cGroundCurrentUnitOverflow * cLightningStrikesProcChance)
                end
            end
        end
    end

    if wan.traitData.CrashingThunder.known and wan.traitData.BarbaricTraining.known then
        critDamageMod = critDamageMod + nBarbaricTraining
    end

    local cSeismicReverberation = 1
    if wan.traitData.CrashingThunder.known and wan.traitData.SeismicReverberation.known then
        if countValidUnit >= nSeismicReverberationThreshold then
            cSeismicReverberation = cSeismicReverberation + nSeismicReverberation
        end
    end

    local cImprovedWhirlwindInstantDmgAoE = 0
    if wan.traitData.CrashingThunder.known and wan.traitData.ImprovedWhirlwind.known then
        local checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if not checkImprovedWhirlwindBuff then
            local countImprovedWhirlwindUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nThunderClapDmg)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    ---- SLAYER TRAITS ----

    local cOverwhelmingBlades = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local formattedDebuffName = "Overwhelmed"

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkOverwhelmingBladesDebuff then
                local cUnitOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
                cOverwhelmingBlades = cOverwhelmingBlades + ((nOverwhelmingBlades * cUnitOverwhelmingBladesStacks) / countValidUnit)
            end
        end
    end

    local cThunderClapCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cThunderClapCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cThunderClapInstantDmg = cThunderClapInstantDmg
        + (cLightningStrikesInstantDmg * cThunderClapCritValueBase)

    cThunderClapDotDmg = cThunderClapDotDmg

    cThunderClapInstantDmgAoE = cThunderClapInstantDmgAoE
        + (cThunderClapInstantDmgBaseAoE * cThunderClapCritValue * cMasteryDeepWounds * cColossusSmash * cSeismicReverberation * cDominanceoftheColossus * cOverwhelmingBlades)
        + (cLightningStrikesInstantDmgAoE * cThunderClapCritValueBase)
        + (cImprovedWhirlwindInstantDmgAoE * cThunderClapCritValue * cSeismicReverberation)

    cThunderClapDotDmgAoE = cThunderClapDotDmgAoE
        + (cRendDotDmgAoE * cThunderClapCritValueBase * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    local cThunderClapDmg = cThunderClapInstantDmg + cThunderClapDotDmg + cThunderClapInstantDmgAoE + cThunderClapDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cThunderClapDmg)
    wan.UpdateAbilityData(wan.spellData.ThunderClap.basename, abilityValue, wan.spellData.ThunderClap.icon, wan.spellData.ThunderClap.name)
end

-- Init frame 
local frameThunderClap = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nThunderClapValues = wan.GetSpellDescriptionNumbers(wan.spellData.ThunderClap.id, { 1, 2, 5, 6 })
            nThunderClapMaxRange = nThunderClapValues[1]
            nThunderClapDmg = nThunderClapValues[2]
            nThunderClapSoftCap = nThunderClapValues[3]
            nRendThunderClapUnitCap = nThunderClapValues[4]

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01

            local nRendValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rend.id, { 1, 2 })
            nRendInstantDmg = nRendValues[1]
            nRendDotDmg = nRendValues[2]

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
frameThunderClap:RegisterEvent("ADDON_LOADED")
frameThunderClap:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ThunderClap.known and wan.spellData.ThunderClap.id
        wan.BlizzardEventHandler(frameThunderClap, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameThunderClap, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nSeismicReverberationValues = wan.GetTraitDescriptionNumbers(wan.traitData.SeismicReverberation.entryid, { 1, 2, 3 })
        nSeismicReverberationThreshold = nSeismicReverberationValues[1]
        nSeismicReverberation = (nSeismicReverberationValues[3] * nSeismicReverberationValues[2]) * 0.01

        nBarbaricTraining = wan.GetTraitDescriptionNumbers(wan.traitData.BarbaricTraining.entryid, { 2 })

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })

        nGatheringCloudsProcMod = wan.GetTraitDescriptionNumbers(wan.traitData.GatheringClouds.entryid, { 1 }) * 0.01 + 1

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameThunderClap, CheckAbilityValue, abilityActive)
    end
end)