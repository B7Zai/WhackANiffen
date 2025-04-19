local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nHighExplosiveTrapDmg = 0

-- init trait data
local nPenetratingShots = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.HighExplosiveTrap.id)
    then
        wan.UpdateAbilityData(wan.spellData.HighExplosiveTrap.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.HighExplosiveTrap.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.HighExplosiveTrap.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cHighExplosiveTrapInstantDmg = 0
    local cHighExplosiveTrapDotDmg = 0
    local cHighExplosiveTrapInstantDmgAoE = 0
    local cHighExplosiveTrapDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cHighExplosiveTrapCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cHighExplosiveTrapInstantDmg = cHighExplosiveTrapInstantDmg
    cHighExplosiveTrapDotDmg = cHighExplosiveTrapDotDmg
    cHighExplosiveTrapInstantDmgAoE = cHighExplosiveTrapInstantDmgAoE + (nHighExplosiveTrapDmg * countValidUnit * cHighExplosiveTrapCritValue)
    cHighExplosiveTrapDotDmgAoE = cHighExplosiveTrapDotDmgAoE

    local cHighExplosiveTrapDmg = cHighExplosiveTrapInstantDmg + cHighExplosiveTrapDotDmg + cHighExplosiveTrapInstantDmgAoE + cHighExplosiveTrapDotDmgAoE

    local abilityValue = math.floor(cHighExplosiveTrapDmg)
    wan.UpdateAbilityData(wan.spellData.HighExplosiveTrap.basename, abilityValue, wan.spellData.HighExplosiveTrap.icon, wan.spellData.HighExplosiveTrap.name)
end

-- Init frame 
local frameHighExplosiveTrap = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nHighExplosiveTrapDmg = wan.GetSpellDescriptionNumbers(wan.spellData.HighExplosiveTrap.id, { 1 })
        end
    end)
end
frameHighExplosiveTrap:RegisterEvent("ADDON_LOADED")
frameHighExplosiveTrap:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HighExplosiveTrap.known and wan.spellData.HighExplosiveTrap.id
        wan.BlizzardEventHandler(frameHighExplosiveTrap, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHighExplosiveTrap, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHighExplosiveTrap, CheckAbilityValue, abilityActive)
    end
end)