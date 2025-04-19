local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local abilityActive = false
local currentSpecName = "Unknown"
local specName = "Feral"
local nCatForm, nCatFormMaxRange = 0, 20

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or specName ~= currentSpecName
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.CatForm.id)
    then
        wan.UpdateMechanicData(wan.spellData.CatForm.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit = wan.ValidUnitBoolCounter(nil, nCatFormMaxRange)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.CatForm.basename)
        return
    end

    -- Base value
    local cCatForm = nCatForm

    -- Update ability data
    local abilityValue = cCatForm
    wan.UpdateMechanicData(wan.spellData.CatForm.basename, abilityValue, wan.spellData.CatForm.icon, wan.spellData.CatForm.name)
end

-- Local frame and event handler
local frameCatForm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end
    
end
frameCatForm:RegisterEvent("ADDON_LOADED")
frameCatForm:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CatForm.known and wan.spellData.CatForm.id
        wan.BlizzardEventHandler(frameCatForm, abilityActive)
        wan.SetUpdateRate(frameCatForm, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nCatForm = wan.AbilityPercentageToValue(10)

        local _, traitInfoName = wan.GetTraitInfo()
        currentSpecName = traitInfoName
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCatForm, CheckAbilityValue, abilityActive)
    end
end)
