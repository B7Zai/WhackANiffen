local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nFelDevastationDmg, nFelDevastationSoftCap, nFelDevastationMaxRange = 0, 0, 20

-- Init trait data
local bCollectiveAnguish, nCollectiveAnguishDmg = false, 0

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
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.FelDevastation.id)
    then
        wan.UpdateAbilityData(wan.spellData.FelDevastation.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.FelDevastation.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FelDevastation.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFelDevastationInstantDmg = 0
    local cFelDevastationDotDmg = 0
    local cFelDevastationInstantDmgAoE = 0
    local cFelDevastationDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- DEMON HUNTER TRAITS ----

    local cCollectiveAnguishInstantDmgAoE = 0
    if bCollectiveAnguish then
        cCollectiveAnguishInstantDmgAoE = cCollectiveAnguishInstantDmgAoE + (nCollectiveAnguishDmg * countValidUnit)
    end

    ---- VENGEANCE TRAITS ----

    local cFieryDemise = 1
    if bFieryDemise then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFieryBrandDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFieryDemise)
            if checkUnitFieryBrandDebuff then

                cFieryDemise = cFieryDemise + (nFieryDemise / countValidUnit)
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

    local cFelDevastationUnitOverflow = wan.AdjustSoftCapUnitOverflow(nFelDevastationSoftCap, countValidUnit)
    local cFelDevastationCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFelDevastationCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFelDevastationInstantDmg = cFelDevastationInstantDmg

    cFelDevastationDotDmg = cFelDevastationDotDmg

    cFelDevastationInstantDmgAoE = cFelDevastationInstantDmgAoE
        + (nFelDevastationDmg * cFelDevastationUnitOverflow * cFelDevastationCritValue * cFieryDemise * cVulnerabilityAoE * cReaversMarkAoE)
        + (cCollectiveAnguishInstantDmgAoE * cFelDevastationCritValueBase * cVulnerabilityAoE * cReaversMarkAoE)
        + (cDemonsurgeInstantDmgAoE * cFelDevastationCritValueBase * cFieryDemise * cVulnerabilityAoE)

    cFelDevastationDotDmgAoE = cFelDevastationDotDmgAoE

    local cFelDevastationDmg = cFelDevastationInstantDmg + cFelDevastationDotDmg + cFelDevastationInstantDmgAoE + cFelDevastationDotDmgAoE

    local cdPotency = wan.CheckOffensiveCooldownPotency(cFelDevastationDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFelDevastationDmg) or 0
    wan.UpdateAbilityData(wan.spellData.FelDevastation.basename, abilityValue, wan.spellData.FelDevastation.icon, wan.spellData.FelDevastation.name)
end

-- Init frame 
local frameFelDevastation = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFelDevastationValues = wan.GetSpellDescriptionNumbers(wan.spellData.FelDevastation.id, { 1, 3 })
            nFelDevastationDmg = nFelDevastationValues[1]
            nFelDevastationSoftCap = nFelDevastationValues[2]

            nCollectiveAnguishDmg = wan.GetTraitDescriptionNumbers(wan.traitData.CollectiveAnguish.entryid, { 1 }, wan.traitData.CollectiveAnguish.rank)

            local nDemonsurgeValues = wan.GetTraitDescriptionNumbers(wan.traitData.Demonsurge.entryid, { 2, 3 }, wan.traitData.Demonsurge.rank)
            nDemonsurgeDmg = nDemonsurgeValues[1]
            nDemonsurgeSoftCap = nDemonsurgeValues[2]

            if bDemonsurge then
                local checkMetamorphosisBuff = wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
                
                if not checkMetamorphosisBuff then
                    checkDemonsurgeEmpowerment = false
                end
            end
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.FelDevastation.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

    end)
end
frameFelDevastation:RegisterEvent("ADDON_LOADED")
frameFelDevastation:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.FelDevastation.isPassive and wan.spellData.FelDevastation.known and wan.spellData.FelDevastation.id
        wan.BlizzardEventHandler(frameFelDevastation, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameFelDevastation, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bCollectiveAnguish = wan.traitData.CollectiveAnguish.known

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
        nFocusedHatredStep = nFocusedHatredValues[2] * 10
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFelDevastation, CheckAbilityValue, abilityActive)
    end
end)