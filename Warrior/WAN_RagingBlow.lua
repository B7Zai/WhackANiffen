local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRagingBlowDmg = 0

-- Init trait data
local nCriticalThinking = 0
local nOverwhelmingBlades = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nOpportunistCritDamage = 0
local nRecklessnessCritChance = 0
local nRecklessAbandonCritDamage = 0
local nLightningStrikesProcChance, nLightningStrikesDmg, nLightningStrikesProcModAvatar = 0, 0, 0
local nGroundCurrentDmg, nGroundCurrentSoftCap = 0, 0
local nGatheringCloudsProcMod = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.RagingBlow.id) then
        wan.UpdateAbilityData(wan.spellData.RagingBlow.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.RagingBlow.id, nWhirlwindMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.RagingBlow.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRagingBlowInstantDmg = 0
    local cRagingBlowDotDmg = 0
    local cRagingBlowInstantDmgAoE = 0
    local cRagingBlowDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WARRIOR TRAITS ----

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- FURY TRAITS ----

    local cImprovedWhirlwindInstantDmgAoE = 0
    local checkImprovedWhirlwindBuff = nil
    local countImprovedWhirlwindUnit = 0
    if wan.traitData.ImprovedWhirlwind.known then
        checkImprovedWhirlwindBuff = wan.CheckUnitBuff(nil, "Whirlwind")

        if checkImprovedWhirlwindBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nRagingBlowDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

                    countImprovedWhirlwindUnit = countImprovedWhirlwindUnit + 1

                    if countImprovedWhirlwindUnit >= nImprovedWhirlwindUnitCap then break end
                end
            end
        end
    end

    if wan.traitData.CriticalThinking.known then
        critDamageMod = critDamageMod + nCriticalThinking
    end

    if wan.traitData.RecklessAbandon.known and wan.spellData.RagingBlow.name == "Crushing Blow" then
        critDamageMod = critDamageMod + nRecklessAbandonCritDamage
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

    local cOverwhelmingBlades = 1
    local cOverwhelmingBladesAoE = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nil, "Overwhelmed")

        if checkOverwhelmingBladesDebuff then
            local cOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
            cOverwhelmingBlades = cOverwhelmingBlades + (nOverwhelmingBlades * cOverwhelmingBladesStacks)
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

    if wan.traitData.Opportunist.known then
        local checkOpportunistBuff = wan.CheckUnitBuff(nil, wan.traitData.Opportunist.traitkey)
        if checkOpportunistBuff then
            critDamageMod = critDamageMod + nOpportunistCritDamage
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cRagingBlowCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cRagingBlowCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cRagingBlowInstantDmg = cRagingBlowInstantDmg
        + (nRagingBlowDmg * checkPhysicalDR * cRagingBlowCritValue * cOverwhelmingBlades)
        + (cLightningStrikesInstantDmg * cRagingBlowCritValueBase)

    cRagingBlowDotDmg = cRagingBlowDotDmg

    cRagingBlowInstantDmgAoE = cRagingBlowInstantDmgAoE
        + (cImprovedWhirlwindInstantDmgAoE * cRagingBlowCritValue * cOverwhelmingBladesAoE)
        + (cLightningStrikesInstantDmgAoE * cRagingBlowCritValueBase)

    cRagingBlowDotDmgAoE = cRagingBlowDotDmgAoE

    local cRagingBlowDmg = cRagingBlowInstantDmg + cRagingBlowDotDmg + cRagingBlowInstantDmgAoE + cRagingBlowDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cRagingBlowDmg)
    wan.UpdateAbilityData(wan.spellData.RagingBlow.basename, abilityValue, wan.spellData.RagingBlow.icon, wan.spellData.RagingBlow.name)
end

-- Init frame 
local frameRagingBlow = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRagingBlowDmg = wan.GetSpellDescriptionNumbers(wan.spellData.RagingBlow.id, { 1 })

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
frameRagingBlow:RegisterEvent("ADDON_LOADED")
frameRagingBlow:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RagingBlow.known and wan.spellData.RagingBlow.id
        wan.BlizzardEventHandler(frameRagingBlow, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRagingBlow, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nCriticalThinking = wan.GetTraitDescriptionNumbers(wan.traitData.CriticalThinking.entryid, { 2 }, wan.traitData.CriticalThinking.rank)

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01
        nWhirlwindMaxRange = wan.traitData.ImprovedWhirlwind.known and 11 or 0

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nOpportunistCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.Opportunist.entryid, { 2 })

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })

        nRecklessAbandonCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.RecklessAbandon.entryid, { 6 })

        nGatheringCloudsProcMod = wan.GetTraitDescriptionNumbers(wan.traitData.GatheringClouds.entryid, { 1 }) * 0.01 + 1
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRagingBlow, CheckAbilityValue, abilityActive)
    end
end)