local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nProwl, nProwlMaxRange = 0, 60

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
        or not wan.IsSpellUsable(wan.spellData.Prowl.id)
    then
        wan.UpdateMechanicData(wan.spellData.Prowl.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit = wan.ValidUnitBoolCounter(nil, nProwlMaxRange)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.Prowl.basename)
        return
    end

    -- Base value
    local cProwl = nProwl

    -- Update ability data
    local abilityValue = cProwl
    wan.UpdateMechanicData(wan.spellData.Prowl.basename, abilityValue, wan.spellData.Prowl.icon, wan.spellData.Prowl.name)
end

-- Init frame 
local frameProwl = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

end
frameProwl:RegisterEvent("ADDON_LOADED")
frameProwl:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Prowl.known and wan.spellData.Prowl.id
        wan.BlizzardEventHandler(frameProwl, abilityActive)
        wan.SetUpdateRate(frameProwl, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nProwl = wan.AbilityPercentageToValue(5)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameProwl, CheckAbilityValue, abilityActive)
    end
end)
