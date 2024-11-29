local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameSoothe = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nSoothe = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.PlayerState.Combat
            or not wan.CheckPurgeBool(wan.auraData, wan.TargetUnitID)
            or not wan.IsSpellUsable(wan.spellData.Soothe.id)
        then
            wan.UpdateMechanicData(wan.spellData.Soothe.basename)
            return
        end
       
        -- Base values
        local cSoothe = nSoothe

        -- Update ability data
        local abilityValue = math.floor(cSoothe)
        wan.UpdateMechanicData(wan.spellData.Soothe.basename, abilityValue, wan.spellData.Soothe.icon, wan.spellData.Soothe.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local sootheValue = 10
            nSoothe = wan.AbilityPercentageToValue(sootheValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Soothe.known and wan.spellData.Soothe.id
            wan.BlizzardEventHandler(frameSoothe, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameSoothe, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameSoothe, CheckAbilityValue, abilityActive)
        end
    end)
end

frameSoothe:RegisterEvent("ADDON_LOADED")
frameSoothe:SetScript("OnEvent", AddonLoad)