local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nImplosiveTrapDmg = 0

-- Init trait data
local nPenetratingShots = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ImplosiveTrap.id)
    then
        wan.UpdateAbilityData(wan.spellData.ImplosiveTrap.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.ImplosiveTrap.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ImplosiveTrap.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cImplosiveTrapInstantDmg = 0
    local cImplosiveTrapDotDmg = 0
    local cImplosiveTrapInstantDmgAoE = 0
    local cImplosiveTrapDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cImplosiveTrapCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cImplosiveTrapInstantDmg = cImplosiveTrapInstantDmg
    cImplosiveTrapDotDmg = cImplosiveTrapDotDmg
    cImplosiveTrapInstantDmgAoE = cImplosiveTrapInstantDmgAoE + (nImplosiveTrapDmg * countValidUnit * cImplosiveTrapCritValue)
    cImplosiveTrapDotDmgAoE = cImplosiveTrapDotDmgAoE

    local cImplosiveTrapDmg = cImplosiveTrapInstantDmg + cImplosiveTrapDotDmg + cImplosiveTrapInstantDmgAoE + cImplosiveTrapDotDmgAoE

    local abilityValue = math.floor(cImplosiveTrapDmg)
    wan.UpdateAbilityData(wan.spellData.ImplosiveTrap.basename, abilityValue, wan.spellData.ImplosiveTrap.icon, wan.spellData.ImplosiveTrap.name)
end

-- Init frame 
local frameImplosiveTrap = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nImplosiveTrapDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ImplosiveTrap.id, { 1 })
        end
    end)
end
frameImplosiveTrap:RegisterEvent("ADDON_LOADED")
frameImplosiveTrap:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ImplosiveTrap.known and wan.spellData.ImplosiveTrap.id
        wan.BlizzardEventHandler(frameImplosiveTrap, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameImplosiveTrap, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameImplosiveTrap, CheckAbilityValue, abilityActive)
    end
end)