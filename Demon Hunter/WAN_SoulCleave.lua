local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nSoulCleaveUnitCap, nSoulCleaveDmg, nSoulCleaveStackUse, nSoulCleaveMaxRange = 0, 0, 0, 11
local sSouldFragmentsBuff = "SoulFragments"
local isTank = false

-- Init trait data
local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bFocusedCleave, nFocusedCleave = false, 0
local bSpiritBomb, nSpiritBombStackUse, nSpiritBombDmg, cMedianPhysicalDR = false, 0, 0, 0
local bVulnerability, nVulnerability = false, 0

local checkFuryoftheAldrachiEmpowerment = false
local bFuryoftheAldrachi, sFuryoftheAldrachiBuff, nFuryoftheAldrachiHits, nFuryoftheAldrachiHitCap, nFuryoftheAldrachiDmg = false, "GlaiveFlurry", 0, 0, 0
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bBurningBlades, nBurningBlades = false, 0
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (bSpiritBomb and not checkDemonsurgeEmpowerment and not wan.IsSpellUsable(wan.spellData.SpiritBomb.id))
        or not wan.IsSpellUsable(wan.spellData.ChaosStrike.id)
    then
        wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename)
        return
    end

    local checkSoulFragmentsBuff = wan.CheckUnitBuff(nil, sSouldFragmentsBuff)
    local nSoulFragmentsStack = checkSoulFragmentsBuff and checkSoulFragmentsBuff.applications or 0
    if not checkDemonsurgeEmpowerment then
        if nSoulFragmentsStack < nSoulCleaveStackUse then
            wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename)
            return
        end
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nSoulCleaveMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSoulCleaveInstantDmg = 0
    local cSoulCleaveDotDmg = 0
    local cSoulCleaveInstantDmgAoE = 0
    local cSoulCleaveDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cSoulCleaveInstantDmgAoEBase = 0
    local countSoulCleaveUnits = 0
    local cAveragePhysicalDR= 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cAveragePhysicalDR = cAveragePhysicalDR + checkUnitPhysicalDR

        cSoulCleaveInstantDmgAoEBase = cSoulCleaveInstantDmgAoEBase + (nSoulCleaveDmg * checkUnitPhysicalDR)

        countSoulCleaveUnits = countSoulCleaveUnits + 1

        if countSoulCleaveUnits >= nSoulCleaveUnitCap then
            break
        end
    end

    -- this is used to determined how much soul fragments are needed when going against spririt bomb
    cMedianPhysicalDR = cAveragePhysicalDR / countSoulCleaveUnits

    ---- VENGEANCE TRAITS ----

    local cFocusedCleave = 1
    if bFocusedCleave then
        cFocusedCleave = cFocusedCleave + (nFocusedCleave / countSoulCleaveUnits)
    end

    local cFieryDemiseAoE = 1
    if bFieryDemise then
        local countFieryDemiseUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFieryBrandDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFieryDemise)
            if checkUnitFieryBrandDebuff then

                cFieryDemiseAoE = cFieryDemiseAoE + (nFieryDemise / countSoulCleaveUnits)
            end

            countFieryDemiseUnits = countFieryDemiseUnits + 1

            if countFieryDemiseUnits >= nSoulCleaveUnitCap then
                break
            end
        end
    end

    local cVulnerabilityAoE = 1
    if bVulnerability then
        local countVulnerabilityUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFrailtyDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFrailty)
            if checkUnitFrailtyDebuff then
                local nFrailtyStacks = checkUnitFrailtyDebuff and checkUnitFrailtyDebuff.applications

                if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

                cVulnerabilityAoE = cVulnerabilityAoE + ((nVulnerability * nFrailtyStacks) / countSoulCleaveUnits)
            end

            countVulnerabilityUnits = countVulnerabilityUnits + 1

            if countVulnerabilityUnits >= nSoulCleaveUnitCap then
                break
            end
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cFuryoftheAldrachiInstantDmgAoE = 0
    if bFuryoftheAldrachi then
        local checkGlaiveFlurryBuff = wan.CheckUnitBuff(nil, sFuryoftheAldrachiBuff)
        local cFuryoftheAldrachiHits = checkFuryoftheAldrachiEmpowerment and nFuryoftheAldrachiHitCap or nFuryoftheAldrachiHits
        if checkGlaiveFlurryBuff then
            cFuryoftheAldrachiInstantDmgAoE = cFuryoftheAldrachiInstantDmgAoE + (nFuryoftheAldrachiDmg * cFuryoftheAldrachiHits * countValidUnit)
        end
    end

    local cReaversMarkAoE = 1
    if bReaversMark then
        local countReaversMarkUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitReaversMarkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sReaversMark)
            if checkUnitReaversMarkDebuff then
                local cReaversMarkStacks = checkUnitReaversMarkDebuff and checkUnitReaversMarkDebuff.applications

                if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                    cReaversMarkStacks = 1
                end

                cReaversMarkAoE = cReaversMarkAoE + ((nReaversMark * cReaversMarkStacks) / countSoulCleaveUnits)
            end

            countReaversMarkUnits = countReaversMarkUnits + 1

            if countReaversMarkUnits >= nSoulCleaveUnitCap then
                break
            end
        end
    end

    ---- FEL-SCARRED TRAITS ----

    local cDemonsurgeInstantDmgAoE = 0
    if bDemonsurge and checkDemonsurgeEmpowerment then
        local _, countValidUnitDemonsurge = wan.ValidUnitBoolCounter(nil, bDemonsurgeMaxRange)
        local cDemonsurgeUnitOverflow = wan.AdjustSoftCapUnitOverflow(nDemonsurgeSoftCap, countValidUnitDemonsurge)

        local cFocusedHatred = 1
        if bFocusedHatred then
            local nFocusedHatredUnits = math.max(countValidUnitDemonsurge - 1, 0)

            cFocusedHatred = cFocusedHatred + (math.max((nFocusedHatred - (nFocusedHatredStep *  nFocusedHatredUnits)), 0))
        end

        cDemonsurgeInstantDmgAoE = cDemonsurgeInstantDmgAoE + (nDemonsurgeDmg * cDemonsurgeUnitOverflow * cFocusedHatred)
    end

    local cBurningBladesDotDmgAoE = 0
    if bBurningBlades then
        local countBurningBladesUnitCap = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkDotPotency = wan.CheckDotPotency(nSoulCleaveDmg, nameplateUnitToken)

            cBurningBladesDotDmgAoE = cBurningBladesDotDmgAoE + (nSoulCleaveDmg * nBurningBlades * checkDotPotency)

            countBurningBladesUnitCap = countBurningBladesUnitCap + 1

            if countBurningBladesUnitCap >= nSoulCleaveUnitCap then
                break
            end
        end
    end

    local cSoulCleaveCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSoulCleaveCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSoulCleaveInstantDmg = cSoulCleaveInstantDmg

    cSoulCleaveDotDmg = cSoulCleaveDotDmg

    cSoulCleaveInstantDmgAoE = cSoulCleaveInstantDmgAoE
        + (cSoulCleaveInstantDmgAoEBase * cSoulCleaveCritValue * cFocusedCleave * cVulnerabilityAoE)
        + (cDemonsurgeInstantDmgAoE * cSoulCleaveCritValueBase * cFieryDemiseAoE * cVulnerabilityAoE)
        + (cFuryoftheAldrachiInstantDmgAoE * cSoulCleaveCritValueBase * cVulnerabilityAoE)

    cSoulCleaveDotDmgAoE = cSoulCleaveDotDmgAoE
        + (cBurningBladesDotDmgAoE * cSoulCleaveCritValue * cFocusedCleave * cFieryDemiseAoE * cVulnerabilityAoE)

    local cSoulCleaveDmg = cSoulCleaveInstantDmg + cSoulCleaveDotDmg + cSoulCleaveInstantDmgAoE + cSoulCleaveDotDmgAoE

    -- priority modifier for the Aldrachi hero class
    if countValidUnit > 1 and cFuryoftheAldrachiInstantDmgAoE > 0 and not checkFuryoftheAldrachiEmpowerment then
        cSoulCleaveDmg = 0
    end

    -- Update ability data
    local abilityValue = math.floor(cSoulCleaveDmg)
    wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename, abilityValue, wan.spellData.ChaosStrike.icon, wan.spellData.ChaosStrike.name)
