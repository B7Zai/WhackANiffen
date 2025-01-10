local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local petUnitToken = "pet"
local nRevivePet = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not UnitExists("pet")
        or not UnitIsDead(petUnitToken) or not wan.IsSpellUsable(wan.spellData.RevivePet.id)
    then
        wan.UpdateMechanicData(wan.spellData.RevivePet.basename)
        return
    end

    -- Base value
    local cRevivePet = nRevivePet

    -- Update ability data
    local abilityValue = cRevivePet
    wan.UpdateMechanicData(wan.spellData.RevivePet.basename, abilityValue, wan.spellData.RevivePet.icon, wan.spellData.RevivePet.name)
end

-- Local frame and event handler
local frameRevivePet = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end
end
frameRevivePet:RegisterEvent("ADDON_LOADED")
frameRevivePet:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RevivePet.known and wan.spellData.RevivePet.id
        wan.BlizzardEventHandler(frameRevivePet, abilityActive, "UI_ERROR_MESSAGE")
        wan.SetUpdateRate(frameRevivePet, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nRevivePet = wan.AbilityPercentageToValue(20)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRevivePet, CheckAbilityValue, abilityActive)
    end
end)
