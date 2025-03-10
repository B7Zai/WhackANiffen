local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRevengeDmg, nRevengeSoftCap, nRevengeMaxRange = 0, 0, 0

-- Init trait data
local nBarbaricTraining = 0
local nDeepWoundsDotDmg = 0
local nSeismicReverberationThreshold, nSeismicReverberation = 0, 0
local nMartialExpertCritDamage = 0
local nOneAgainstMany, nOneAgainstManyUnitCap = 0, 0
local nDominanceoftheColossus = 0
local nLightningStrikesProcChance, nLightningStrikesDmg, nLightningStrikesProcModAvatar = 0, 0, 0
local nGroundCurrentDmg, nGroundCurrentSoftCap = 0, 0
local nGatheringCloudsProcMod = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Revenge.id) then
        wan.UpdateAbilityData(wan.spellData.Revenge.basename)
        return
    end

    if wan.spellData.ShieldBlock.known and wan.IsTanking()
        and not wan.CheckUnitBuff(nil, wan.spellData.ShieldBlock.formattedName)
        and not wan.CheckUnitBuff(nil, wan.spellData.Revenge.formattedName)
    then
        local currentCharges = wan.CheckSpellCharges(wan.spellData.ShieldBlock.id)
        local _, insufficientPower = wan.IsSpellUsable(wan.spellData.ShieldBlock.id)
        if currentCharges > 0 and insufficientPower then
            wan.UpdateAbilityData(wan.spellData.Revenge.basename)
            return
        end
    end

    if wan.spellData.IgnorePain.known and wan.IsTanking()
        and not wan.CheckUnitBuff(nil, wan.spellData.IgnorePain.formattedName)
        and not wan.CheckUnitBuff(nil, wan.spellData.Revenge.formattedName)
    then
        local _, insufficientPower = wan.IsSpellUsable(wan.spellData.IgnorePain.id)
        if insufficientPower then
            wan.UpdateAbilityData(wan.spellData.Revenge.basename)
            return
        end
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nRevengeMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Revenge.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRevengeInstantDmg = 0
    local cRevengeDotDmg = 0
    local cRevengeInstantDmgAoE = 0
    local cRevengeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cRevengeInstantDmgBaseAoE = 0
    local cRevengeUnitOverflow = wan.SoftCapOverflow(nRevengeSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cRevengeInstantDmgBaseAoE = cRevengeInstantDmgBaseAoE + (nRevengeDmg * cRevengeUnitOverflow * checkUnitPhysicalDR)
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

    ---- PROTECTION TRAITS ----

    local cDeepWoundsDotDmgAoE = 0
    if wan.spellData.DeepWounds.known then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "DeepWounds")

            if not checkUnitMasteryDeepWoundsDebuff then
                local checkDotPotency = wan.CheckDotPotency(nRevengeDmg, nameplateUnitToken)

                cDeepWoundsDotDmgAoE = cDeepWoundsDotDmgAoE + (nDeepWoundsDotDmg * checkDotPotency)
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

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    cLightningStrikesInstantDmgAoE = cLightningStrikesInstantDmgAoE + (nGroundCurrentDmg * cGroundCurrentUnitOverflow * cLightningStrikesProcChance)
                end
            end
        end
    end

    local cRevengeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cRevengeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cRevengeInstantDmg = cRevengeInstantDmg
        + (cLightningStrikesInstantDmg * cRevengeCritValueBase)

    cRevengeDotDmg = cRevengeDotDmg

    cRevengeInstantDmgAoE = cRevengeInstantDmgAoE
        + (cRevengeInstantDmgBaseAoE * cRevengeCritValue * cSeismicReverberation * cOneAgainstMany * cDominanceoftheColossusAoE)

    cRevengeDotDmgAoE = cRevengeDotDmgAoE
        + (cDeepWoundsDotDmgAoE * cRevengeCritValueBase * cDominanceoftheColossusAoE)
        + (cLightningStrikesInstantDmgAoE * cRevengeCritValueBase)

    local cRevengeDmg = cRevengeInstantDmg + cRevengeDotDmg + cRevengeInstantDmgAoE + cRevengeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cRevengeDmg)
    wan.UpdateAbilityData(wan.spellData.Revenge.basename, abilityValue, wan.spellData.Revenge.icon, wan.spellData.Revenge.name)
end

-- Init frame 
local frameRevenge = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nRevengeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Revenge.id, { 1, 2 })
            nRevengeDmg = nRevengeValues[1]
            nRevengeSoftCap = nRevengeValues[2]
            nRevengeMaxRange = 11

            nDeepWoundsDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.DeepWounds.id, { 1 })

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
frameRevenge:RegisterEvent("ADDON_LOADED")
frameRevenge:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Revenge.known and wan.spellData.Revenge.id
        wan.BlizzardEventHandler(frameRevenge, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRevenge, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nSeismicReverberationValues = wan.GetTraitDescriptionNumbers(wan.traitData.SeismicReverberation.entryid, { 1, 2, 3 })
        nSeismicReverberationThreshold = nSeismicReverberationValues[1]
        nSeismicReverberation = (nSeismicReverberationValues[3] * nSeismicReverberationValues[2]) * 0.01

        nBarbaricTraining = wan.GetTraitDescriptionNumbers(wan.traitData.BarbaricTraining.entryid, { 2 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        local nOneAgainstManyValues = wan.GetTraitDescriptionNumbers(wan.traitData.OneAgainstMany.entryid, { 1, 2 })
        nOneAgainstMany = nOneAgainstManyValues[1] * 0.01
        nOneAgainstManyUnitCap = nOneAgainstManyValues[2]

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nGatheringCloudsProcMod = wan.GetTraitDescriptionNumbers(wan.traitData.GatheringClouds.entryid, { 1 }) * 0.01 + 1
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRevenge, CheckAbilityValue, abilityActive)
    end
end)