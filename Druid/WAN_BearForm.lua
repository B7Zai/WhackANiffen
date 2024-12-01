local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameBearForm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local currentSpecName = "Unknown"
    local specName = "Guardian"
    local nBearForm, nBearFormMaxRange = 0, 20

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_BearForm
            or specName ~= currentSpecName or not wan.IsSpellUsable(wan.spellData.BearForm.id)
        then
            wan.UpdateMechanicData(wan.spellData.BearForm.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit = wan.ValidUnitBoolCounter(nil, nBearFormMaxRange)
        if countValidUnit == 0 then
            wan.UpdateMechanicData(wan.spellData.BearForm.basename)
            return
        end

        -- Base value
        local cBearForm = nBearForm

        -- Update ability data
        local abilityValue = cBearForm
        wan.UpdateMechanicData(wan.spellData.BearForm.basename, abilityValue, wan.spellData.BearForm.icon, wan.spellData.BearForm.name)
    end

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.BearForm.known and wan.spellData.BearForm.id
            wan.BlizzardEventHandler(frameBearForm, abilityActive)
            wan.SetUpdateRate(frameBearForm, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nBearForm = wan.AbilityPercentageToValue(10)

            local _, traitInfoName = wan.GetTraitInfo()
            currentSpecName = traitInfoName
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameBearForm, CheckAbilityValue, abilityActive)
        end
    end)
end

frameBearForm:RegisterEvent("ADDON_LOADED")
frameBearForm:SetScript("OnEvent", AddonLoad)