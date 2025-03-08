local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSkullsplitterDmg, nSkullsplitter = 0, 0
local nRendDotDmg, nRendDotDuration = 0, 0
local nMasteryDeepWoundsDotDmg, nMasteryDeepWoundsDotDuration = 0, 0

-- Init trait data
local nMasteryDeepWounds = 0
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 0, 0
local nColossusSmash = 0
local nImpale = 0
local nBloodlettingCritChance = 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nDominanceoftheColossus = 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Skullsplitter.id) then
        wan.UpdateAbilityData(wan.spellData.Skullsplitter.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Skullsplitter.id, nSweepingStrikesMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Skullsplitter.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSkullsplitterInstantDmg = 0
    local cSkullsplitterDotDmg = 0
    local cSkullsplitterInstantDmgAoE = 0
    local cSkullsplitterDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local currentTime = GetTime()
    local cSkullsplitterDotDmgBase = 0

    local checkRendDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Rend.formattedName)
    if checkRendDebuff then
        local cRendExpirationTime = checkRendDebuff.expirationTime - currentTime
        local cSkullsplitterRendMod = cRendExpirationTime / checkRendDebuff.duration
        local checkDotPotency = wan.CheckDotPotency(nSkullsplitterDmg)
        cSkullsplitterDotDmgBase = cSkullsplitterDotDmgBase + (nRendDotDmg * cSkullsplitterRendMod * nSkullsplitter * checkDotPotency)
    end

    local checkMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nil, "DeepWounds")
    if checkMasteryDeepWoundsDebuff then
        local cMasteryDeepWoundsExpirationTime = checkMasteryDeepWoundsDebuff.expirationTime - currentTime
        local cSkullsplitterMasteryDeepWoundsMod = cMasteryDeepWoundsExpirationTime / checkMasteryDeepWoundsDebuff.duration
        local checkDotPotency = wan.CheckDotPotency(nSkullsplitterDmg)
        cSkullsplitterDotDmgBase = cSkullsplitterDotDmgBase + (nMasteryDeepWoundsDotDmg * cSkullsplitterMasteryDeepWoundsMod * nSkullsplitter * checkDotPotency)
    end

    ---- WARRIOR TRAITS ----

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cSweepingStrikesInstantDmgAoE = 0
    local cSweepingStrikesDotDmgAoE = 0
    local checkSweepingStrikesBuff = nil
    if wan.spellData.SweepingStrikes.known then
        checkSweepingStrikesBuff = wan.CheckUnitBuff(nil, wan.spellData.SweepingStrikes.formattedName)
        local countSweepingStrikesUnit = 0

        if checkSweepingStrikesBuff then

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + (nSkullsplitterDmg * nSweepingStrikes * checkUnitPhysicalDR)

                    local checkUnitRendDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.Rend.formattedName)
                    if checkUnitRendDebuff then
                        local cUnitRendExpirationTime = checkUnitRendDebuff.expirationTime - currentTime
                        local cUnitSkullsplitterRendMod = cUnitRendExpirationTime / checkUnitRendDebuff.duration
                        local checkUnitDotPotency = wan.CheckDotPotency(nSkullsplitterDmg)
                        cSweepingStrikesDotDmgAoE = cSweepingStrikesDotDmgAoE + (nRendDotDmg * cUnitSkullsplitterRendMod * nSkullsplitter * checkUnitDotPotency)
                    end

                    local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "DeepWounds")
                    if checkUnitMasteryDeepWoundsDebuff then
                        local cUnitMasteryDeepWoundsExpirationTime = checkUnitMasteryDeepWoundsDebuff.expirationTime - currentTime
                        local cUnitSkullsplitterMasteryDeepWoundsMod = cUnitMasteryDeepWoundsExpirationTime / checkUnitMasteryDeepWoundsDebuff.duration
                        local checkUnitDotPotency = wan.CheckDotPotency(nSkullsplitterDmg)
                        cSweepingStrikesDotDmgAoE = cSweepingStrikesDotDmgAoE + (nMasteryDeepWoundsDotDmg * cUnitSkullsplitterMasteryDeepWoundsMod * nSkullsplitter * checkUnitDotPotency)
                    end

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

    if wan.traitData.Bloodletting.known then
        critChanceModBase = critChanceModBase + nBloodlettingCritChance
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
    local cSkullsplitterCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSkullsplitterCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSkullsplitterInstantDmg = cSkullsplitterInstantDmg
        + (nSkullsplitterDmg * checkPhysicalDR * cSkullsplitterCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cSkullsplitterDotDmg = cSkullsplitterDotDmg
        + (cSkullsplitterDotDmgBase * cSkullsplitterCritValueBase * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cSkullsplitterInstantDmgAoE = cSkullsplitterInstantDmgAoE
        + (cSweepingStrikesInstantDmgAoE * cSkullsplitterCritValue * cMasteryDeepWoundsAoE * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)

    cSkullsplitterDotDmgAoE = cSkullsplitterDotDmgAoE
        + (cSweepingStrikesDotDmgAoE * cSkullsplitterCritValueBase * cColossusSmashAoE * cDominanceoftheColossusAoE * cOverwhelmingBladesAoE)

    local cSkullsplitterDmg = cSkullsplitterInstantDmg + cSkullsplitterDotDmg + cSkullsplitterInstantDmgAoE + cSkullsplitterDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSkullsplitterDmg)
    wan.UpdateAbilityData(wan.spellData.Skullsplitter.basename, abilityValue, wan.spellData.Skullsplitter.icon, wan.spellData.Skullsplitter.name)
end

-- Init frame 
local frameSkullsplitter = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nSkullsplitterValues = wan.GetSpellDescriptionNumbers(wan.spellData.Skullsplitter.id, { 1, 2, 3 })
            nSkullsplitterDmg = nSkullsplitterValues[1]
            nSkullsplitter = nSkullsplitterValues[2] * 0.01 + 1

            nRendDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Rend.id, { 2 })

            nMasteryDeepWoundsDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 1 })
        end
    end)
end
frameSkullsplitter:RegisterEvent("ADDON_LOADED")
frameSkullsplitter:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Skullsplitter.known and wan.spellData.Skullsplitter.id
        wan.BlizzardEventHandler(frameSkullsplitter, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSkullsplitter, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nSweepingStrikesValues = wan.GetSpellDescriptionNumbers(wan.spellData.SweepingStrikes.id, { 2, 3, 4 })
        nSweepingStrikesUnitCap = nSweepingStrikesValues[1]
        nSweepingStrikesMaxRange = nSweepingStrikesValues[2]
        nSweepingStrikes = nSweepingStrikesValues[3] * 0.01

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001

        nBloodlettingCritChance = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodletting.entryid, { 2 })

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSkullsplitter, CheckAbilityValue, abilityActive)
    end
end)