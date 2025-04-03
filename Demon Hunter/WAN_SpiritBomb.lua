local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nSpiritBombStackCap, nSpiritBombDmg, nSpiritBombSoftCap, nSpiritBombStackUse, nSpiritBombMaxRange = 0, 0, 0, 0,11
local nSoulCleaveUnitCap, nSoulCleaveDmg, cMedianPhysicalDR = 0, 0, 0
local sSouldFragmentsBuff = "SoulFragments"

-- Init trait data
local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.SpiritBomb.id)
    then
        wan.UpdateAbilityData(wan.spellData.SpiritBomb.basename)
        return
    end

    local checkSoulFragmentsBuff = wan.CheckUnitBuff(nil, sSouldFragmentsBuff)
    local nSoulFragmentsStack = checkSoulFragmentsBuff and checkSoulFragmentsBuff.applications or 0
    if not checkDemonsurgeEmpowerment then
        if nSoulFragmentsStack < nSpiritBombStackUse then
            wan.UpdateAbilityData(wan.spellData.SpiritBomb.basename)
            return
        end
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nSpiritBombMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.SpiritBomb.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSpiritBombInstantDmg = 0
    local cSpiritBombDotDmg = 0
    local cSpiritBombInstantDmgAoE = 0
    local cSpiritBombDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local countSoulCleaveUnits = 0
    local cPhysicalDR = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cPhysicalDR = cPhysicalDR + checkUnitPhysicalDR

        countSoulCleaveUnits = countSoulCleaveUnits + 1

        if countSoulCleaveUnits >= nSoulCleaveUnitCap then
            break
        end
    end

    -- this is used to determined how much soul fragments are needed when going against soul cleave
    cMedianPhysicalDR = cPhysicalDR / countSoulCleaveUnits

    ---- VENGEANCE TRAITS ----

    local cFieryDemiseAoE = 1
    if bFieryDemise then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFieryBrandDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFieryDemise)
            if checkUnitFieryBrandDebuff then

                cFieryDemiseAoE = cFieryDemiseAoE + (nFieryDemise / countValidUnit)
            end
        end
    end

    local cVulnerabilityAoE = 1
    if bVulnerability then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFrailtyDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFrailty)
            if checkUnitFrailtyDebuff then
                local nFrailtyStacks = checkUnitFrailtyDebuff and checkUnitFrailtyDebuff.applications

                if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

                cVulnerabilityAoE = cVulnerabilityAoE + ((nVulnerability * nFrailtyStacks) / countValidUnit)
            end
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMarkAoE = 1
    if bReaversMark then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitReaversMarkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sReaversMark)
            if checkUnitReaversMarkDebuff then
                local cReaversMarkStacks = checkUnitReaversMarkDebuff and checkUnitReaversMarkDebuff.applications

                if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                    cReaversMarkStacks = 1
                end

                cReaversMarkAoE = cReaversMarkAoE + ((nReaversMark * cReaversMarkStacks) / countValidUnit)
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

    local cSpiritBombUnitOverflow = wan.AdjustSoftCapUnitOverflow(nSpiritBombSoftCap, countValidUnit)
    local cSpiritBombCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSpiritBombCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSpiritBombInstantDmg = cSpiritBombInstantDmg

    cSpiritBombDotDmg = cSpiritBombDotDmg

    cSpiritBombInstantDmgAoE = cSpiritBombInstantDmgAoE
        + (nSpiritBombDmg * nSoulFragmentsStack * cSpiritBombUnitOverflow * cSpiritBombCritValue * cFieryDemiseAoE * cVulnerabilityAoE)
        + (cDemonsurgeInstantDmgAoE * cSpiritBombCritValueBase * cFieryDemiseAoE * cVulnerabilityAoE)

    cSpiritBombDotDmgAoE = cSpiritBombDotDmgAoE

    local cSpiritBombDmg = cSpiritBombInstantDmg + cSpiritBombDotDmg + cSpiritBombInstantDmgAoE + cSpiritBombDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSpiritBombDmg)
    wan.UpdateAbilityData(wan.spellData.SpiritBomb.basename, abilityValue, wan.spellData.SpiritBomb.icon, wan.spellData.SpiritBomb.name)
end

-- Init frame 
local frameSpiritBomb = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local aSpiritBombValues = wan.GetSpellDescriptionNumbers(wan.spellData.SpiritBomb.id, { 1, 2, 5 })
            nSpiritBombStackCap = aSpiritBombValues[1]
            nSpiritBombDmg = aSpiritBombValues[2]
            nSpiritBombSoftCap = aSpiritBombValues[3]

            local aSoulCleaveValues = wan.GetSpellDescriptionNumbers(wan.spellData.ChaosStrike.id, { 1, 2 })
            nSoulCleaveUnitCap = aSoulCleaveValues[1]
            nSoulCleaveDmg = aSoulCleaveValues[2]

            local cSoulCleaveBase = nSoulCleaveDmg * cMedianPhysicalDR
            for i = 1, nSpiritBombStackCap do
                local cSpiritBombDmg = nSpiritBombDmg * i
                if cSpiritBombDmg >= cSoulCleaveBase then
                    nSpiritBombStackUse = i
                    break
                end
            end
            
            if bDemonsurge then
                
                local checkMetamorphosisBuff = wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
                if not checkMetamorphosisBuff then
                    checkDemonsurgeEmpowerment = false
                end
            end

            local nDemonsurgeValues = wan.GetTraitDescriptionNumbers(wan.traitData.Demonsurge.entryid, { 1, 2 }, wan.traitData.Demonsurge.rank)
            nDemonsurgeDmg = nDemonsurgeValues[1]
            nDemonsurgeSoftCap = nDemonsurgeValues[2]
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.SpiritBomb.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.FelDevastation.id then
            checkDemonsurgeEmpowerment = true
        end
    end)
end
frameSpiritBomb:RegisterEvent("ADDON_LOADED")
frameSpiritBomb:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.SpiritBomb.isPassive and wan.spellData.SpiritBomb.known and wan.spellData.SpiritBomb.id
        wan.BlizzardEventHandler(frameSpiritBomb, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameSpiritBomb, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bFieryDemise = wan.traitData.FieryDemise.known
        nFieryDemise = wan.GetTraitDescriptionNumbers(wan.traitData.FieryDemise .entryid, { 1 }, wan.traitData.FieryDemise .rank) * 0.01

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bDemonsurge = wan.traitData.Demonsurge.known

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSpiritBomb, CheckAbilityValue, abilityActive)
    end
end)