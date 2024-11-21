local _, wan = ...

local frameRenewal = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nRenewalHeal = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_FrenziedRegeneration
        or wan.HealThreshold() <= nRenewalHeal or not wan.IsSpellUsable(wan.spellData.Renewal.id)
        then
            wan.UpdateMechanicData(wan.spellData.Renewal.basename)
            return
        end

        -- Base values
        local cRenewalHeal = nRenewalHeal

        -- Update ability data
        local healValue = math.floor(cRenewalHeal)
        wan.UpdateMechanicData(wan.spellData.Renewal.basename, healValue, wan.spellData.Renewal.icon, wan.spellData.Renewal.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local renewalValue = wan.GetSpellDescriptionNumbers(wan.spellData.Renewal.id, { 1 })
            nRenewalHeal = wan.AbilityPercentageToValue(renewalValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Renewal.known and wan.spellData.Renewal.id
            wan.BlizzardEventHandler(frameRenewal, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameRenewal, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRenewal, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRenewal:RegisterEvent("ADDON_LOADED")
frameRenewal:SetScript("OnEvent", OnEvent)