local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameBarkskin = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nBarkskin = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.PlayerState.Combat
            or wan.auraData.player.buff_Barkskin or wan.HealThreshold() <= nBarkskin
            or not wan.IsSpellUsable(wan.spellData.Barkskin.id)
        then
            wan.UpdateMechanicData(wan.spellData.Barkskin.basename)
            return
        end

        -- Base values
        local cBarkskin = nBarkskin

        -- Update ability data
        local abilityValue = math.floor(cBarkskin)
        wan.UpdateMechanicData(wan.spellData.Barkskin.basename, abilityValue, wan.spellData.Barkskin.icon, wan.spellData.Barkskin.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local barkskinValue = wan.GetSpellDescriptionNumbers(wan.spellData.Barkskin.id, { 1 })
            nBarkskin = wan.AbilityPercentageToValue(barkskinValue)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Barkskin.known and wan.spellData.Barkskin.id
            wan.BlizzardEventHandler(frameBarkskin, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameBarkskin, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameBarkskin, CheckAbilityValue, abilityActive)
        end
    end)
end

frameBarkskin:RegisterEvent("ADDON_LOADED")
frameBarkskin:SetScript("OnEvent", AddonLoad)