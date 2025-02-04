local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local abilityActive = false
local nArcaneSurge, nArcaneSurgeMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.aurahalData.player["buff_" .. wan.spellData.ArcaneSurge.basename]
        or not wan.IsSpellUsable(wan.spellData.ArcaneSurge.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneSurge.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.ArcaneSurge.maxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.ArcaneSurge.basename)
        return
    end

    -- Base value
    local cArcaneSurge = nArcaneSurge
    local cdPotency = wan.CheckOffensiveCooldownPotency(cArcaneSurge, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cArcaneSurge) or 0
    wan.UpdateAbilityData(wan.spellData.ArcaneSurge.basename, abilityValue, wan.spellData.ArcaneSurge.icon, wan.spellData.ArcaneSurge.name)
end

-- Init frame 
local frameArcaneSurge = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneSurge = wan.OffensiveCooldownToValue(wan.spellData.ArcaneSurge.id)
            nArcaneSurgeMaxRange = wan.spellData.ArcaneSurge.maxRange > 0 and wan.spellData.ArcaneSurge.maxRange or 40
        end
    end)
end
frameArcaneSurge:RegisterEvent("ADDON_LOADED")
frameArcaneSurge:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneSurge.known and wan.spellData.ArcaneSurge.id
        wan.SetUpdateRate(frameArcaneSurge, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameArcaneSurge, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneSurge, CheckAbilityValue, abilityActive)
    end
end)
