local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nFelbladeDmg, nFelbladePowerGain, nFelbladeMaxRange = 0, 0, 20
local currentPower, currentPowerPercentage = 0, 0
local checkMaxPower = 0

-- Init trait data
local bUnboundChaos, sUnboundChaos, nUnboundChaos = false, "UnboundChaos", 0
local bKnowYourEnemy, nKnowYourEnemy = false, 0

local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Felblade.id)
    then
        wan.UpdateMechanicData(wan.spellData.Felblade.basename)
        wan.UpdateAbilityData(wan.spellData.Felblade.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nFelbladeMaxRange)
    if not isValidUnit then
        wan.UpdateMechanicData(wan.spellData.Felblade.basename)
        wan.UpdateAbilityData(wan.spellData.Felblade.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFelbladeInstantDmg = 0
    local cFelbladeDotDmg = 0
    local cFelbladeInstantDmgAoE = 0
    local cFelbladeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HAVOC TRAITS ----

    local cUnboundChaos = 1
    if bUnboundChaos then
        local checkUnboundChaosBuff = wan.CheckUnitBuff(nil, sUnboundChaos)
        if checkUnboundChaosBuff then
            cUnboundChaos = cUnboundChaos + nUnboundChaos
        end
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
    end

    ---- VENGEANCE TRAITS ----

    local cFieryDemise = 1
    if bFieryDemise then
        local checkFieryBrandDebuff = wan.CheckUnitDebuff(nil, sFieryDemise)

        if checkFieryBrandDebuff then
            cFieryDemise = cFieryDemise + nFieryDemise
        end
    end

    local cVulnerability = 1
    if bVulnerability then
        local checkFrailtyDebuff = wan.CheckUnitDebuff(nil, sFrailty)

        if checkFrailtyDebuff then
            local nFrailtyStacks = checkFrailtyDebuff and checkFrailtyDebuff.applications

            if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

            cVulnerability = cVulnerability + (nVulnerability * nFrailtyStacks)
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMark = 1
    if bReaversMark then
        local checkReaversMarkDebuff = wan.CheckUnitDebuff(nil, sReaversMark)
        if checkReaversMarkDebuff then
            local cReaversMarkStacks = checkReaversMarkDebuff and checkReaversMarkDebuff.applications

            if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                cReaversMarkStacks = 1
            end

            cReaversMark = cReaversMark + (nReaversMark * cReaversMarkStacks)
        end
    end

    local cFelbladeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFelbladeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFelbladeInstantDmg = cFelbladeInstantDmg
        + (nFelbladeDmg * cFelbladeCritValue * cReaversMark * cUnboundChaos * cFieryDemise * cVulnerability)

    cFelbladeDotDmg = cFelbladeDotDmg

    cFelbladeInstantDmgAoE = cFelbladeInstantDmgAoE

    cFelbladeDotDmgAoE = cFelbladeDotDmgAoE

    local cFelbladeDmg = cFelbladeInstantDmg + cFelbladeDotDmg + cFelbladeInstantDmgAoE + cFelbladeDotDmgAoE

    local abilityValue = 0
    local mechanicValue = 0
    if (checkMaxPower - currentPower) > nFelbladePowerGain then
        mechanicValue = math.floor(cFelbladeDmg)
    else
        abilityValue = math.floor(cFelbladeDmg)
    end

    wan.UpdateMechanicData(wan.spellData.Felblade.basename, mechanicValue, wan.spellData.Felblade.icon, wan.spellData.Felblade.name)
    wan.UpdateAbilityData(wan.spellData.Felblade.basename, abilityValue, wan.spellData.Felblade.icon, wan.spellData.Felblade.name)
end

-- Init frame 
local frameFelblade = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            checkMaxPower = wan.CheckUnitMaxPower("player", 17) or wan.CheckUnitMaxPower("player", 18) or 0
            currentPower = wan.CheckUnitPower("player", 17) or wan.CheckUnitPower("player", 18) or 0
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and (powerType == "FURY" or powerType == "PAIN") then
                currentPower = wan.CheckUnitPower("player", 17) or wan.CheckUnitPower("player", 18) or 0
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local aFelbladeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Felblade.id, { 1, 2 })
            nFelbladeDmg = aFelbladeValues[1]
            nFelbladePowerGain = aFelbladeValues[2]
        end
    end)
end
frameFelblade:RegisterEvent("ADDON_LOADED")
frameFelblade:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.Felblade.isPassive and wan.spellData.Felblade.known and wan.spellData.Felblade.id
        wan.BlizzardEventHandler(frameFelblade, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_POWER_UPDATE")
        wan.SetUpdateRate(frameFelblade, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bUnboundChaos = wan.traitData.UnboundChaos.known
        sUnboundChaos = wan.traitData.UnboundChaos.traitkey
        nUnboundChaos = wan.GetTraitDescriptionNumbers(wan.traitData.UnboundChaos.entryid, { 1 }, wan.traitData.UnboundChaos.rank) * 0.01

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
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFelblade, CheckAbilityValue, abilityActive)
    end
end)