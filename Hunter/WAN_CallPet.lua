local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local petUnitToken = "pet"
local nCallPet = 0
local callPetIconID = 132161
local callPetAbilityName = "Call Pet"

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or UnitExists("pet")
        or not wan.traitData.UnbreakableBond.known
        or (wan.PlayerState.Resting and not wan.PlayerState.Combat)
        or not wan.IsSpellUsable(wan.spellData.CallPet1.id)
    then
        wan.UpdateMechanicData(wan.spellData.CallPet1.basename)
        return
    end

    -- Base value
    local cCallPet = nCallPet

    -- Update ability data
    local abilityValue = cCallPet
    wan.UpdateMechanicData(wan.spellData.CallPet1.basename, abilityValue, callPetIconID, callPetAbilityName)
end

-- Local frame and event handler
local frameCallPet = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end
end
frameCallPet:RegisterEvent("ADDON_LOADED")
frameCallPet:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CallPet1.known and wan.spellData.CallPet1.id
        wan.BlizzardEventHandler(frameCallPet, abilityActive)
        wan.SetUpdateRate(frameCallPet, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nCallPet = wan.AbilityPercentageToValue(25)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCallPet, CheckAbilityValue, abilityActive)
    end
end)
