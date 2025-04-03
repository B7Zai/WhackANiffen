local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nSigilofFlameInstantDmg, nSigilofFlameMaxRange, nSigilofFlameDotDmg = 0, 8, 0

-- Init trait data
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.SigilofFlame.id)
    then
        wan.UpdateAbilityData(wan.spellData.SigilofFlame.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.SigilofFlame.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.SigilofFlame.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSigilofFlameInstantDmg = 0
    local cSigilofFlameDotDmg = 0
    local cSigilofFlameInstantDmgAoE = 0
    local cSigilofFlameDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cSigilofFlameDotDmgBaseAoE = 0
    local cSigilofFlameInstantDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkDotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cSigilofFlameDotDmgBaseAoE = cSigilofFlameDotDmgBaseAoE + (nSigilofFlameDotDmg * checkDotPotency)
        cSigilofFlameInstantDmgBaseAoE = cSigilofFlameInstantDmgBaseAoE + nSigilofFlameInstantDmg
    end

    ---- HAVOC TRAITS ----

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

    local cSigilofFlameCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSigilofFlameCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSigilofFlameInstantDmg = cSigilofFlameInstantDmg

    cSigilofFlameDotDmg = cSigilofFlameDotDmg

    cSigilofFlameInstantDmgAoE = cSigilofFlameInstantDmgAoE
        + (cSigilofFlameInstantDmgBaseAoE * cSigilofFlameCritValue * cFieryDemise * cVulnerabilityAoE * cReaversMarkAoE)
        + (cDemonsurgeInstantDmgAoE * cSigilofFlameCritValueBase * cFieryDemise * cVulnerabilityAoE)

    cSigilofFlameDotDmgAoE = cSigilofFlameDotDmgAoE
        + (cSigilofFlameDotDmgBaseAoE * cSigilofFlameCritValue * cFieryDemise * cVulnerabilityAoE * cReaversMarkAoE)

    local cSigilofFlameDmg = cSigilofFlameInstantDmg + cSigilofFlameDotDmg + cSigilofFlameInstantDmgAoE + cSigilofFlameDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSigilofFlameDmg)
    wan.UpdateAbilityData(wan.spellData.SigilofFlame.basename, abilityValue, wan.spellData.SigilofFlame.icon, wan.spellData.SigilofFlame.name)
end

-- Init frame 
local frameSigilofFlame = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nSigilofFlameValues = wan.GetSpellDescriptionNumbers(wan.spellData.SigilofFlame.id, { 2, 3 })
            nSigilofFlameInstantDmg = nSigilofFlameValues[1]
            nSigilofFlameDotDmg = nSigilofFlameValues[2]


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

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.SigilofFlame.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

    end)
end
frameSigilofFlame:RegisterEvent("ADDON_LOADED")
frameSigilofFlame:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.SigilofFlame.isPassive and wan.spellData.SigilofFlame.known and wan.spellData.SigilofFlame.id
        wan.BlizzardEventHandler(frameSigilofFlame, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameSigilofFlame, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

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
        wan.SetUpdateRate(frameSigilofFlame, CheckAbilityValue, abilityActive)
    end
end)