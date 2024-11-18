local _, wan = ...

local frameBerserk = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local abilityAura = "Berserk"
    local maxRange = 12
    local nBerserk = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        if not wan.PlayerState.Status or wan.auraData.player["buff_" .. abilityAura]
        or wan.auraData.player.buff_Prowl or not wan.IsSpellUsable(wan.spellData.Berserk.id) 
        then wan.UpdateMechanicData(wan.spellData.Berserk.basename) return end -- Early exits

        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, maxRange)
        local cBerserk = nBerserk -- Base values

        if not wan.CheckOffensiveCooldownPotency(cBerserk, isValidUnit, idValidUnit)
        then wan.UpdateMechanicData(wan.spellData.Berserk.basename) return end

        local abilityValue = math.floor(cBerserk) -- Update AbilityData
        if abilityValue == 0 then wan.UpdateMechanicData(wan.spellData.Berserk.basename) return end
        wan.UpdateMechanicData(wan.spellData.Berserk.basename, abilityValue, wan.spellData.Berserk.icon, wan.spellData.Berserk.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nBerserk = wan.OffensiveCooldownToValue(wan.spellData.Berserk.id)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Berserk.known and wan.spellData.Berserk.id
            abilityAura = wan.FormatNameForKey(wan.spellData.Berserk.name)
            wan.BlizzardEventHandler(frameBerserk, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameBerserk, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameBerserk, CheckAbilityValue, abilityActive)
        end
    end)
end

frameBerserk:RegisterEvent("ADDON_LOADED")
frameBerserk:SetScript("OnEvent", OnEvent)