local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameRemoveCorruption = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRemoveCorruption = 0
    local dispelType = { Curse = true, Poison = true}

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.CheckDispelBool(wan.auraData, "player", dispelType)
            or not wan.IsSpellUsable(wan.spellData.RemoveCorruption.id)
        then
            wan.UpdateMechanicData(wan.spellData.RemoveCorruption.basename)
            return
        end

        -- Base values
        local cRemoveCorruption = nRemoveCorruption

        -- Update ability data
        local abilityValue = math.floor(cRemoveCorruption)
        wan.UpdateMechanicData(wan.spellData.RemoveCorruption.basename, abilityValue, wan.spellData.RemoveCorruption.icon, wan.spellData.RemoveCorruption.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local removeCorruptionValue = 25
            nRemoveCorruption = wan.AbilityPercentageToValue(removeCorruptionValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.RemoveCorruption.known and wan.spellData.RemoveCorruption.id
            wan.BlizzardEventHandler(frameRemoveCorruption, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameRemoveCorruption, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRemoveCorruption, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRemoveCorruption:RegisterEvent("ADDON_LOADED")
frameRemoveCorruption:SetScript("OnEvent", AddonLoad)