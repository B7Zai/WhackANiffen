local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nShiftingPowerDmg, nShiftingPowerMaxRange, nShiftingPowerCastTime = 0, 0, 0

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ShiftingPower.id)
    then
        wan.UpdateAbilityData(wan.spellData.ShiftingPower.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nShiftingPowerMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ShiftingPower.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.ShiftingPower.id, nShiftingPowerCastTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.ShiftingPower.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cShiftingPowerInstantDmg = nShiftingPowerDmg
    local cShiftingPowerDotDmg = 0
    local cShiftingPowerInstantDmgAoE = 0
    local cShiftingPowerDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cShiftingPowerBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cShiftingPowerBaseDmgAoE = cShiftingPowerBaseDmgAoE + (nShiftingPowerDmg * unitAoEPotency)
    end

    ---- TRAITS ----

    local cShiftingPowerCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cShiftingPowerInstantDmg = cShiftingPowerInstantDmg

    cShiftingPowerDotDmg = cShiftingPowerDotDmg

    cShiftingPowerInstantDmgAoE = cShiftingPowerInstantDmgAoE
        + (cShiftingPowerBaseDmgAoE * cShiftingPowerCritValue)

    cShiftingPowerDotDmgAoE = cShiftingPowerDotDmgAoE
    
    local cShiftingPowerDmg = (cShiftingPowerInstantDmg + cShiftingPowerDotDmg + cShiftingPowerInstantDmgAoE + cShiftingPowerDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cShiftingPowerDmg)
    wan.UpdateAbilityData(wan.spellData.ShiftingPower.basename, abilityValue, wan.spellData.ShiftingPower.icon, wan.spellData.ShiftingPower.name)
end

-- Init frame 
local frameShiftingPower = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nShiftingPowerValues = wan.GetSpellDescriptionNumbers(wan.spellData.ShiftingPower.id, { 1, 2, 3 })
            nShiftingPowerDmg = nShiftingPowerValues[1]
            nShiftingPowerCastTime = nShiftingPowerValues[2] * 1000
            nShiftingPowerMaxRange = nShiftingPowerValues[3]
        end
    end)
end
frameShiftingPower:RegisterEvent("ADDON_LOADED")
frameShiftingPower:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShiftingPower.known and wan.spellData.ShiftingPower.id
        wan.BlizzardEventHandler(frameShiftingPower, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameShiftingPower, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShiftingPower, CheckAbilityValue, abilityActive)
    end
end)