local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nFinalReckoningDmg, nFinalReckoningMaxRange = 0, 15

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FinalReckoning.id)
    then
        wan.UpdateAbilityData(wan.spellData.FinalReckoning.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, nFinalReckoningMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FinalReckoning.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cFinalReckoningInstantDmg = 0
    local cFinalReckoningDotDmg = 0
    local cFinalReckoningInstantDmgAoE = 0
    local cFinalReckoningDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- Crit layer
    local cFinalReckoningCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFinalReckoningInstantDmg = cFinalReckoningInstantDmg

    cFinalReckoningDotDmg = cFinalReckoningDotDmg

    cFinalReckoningInstantDmgAoE = cFinalReckoningInstantDmgAoE
        + (nFinalReckoningDmg * countValidUnit * cFinalReckoningCritValue)

    cFinalReckoningDotDmgAoE = cFinalReckoningDotDmgAoE

    local cFinalReckoningDmg = cFinalReckoningInstantDmg + cFinalReckoningDotDmg + cFinalReckoningInstantDmgAoE + cFinalReckoningDotDmgAoE
    local cdPotency = wan.CheckOffensiveCooldownPotency(cFinalReckoningDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFinalReckoningDmg) or 0
    wan.UpdateAbilityData(wan.spellData.FinalReckoning.basename, abilityValue, wan.spellData.FinalReckoning.icon, wan.spellData.FinalReckoning.name)
end

-- Init frame 
local frameFinalReckoning = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFinalReckoningDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FinalReckoning.id, { 1 })
        end
    end)
end
frameFinalReckoning:RegisterEvent("ADDON_LOADED")
frameFinalReckoning:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FinalReckoning.known and wan.spellData.FinalReckoning.id
        wan.BlizzardEventHandler(frameFinalReckoning, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFinalReckoning, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFinalReckoning, CheckAbilityValue, abilityActive)
    end
end)