end

-- Init frame 
local frameSoulCleave = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local aSoulCleaveValues = wan.GetSpellDescriptionNumbers(wan.spellData.ChaosStrike.id, { 1, 2, 4 })
            nSoulCleaveUnitCap = aSoulCleaveValues[1]
            nSoulCleaveDmg = aSoulCleaveValues[2]
            nSoulCleaveStackUse = aSoulCleaveValues[3]

            if bSpiritBomb then
                nSpiritBombDmg = wan.GetTraitDescriptionNumbers(wan.traitData.SpiritBomb.entryid, { 2 }, wan.traitData.SpiritBomb.rank)
                local cSoulCleaveDmgBase = nSoulCleaveDmg * cMedianPhysicalDR
                for i = 1, nSpiritBombStackUse do
                    local cSpiritBombDmg = nSpiritBombDmg * i
                    if cSpiritBombDmg >= cSoulCleaveDmgBase then
                        nSoulCleaveStackUse = i
                        break
                    end
                end
            end

            -- nFuryoftheAldrachiDmg is a made up value
            -- no tooltip carry any values for this talent except the buff itself
            -- when checking the buff, .points is an empty array
            nFuryoftheAldrachiDmg = nSoulCleaveDmg * 0.45

            local nDemonsurgeValues = wan.GetTraitDescriptionNumbers(wan.traitData.Demonsurge.entryid, { 1, 2 }, wan.traitData.Demonsurge.rank)
            nDemonsurgeDmg = nDemonsurgeValues[1]
            nDemonsurgeSoftCap = nDemonsurgeValues[2]

            if bDemonsurge then

                local checkMetamorphosisBuff = wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
                if not checkMetamorphosisBuff then
                    checkDemonsurgeEmpowerment = false
                end
            end
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.ChaosStrike.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.FelDevastation.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.DemonsBite.id then
            local checkGlaiveFlurryBuff = wan.CheckUnitBuff(nil, sFuryoftheAldrachiBuff)
            if checkGlaiveFlurryBuff then
                checkFuryoftheAldrachiEmpowerment = true
            end
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.ChaosStrike.id then
            checkFuryoftheAldrachiEmpowerment = false
        end

    end)
