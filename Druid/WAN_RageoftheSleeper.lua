local _, wan = ...

local frameRageOfTheSleeper = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local nRageOfTheSleeperDR, nRageOfTheSleeperHeal = 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
        or not wan.PlayerState.Combat or wan.auraData.player.buff_RageoftheSleeper 
        or wan.HealThreshold() <= nRageOfTheSleeperHeal or not wan.IsSpellUsable(wan.spellData.RageoftheSleeper.id)
        then
            wan.UpdateMechanicData(wan.spellData.RageoftheSleeper.basename)
            return
        end

        -- Base value
        local cRageOfTheSleeperHeal = nRageOfTheSleeperHeal

        -- Update ability data
        local healValue = math.floor(cRageOfTheSleeperHeal)

        wan.UpdateMechanicData(wan.spellData.RageoftheSleeper.basename, healValue, wan.spellData.RageoftheSleeper.icon, wan.spellData.RageoftheSleeper.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRageOfTheSleeperDR = wan.GetSpellDescriptionNumbers(wan.spellData.RageoftheSleeper.id, { 1 })
            nRageOfTheSleeperHeal = wan.AbilityPercentageToValue(nRageOfTheSleeperDR)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.RageoftheSleeper.known and wan.spellData.RageoftheSleeper.id
            wan.BlizzardEventHandler(frameRageOfTheSleeper, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRageOfTheSleeper, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRageOfTheSleeper, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRageOfTheSleeper:RegisterEvent("ADDON_LOADED")
frameRageOfTheSleeper:SetScript("OnEvent", OnEvent)