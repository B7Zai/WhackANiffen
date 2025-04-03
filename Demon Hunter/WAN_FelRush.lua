local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nFelRusDmg, nFelRushMaxRange = 0, 20

-- Init trait data
local sDarknessBuff = "Darkness"
local bDashofChaos = false
local bUnboundChaos, sUnboundChaos, nUnboundChaos = false, "UnboundChaos", 0
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.spellData.FelRush.name == "Infernal Strike"
        or not wan.IsSpellUsable(wan.spellData.FelRush.id)
        or wan.CheckUnitBuff(nil, sDarknessBuff)
    then
        wan.UpdateAbilityData(wan.spellData.FelRush.basename)
        return
    end

    local checkCharges, checkMaxcharges = wan.CheckSpellCharges(wan.spellData.FelRush.id)
    if checkCharges ~= checkMaxcharges or (bUnboundChaos and not wan.CheckUnitBuff(nil, sUnboundChaos)) then
        wan.UpdateAbilityData(wan.spellData.FelRush.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nFelRushMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FelRush.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFelRushInstantDmg = 0
    local cFelRushDotDmg = 0
    local cFelRushInstantDmgAoE = 0
    local cFelRushDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HAVOC TRAITS ----

    local cDashofChaosInstantDmgAoE = 0
    local cDashofChaos = 1
    if bDashofChaos then
        cDashofChaos = 0.5
        cDashofChaosInstantDmgAoE = cDashofChaosInstantDmgAoE + (nFelRusDmg * countValidUnit * cDashofChaos)
    end

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

    local cFelRushCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFelRushCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFelRushInstantDmg = cFelRushInstantDmg

    cFelRushDotDmg = cFelRushDotDmg

    cFelRushInstantDmgAoE = cFelRushInstantDmgAoE
        + (nFelRusDmg * countValidUnit * cFelRushCritValue * cReaversMarkAoE * cUnboundChaos)
        + (cDashofChaosInstantDmgAoE * cFelRushCritValue * cReaversMarkAoE)

    cFelRushDotDmgAoE = cFelRushDotDmgAoE

    local cFelRushDmg = cFelRushInstantDmg + cFelRushDotDmg + cFelRushInstantDmgAoE + cFelRushDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFelRushDmg)
    wan.UpdateAbilityData(wan.spellData.FelRush.basename, abilityValue, wan.spellData.FelRush.icon, wan.spellData.FelRush.name)
end

-- Init frame 
local frameFelRush = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFelRusDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FelRush.id, { 1 })

            sDarknessBuff = wan.spellData.Darkness.formattedName
        end
    end)
end
frameFelRush:RegisterEvent("ADDON_LOADED")
frameFelRush:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.FelRush.isPassive and wan.spellData.FelRush.known and wan.spellData.FelRush.id
        wan.BlizzardEventHandler(frameFelRush, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFelRush, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        bDashofChaos = wan.traitData.DashofChaos.known

        bUnboundChaos = wan.traitData.UnboundChaos.known
        sUnboundChaos = wan.traitData.UnboundChaos.traitkey
        nUnboundChaos = wan.GetTraitDescriptionNumbers(wan.traitData.UnboundChaos.entryid, { 1 }, wan.traitData.UnboundChaos.rank) * 0.01

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFelRush, CheckAbilityValue, abilityActive)
    end
end)