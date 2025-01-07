local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nArcaneShotDmg = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
    or (wan.spellData.MultiShot.known and not wan.IsSpellUsable(wan.spellData.MultiShot.id) or not wan.IsSpellUsable(wan.spellData.ArcaneShot.id))
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cArcaneShotInstantDmg = nArcaneShotDmg
    local cArcaneShotDotDmg = 0

    local targetUnitToken = wan.TargetUnitID

    -- Remove physical layer
    local checkPhysicalDR = 1
    if wan.traitData.CobraShot.known then
        checkPhysicalDR = checkPhysicalDR * wan.CheckUnitPhysicalDamageReduction()
    end

    -- Crit layer
    local cArcaneShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneShotInstantDmg = cArcaneShotInstantDmg * checkPhysicalDR * cArcaneShotCritValue
    cArcaneShotDotDmg = cArcaneShotDotDmg * cArcaneShotCritValue

    local cArcaneShotDmg = cArcaneShotInstantDmg + cArcaneShotDotDmg

    -- Update ability data
    local abilityValue = math.floor(cArcaneShotDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename, abilityValue, wan.spellData.ArcaneShot.icon, wan.spellData.ArcaneShot.name)
end

-- Init frame 
local frameArcaneShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneShot.id, { 1 })
        end
    end)
end
frameArcaneShot:RegisterEvent("ADDON_LOADED")
frameArcaneShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneShot.known and wan.spellData.ArcaneShot.id
        wan.BlizzardEventHandler(frameArcaneShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end
end)