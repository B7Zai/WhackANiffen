local _, wan = ...

local frameSurvivalInstincts = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nSurvivalInstincts = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.PlayerState.Combat
            or wan.auraData.player.buff_SurvivalInstincts or wan.HealThreshold() <= nSurvivalInstincts
            or not wan.IsSpellUsable(wan.spellData.SurvivalInstincts.id)
        then
            wan.UpdateMechanicData(wan.spellData.SurvivalInstincts.basename)
            return
        end

        -- Base values
        local cSurvivalInstincts = nSurvivalInstincts

        -- Update ability data
        local abilityValue = math.floor(cSurvivalInstincts)
        wan.UpdateMechanicData(wan.spellData.SurvivalInstincts.basename, abilityValue, wan.spellData.SurvivalInstincts.icon, wan.spellData.SurvivalInstincts.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local survivalInstinctsValue = wan.GetSpellDescriptionNumbers(wan.spellData.SurvivalInstincts.id, { 1 })
            nSurvivalInstincts = wan.AbilityPercentageToValue(survivalInstinctsValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.SurvivalInstincts.known and wan.spellData.SurvivalInstincts.id
            wan.BlizzardEventHandler(frameSurvivalInstincts, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameSurvivalInstincts, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameSurvivalInstincts, CheckAbilityValue, abilityActive)
        end
    end)
end

frameSurvivalInstincts:RegisterEvent("ADDON_LOADED")
frameSurvivalInstincts:SetScript("OnEvent", OnEvent)