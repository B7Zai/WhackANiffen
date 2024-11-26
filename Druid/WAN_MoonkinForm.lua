local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMoonkinForm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local currentSpecName = "Unknown"
    local specName = "Balance"
    local nMoonkinForm = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_MoonkinForm
            or specName ~= currentSpecName or not wan.IsSpellUsable(wan.spellData.MoonkinForm.id)
        then
            wan.UpdateMechanicData(wan.spellData.MoonkinForm.basename)
            return
        end

        -- Base value
        local cMoonkinForm = nMoonkinForm

        -- Update ability data
        local abilityValue = cMoonkinForm or 0
        wan.UpdateMechanicData(wan.spellData.MoonkinForm.basename, abilityValue, wan.spellData.MoonkinForm.icon, wan.spellData.MoonkinForm.name)
    end

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.MoonkinForm.known and wan.spellData.MoonkinForm.id
            wan.BlizzardEventHandler(frameMoonkinForm, abilityActive)
            wan.SetUpdateRate(frameMoonkinForm, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nMoonkinForm = wan.AbilityPercentageToValue(10)

            local _, traitInfoName = wan.GetTraitInfo()
            currentSpecName = traitInfoName
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMoonkinForm, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMoonkinForm:RegisterEvent("ADDON_LOADED")
frameMoonkinForm:SetScript("OnEvent", AddonLoad)