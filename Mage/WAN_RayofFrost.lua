local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local abilityActive = false
local nRayofFrost = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.RayofFrost.id)
    then
        wan.UpdateAbilityData(wan.spellData.RayofFrost.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.RayofFrost.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.RayofFrost.basename)
        return
    end

    -- Base value
    local cRayofFrost = nRayofFrost
    local cdPotency = wan.CheckOffensiveCooldownPotency(cRayofFrost, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cRayofFrost) or 0
    wan.UpdateAbilityData(wan.spellData.RayofFrost.basename, abilityValue, wan.spellData.RayofFrost.icon, wan.spellData.RayofFrost.name)
end

-- Init frame 
local frameRayofFrost = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRayofFrost = wan.OffensiveCooldownToValue(wan.spellData.RayofFrost.id)
        end
    end)
end
frameRayofFrost:RegisterEvent("ADDON_LOADED")
frameRayofFrost:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RayofFrost.known and wan.spellData.RayofFrost.id
        wan.SetUpdateRate(frameRayofFrost, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameRayofFrost, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRayofFrost, CheckAbilityValue, abilityActive)
    end
end)
