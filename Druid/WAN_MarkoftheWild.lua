local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMarkOfTheWild = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nMarkOfTheWild = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.PlayerState.Combat
        or not wan.CheckClassBuff(wan.spellData.MarkoftheWild.basename)
             or not wan.IsSpellUsable(wan.spellData.MarkoftheWild.id)
        then
            wan.UpdateMechanicData(wan.spellData.MarkoftheWild.basename)
            return
        end

        -- Base value
        local cMarkoftheWild = nMarkOfTheWild

        -- Update ability data
        local abilityValue = cMarkoftheWild
        wan.UpdateMechanicData(wan.spellData.MarkoftheWild.basename, abilityValue, wan.spellData.MarkoftheWild.icon, wan.spellData.MarkoftheWild.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMarkOfTheWildValue = wan.GetSpellDescriptionNumbers(wan.spellData.MarkoftheWild.id, { 1 })
            nMarkOfTheWild = wan.AbilityPercentageToValue(nMarkOfTheWildValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.MarkoftheWild.known and wan.spellData.MarkoftheWild.id
            wan.BlizzardEventHandler(frameMarkOfTheWild, abilityActive, "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameMarkOfTheWild, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMarkOfTheWild, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMarkOfTheWild:RegisterEvent("ADDON_LOADED")
frameMarkOfTheWild:SetScript("OnEvent", AddonLoad)