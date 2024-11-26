local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameForceOfNature = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nForceOfNature  = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.ForceofNature.id)
        then
            wan.UpdateMechanicData(wan.spellData.ForceofNature.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.ForceofNature.maxRange)
        if countValidUnit == 0 then
            wan.UpdateMechanicData(wan.spellData.ForceofNature.basename)
            return
        end

        -- Base value
        local cForceofNature = nForceOfNature
        local cdPotency = wan.CheckOffensiveCooldownPotency(cForceofNature, isValidUnit, idValidUnit)

        -- Update ability data
        local abilityValue = cdPotency and math.floor(cForceofNature) or 0
        wan.UpdateMechanicData(wan.spellData.ForceofNature.basename, abilityValue, wan.spellData.ForceofNature.icon, wan.spellData.ForceofNature.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nForceOfNature = wan.OffensiveCooldownToValue(wan.spellData.ForceofNature.id)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.ForceofNature.known and wan.spellData.ForceofNature.id
            wan.BlizzardEventHandler(frameForceOfNature, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameForceOfNature, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameForceOfNature, CheckAbilityValue, abilityActive)
        end
    end)
end

frameForceOfNature:RegisterEvent("ADDON_LOADED")
frameForceOfNature:SetScript("OnEvent", AddonLoad)