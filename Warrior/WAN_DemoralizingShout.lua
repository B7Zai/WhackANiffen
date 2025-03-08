local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDemoralizingShout, nDemoralizingShoutMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.CheckUnitBuff(nil, wan.spellData.ShieldWall.formattedName)
        or not wan.IsSpellUsable(wan.spellData.DemoralizingShout.id)
    then
        wan.UpdateMechanicData(wan.spellData.DemoralizingShout.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit= wan.ValidUnitBoolCounter(nil, nDemoralizingShoutMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.DemoralizingShout.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cDemoralizingShout = nDemoralizingShout

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cDemoralizingShout, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.DemoralizingShout.basename, abilityValue, wan.spellData.DemoralizingShout.icon, wan.spellData.DemoralizingShout.name)
end

-- Init frame 
local frameDemoralizingShout = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nDemoralizingShoutValue = wan.GetSpellDescriptionNumbers(wan.spellData.DemoralizingShout.id, { 1, 2 })
            nDemoralizingShoutMaxRange = nDemoralizingShoutValue[1]
            nDemoralizingShout = wan.AbilityPercentageToValue(nDemoralizingShoutValue[2])
        end
    end)
end
frameDemoralizingShout:RegisterEvent("ADDON_LOADED")
frameDemoralizingShout:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DemoralizingShout.known and wan.spellData.DemoralizingShout.id
        wan.BlizzardEventHandler(frameDemoralizingShout, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameDemoralizingShout, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDemoralizingShout, CheckAbilityValue, abilityActive)
    end
end)