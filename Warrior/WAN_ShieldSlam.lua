local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nShieldSlamDmg, nShieldSlamMaxRange = 0, 0

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
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ShieldSlam.id) then
        wan.UpdateAbilityData(wan.spellData.ShieldSlam.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ShieldSlam.id, nShieldSlamMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ShieldSlam.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cShieldSlamInstantDmg = 0
    local cShieldSlamDotDmg = 0
    local cShieldSlamInstantDmgAoE = 0
    local cShieldSlamDotDmgAoE = 0

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

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + (nShieldSlamDmg * nSweepingStrikes * checkUnitPhysicalDR)
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

                    cImprovedWhirlwindInstantDmgAoE = cImprovedWhirlwindInstantDmgAoE + (nShieldSlamDmg * nImprovedWhirlwind * checkUnitPhysicalDR)

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
    local cShieldSlamCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cShieldSlamCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cShieldSlamInstantDmg = cShieldSlamInstantDmg
        + (nShieldSlamDmg * checkPhysicalDR * cShieldSlamCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cShieldSlamDotDmg = cShieldSlamDotDmg

    cShieldSlamInstantDmgAoE = cShieldSlamInstantDmgAoE
        + (cSweepingStrikesInstantDmgAoE * cShieldSlamCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)
        + (cImprovedWhirlwindInstantDmgAoE * cOverwhelmingBlades)

    cShieldSlamDotDmgAoE = cShieldSlamDotDmgAoE

    local cShieldSlamDmg = cShieldSlamInstantDmg + cShieldSlamDotDmg + cShieldSlamInstantDmgAoE + cShieldSlamDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cShieldSlamDmg)
    wan.UpdateAbilityData(wan.spellData.ShieldSlam.basename, abilityValue, wan.spellData.ShieldSlam.icon, wan.spellData.ShieldSlam.name)
end

-- Init frame 
local frameShieldSlam = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nShieldSlamDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ShieldSlam.id, { 1 })

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01
        end
    end)
end
frameShieldSlam:RegisterEvent("ADDON_LOADED")
frameShieldSlam:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldSlam.known and wan.spellData.ShieldSlam.id
        wan.BlizzardEventHandler(frameShieldSlam, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShieldSlam, CheckAbilityValue, abilityActive)
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

        nShieldSlamMaxRange = (wan.spellData.SweepingStrikes.known and nSweepingStrikesMaxRange)
            or (wan.traitData.ImprovedWhirlwind.known and 11)
            or 0
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldSlam, CheckAbilityValue, abilityActive)
    end
end)