end
frameSoulCleave:RegisterEvent("ADDON_LOADED")
frameSoulCleave:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        isTank = wan.spellData.MasteryFelBlood.known

        abilityActive = isTank and not wan.spellData.ChaosStrike.isPassive and wan.spellData.ChaosStrike.known and wan.spellData.ChaosStrike.id
        wan.BlizzardEventHandler(frameSoulCleave, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameSoulCleave, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bFocusedCleave = wan.traitData.FocusedCleave.known
        nFocusedCleave = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedCleave.entryid, { 1 }, wan.traitData.FocusedCleave.rank) * 0.01

        bSpiritBomb = wan.traitData.SpiritBomb.known
        nSpiritBombStackUse = wan.GetTraitDescriptionNumbers(wan.traitData.SpiritBomb.entryid, { 1 }, wan.traitData.SpiritBomb.rank)

        bFieryDemise = wan.traitData.FieryDemise.known
        nFieryDemise = wan.GetTraitDescriptionNumbers(wan.traitData.FieryDemise .entryid, { 1 }, wan.traitData.FieryDemise .rank) * 0.01

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01

        bFuryoftheAldrachi = wan.traitData.FuryoftheAldrachi.known
        local nFuryoftheAldrachiValues = wan.GetTraitDescriptionNumbers(wan.traitData.FuryoftheAldrachi.entryid, { 1, 2 }, wan.traitData.FuryoftheAldrachi.rank)
        nFuryoftheAldrachiHits = nFuryoftheAldrachiValues[1]
        nFuryoftheAldrachiHitCap = nFuryoftheAldrachiValues[2]

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bDemonsurge = wan.traitData.Demonsurge.known

        bBurningBlades = wan.traitData.BurningBlades.known
        nBurningBlades = wan.GetTraitDescriptionNumbers(wan.traitData.BurningBlades.entryid, { 1 }, wan.traitData.BurningBlades.rank) * 0.01

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSoulCleave, CheckAbilityValue, abilityActive)
    end
end)