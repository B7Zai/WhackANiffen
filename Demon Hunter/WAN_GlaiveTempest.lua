local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nGlaiveTempestDmg, nGlaiveTempestSoftCap, nGlaiveTempestMaxRange = 0, 0, 11

-- Init trait data
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.GlaiveTempest.id)
    then
        wan.UpdateAbilityData(wan.spellData.GlaiveTempest.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nGlaiveTempestMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.GlaiveTempest.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cGlaiveTempestInstantDmg = 0
    local cGlaiveTempestDotDmg = 0
    local cGlaiveTempestInstantDmgAoE = 0
    local cGlaiveTempestDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cGlaiveTempestInstantDmgBaseAoE = 0
    local cGlaiveTempestUnitOverflow = wan.SoftCapOverflow(nGlaiveTempestSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkDotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cGlaiveTempestInstantDmgBaseAoE = cGlaiveTempestInstantDmgBaseAoE + (nGlaiveTempestDmg * cGlaiveTempestUnitOverflow * checkDotPotency)
    end

    ---- HAVOC TRAITS ----

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

    local cGlaiveTempestCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cGlaiveTempestCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cGlaiveTempestInstantDmg = cGlaiveTempestInstantDmg

    cGlaiveTempestDotDmg = cGlaiveTempestDotDmg

    cGlaiveTempestInstantDmgAoE = cGlaiveTempestInstantDmgAoE
        + (cGlaiveTempestInstantDmgBaseAoE * cGlaiveTempestCritValue * cReaversMarkAoE)

    cGlaiveTempestDotDmgAoE = cGlaiveTempestDotDmgAoE

    local cGlaiveTempestDmg = cGlaiveTempestInstantDmg + cGlaiveTempestDotDmg + cGlaiveTempestInstantDmgAoE + cGlaiveTempestDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cGlaiveTempestDmg)
    wan.UpdateAbilityData(wan.spellData.GlaiveTempest.basename, abilityValue, wan.spellData.GlaiveTempest.icon, wan.spellData.GlaiveTempest.name)
end

-- Init frame 
local frameGlaiveTempest = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nGlaiveTempestValues = wan.GetSpellDescriptionNumbers(wan.spellData.GlaiveTempest.id, { 1, 3 })
            nGlaiveTempestDmg = nGlaiveTempestValues[1]
            nGlaiveTempestSoftCap = nGlaiveTempestValues[2]
        end
    end)
end
frameGlaiveTempest:RegisterEvent("ADDON_LOADED")
frameGlaiveTempest:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.GlaiveTempest.isPassive and wan.spellData.GlaiveTempest.known and wan.spellData.GlaiveTempest.id
        wan.BlizzardEventHandler(frameGlaiveTempest, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameGlaiveTempest, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameGlaiveTempest, CheckAbilityValue, abilityActive)
    end
end)