local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nImmolationAuraInstantDmg, nImmolationAuraMaxRange, nImmolationAuraDotDmg, nImmolationAuraTicks = 0, 8, 0, 10

-- Init trait data
local bAuraofPain, nAuraofPainCritChance = false, 0
local bIsolatedPrey = false
local bBurningWound, sBurningWoundDebuff, nBurningWound = false, "BurningWound", 0
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bGrowingInferno, nGrowingInferno = false, 0
local bRagefire, nRagefire, nRagefireCritChance = false, 0, 0

local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0
local checkDemonsurgeEmpowerment = false

local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0
local bFlamebound, nFlameboundCritDamage = false, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ImmolationAura.id)
    then
        wan.UpdateAbilityData(wan.spellData.ImmolationAura.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nImmolationAuraMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ImmolationAura.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cImmolationAuraInstantDmg = 0
    local cImmolationAuraDotDmg = 0
    local cImmolationAuraInstantDmgAoE = 0
    local cImmolationAuraDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cImmolationAuraDotDmgBaseAoE = 0
    local cImmolationAuraInstantDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkDotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cImmolationAuraDotDmgBaseAoE = cImmolationAuraDotDmgBaseAoE + (nImmolationAuraDotDmg * checkDotPotency)
        cImmolationAuraInstantDmgBaseAoE = cImmolationAuraInstantDmgBaseAoE + nImmolationAuraInstantDmg
    end

    ---- DEMON HUNTER TRAITS ----

    if bAuraofPain then
        critChanceMod = critChanceMod + nAuraofPainCritChance
    end

    ---- HAVOC TRAITS ----

    local cGrowingInferno = 1
    if bGrowingInferno then
        local cGrowingInfernoDmgOverflow = wan.UncappedDamageOverflow(nImmolationAuraTicks, nGrowingInferno)
        cGrowingInferno = cGrowingInferno + cGrowingInfernoDmgOverflow
    end

    if bIsolatedPrey and countValidUnit < 2 then
        critChanceMod = critChanceMod + 100
    end

    local cBurningWoundAoE = 1
    if bBurningWound then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitBurningWoundDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sBurningWoundDebuff)
            if checkUnitBurningWoundDebuff then
                cBurningWoundAoE = cBurningWoundAoE + (nBurningWound / countValidUnit)
            end
        end
    end

    local cRagefireInstantDmgAoE = 0
    if bRagefire then
        local cImmolationDmg = cImmolationAuraDotDmgBaseAoE + cImmolationAuraInstantDmgBaseAoE
        local cRagefireCritCap = math.min(wan.CritChance, nRagefireCritChance) * 0.01 + 1

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkDotPotency = wan.CheckDotPotency(cImmolationDmg, nameplateUnitToken)

            cRagefireInstantDmgAoE = cRagefireInstantDmgAoE + (cImmolationDmg * nRagefire * cRagefireCritCap * checkDotPotency)
        end
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
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

    if bFlamebound then
        critDamageMod = critDamageMod + nFlameboundCritDamage
    end

    local cImmolationAuraCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cImmolationAuraCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cImmolationAuraInstantDmg = cImmolationAuraInstantDmg

    cImmolationAuraDotDmg = cImmolationAuraDotDmg

    cImmolationAuraInstantDmgAoE = cImmolationAuraInstantDmgAoE
        + (cImmolationAuraInstantDmgBaseAoE * cImmolationAuraCritValue * cBurningWoundAoE * cFieryDemise * cReaversMarkAoE * cVulnerabilityAoE)
        + (cRagefireInstantDmgAoE * cBurningWoundAoE * cReaversMarkAoE)
        + (cDemonsurgeInstantDmgAoE * cImmolationAuraCritValueBase * cFieryDemise * cVulnerabilityAoE)

    cImmolationAuraDotDmgAoE = cImmolationAuraDotDmgAoE
        + (cImmolationAuraDotDmgBaseAoE * cImmolationAuraCritValue * cGrowingInferno * cBurningWoundAoE * cFieryDemise * cReaversMarkAoE * cVulnerabilityAoE)

    local cImmolationAuraDmg = cImmolationAuraInstantDmg + cImmolationAuraDotDmg + cImmolationAuraInstantDmgAoE + cImmolationAuraDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cImmolationAuraDmg)
    wan.UpdateAbilityData(wan.spellData.ImmolationAura.basename, abilityValue, wan.spellData.ImmolationAura.icon, wan.spellData.ImmolationAura.name)
end

-- Init frame 
local frameImmolationAura = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nImmolationAuraValues = wan.GetSpellDescriptionNumbers(wan.spellData.ImmolationAura.id, { 1, 2, 3 })
            nImmolationAuraInstantDmg = nImmolationAuraValues[1]
            nImmolationAuraMaxRange = nImmolationAuraValues[2]
            nImmolationAuraDotDmg = nImmolationAuraValues[3]


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

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.ImmolationAura.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

    end)
end
frameImmolationAura:RegisterEvent("ADDON_LOADED")
frameImmolationAura:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.ImmolationAura.isPassive and wan.spellData.ImmolationAura.known and wan.spellData.ImmolationAura.id
        wan.BlizzardEventHandler(frameImmolationAura, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameImmolationAura, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bAuraofPain = wan.traitData.AuraofPain.known
        nAuraofPainCritChance = wan.GetTraitDescriptionNumbers(wan.traitData.AuraofPain.entryid, { 1 }, wan.traitData.AuraofPain.rank)

        bGrowingInferno = wan.traitData.GrowingInferno.known
        nGrowingInferno = wan.GetTraitDescriptionNumbers(wan.traitData.GrowingInferno.entryid, { 1 }, wan.traitData.GrowingInferno.rank) * 0.01

        bIsolatedPrey = wan.traitData.IsolatedPrey.known

        bBurningWound = wan.traitData.BurningWound.known
        sBurningWoundDebuff = wan.traitData.BurningWound.traitkey
        nBurningWound = wan.GetTraitDescriptionNumbers(wan.traitData.BurningWound.entryid, { 3 }, wan.traitData.BurningWound.rank) * 0.01

        bRagefire = wan.traitData.Ragefire.known
        local aRagefireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Ragefire.entryid, { 1, 2 }, wan.traitData.Ragefire.rank)
        nRagefire = aRagefireValues[1] * 0.01
        nRagefireCritChance = (nImmolationAuraTicks / aRagefireValues[2]) * 10

        bFieryDemise = wan.traitData.FieryDemise.known
        nFieryDemise = wan.GetTraitDescriptionNumbers(wan.traitData.FieryDemise .entryid, { 1 }, wan.traitData.FieryDemise .rank) * 0.01

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bDemonsurge = wan.traitData.Demonsurge.known

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 10

        bFlamebound = wan.traitData.Flamebound.known
        nFlameboundCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.Flamebound.entryid, { 2 }, wan.traitData.Flamebound.rank)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameImmolationAura, CheckAbilityValue, abilityActive)
    end
end)