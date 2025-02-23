local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local abilityActive = false
local nCombustion, nCombustionMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Combustion.id)
    then
        wan.UpdateAbilityData(wan.spellData.Combustion.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nCombustionMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Combustion.basename)
        return
    end

    -- Base value
    local cCombustion = nCombustion
    local cdPotency = wan.CheckOffensiveCooldownPotency(cCombustion, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cCombustion) or 0
    wan.UpdateAbilityData(wan.spellData.Combustion.basename, abilityValue, wan.spellData.Combustion.icon, wan.spellData.Combustion.name)
end

-- Init frame 
local frameCombustion = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCombustion = wan.OffensiveCooldownToValue(wan.spellData.Combustion.id)
            nCombustionMaxRange = wan.spellData.Combustion.maxRange > 0 and wan.spellData.Combustion.maxRange or 40
        end
    end)
end
frameCombustion:RegisterEvent("ADDON_LOADED")
frameCombustion:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Combustion.known and wan.spellData.Combustion.id
        wan.SetUpdateRate(frameCombustion, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameCombustion, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCombustion, CheckAbilityValue, abilityActive)
    end
end)
