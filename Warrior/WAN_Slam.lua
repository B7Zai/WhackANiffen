local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSlamDmg, nSlamMaxRange = 0, 0

-- Init trait data
local nBarbaricTraining = 0
local nMasteryDeepWounds = 0
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 0, 0
local nColossusSmash = 0
local nImpale = 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nDominanceoftheColossus = 0
local nImprovedWhirlwindUnitCap, nImprovedWhirlwind, nWhirlwindMaxRange = 0, 0, 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Slam.id)
        or (wan.PlayerState.Role == "TANK" and wan.spellData.IgnorePain.known and not wan.IsSpellUsable(wan.spellData.IgnorePain.id))
    then
        wan.UpdateAbilityData(wan.spellData.Slam.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Slam.id, nSlamMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Slam.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cSlamInstantDmg = 0
    local cSlamDotDmg = 0
    local cSlamInstantDmgAoE = 0
    local cSlamDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WARRIOR TRAITS ----

    if wan.traitData.BarbaricTraining.known then
        critDamageMod = critDamageMod + nBarbaricTraining
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

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + (nSlamDmg * nSweepingStrikes * checkUnitPhysicalDR)
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
        local checkColossusSmashDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ColossusSmash.traitkey)
        if checkColossusSmashDebuff then
            cColossusSmash = cColossusSmash + nColossusSmash
        end

        if checkSweepingStrikesBuff then
            local cSweepingStrikesUnit = math.min(countValidUnit, nSweepingStrikesUnitCap)
            local countSweepingStrikesUnit = 0
            local countColossusSmashDebuff = 0

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

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nSlamDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

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

    local cDominanceoftheColossus = 1
    local cDominanceoftheColossusAoE = 1
    if wan.traitData.DominanceoftheColossus.known then
        local checkWreckedDebuff = wan.CheckUnitDebuff(nil, "Wrecked")

        if checkWreckedDebuff then
            local cWreckedStacks = checkWreckedDebuff.applications or 1
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
    local cSlamCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cSlamCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSlamInstantDmg = cSlamInstantDmg
        + (nSlamDmg * checkPhysicalDR * cSlamCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cSlamDotDmg = cSlamDotDmg

    cSlamInstantDmgAoE = cSlamInstantDmgAoE
        + (cSweepingStrikesInstantDmgAoE * cSlamCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)
        + (cImprovedWhirlwindInstantDmgAoE * cOverwhelmingBlades)

    cSlamDotDmgAoE = cSlamDotDmgAoE

    local cSlamDmg = cSlamInstantDmg + cSlamDotDmg + cSlamInstantDmgAoE + cSlamDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSlamDmg)
    wan.UpdateAbilityData(wan.spellData.Slam.basename, abilityValue, wan.spellData.Slam.icon, wan.spellData.Slam.name)
end

-- Init frame 
local frameSlam = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSlamDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Slam.id, { 1 })

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01
        end
    end)
end
frameSlam:RegisterEvent("ADDON_LOADED")
frameSlam:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Slam.known and wan.spellData.Slam.id
        wan.BlizzardEventHandler(frameSlam, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSlam, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nBarbaricTraining = wan.GetTraitDescriptionNumbers(wan.traitData.BarbaricTraining.entryid, { 2 })

        local nSweepingStrikesValues = wan.GetSpellDescriptionNumbers(wan.spellData.SweepingStrikes.id, { 2, 3, 4 })
        nSweepingStrikesUnitCap = nSweepingStrikesValues[1]
        nSweepingStrikesMaxRange = nSweepingStrikesValues[2]
        nSweepingStrikes = nSweepingStrikesValues[3] * 0.01

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        local nImprovedWhirlwindValues = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedWhirlwind.entryid, { 2, 3 })
        nImprovedWhirlwindUnitCap = nImprovedWhirlwindValues[1]
        nImprovedWhirlwind = nImprovedWhirlwindValues[2] * 0.01
        nWhirlwindMaxRange = wan.traitData.ImprovedWhirlwind.known and 11 or 0
        
        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })

        nSlamMaxRange = (wan.spellData.SweepingStrikes.known and nSweepingStrikesMaxRange)
            or (wan.traitData.ImprovedWhirlwind.known and 11)
            or 0
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSlam, CheckAbilityValue, abilityActive)
    end
end)