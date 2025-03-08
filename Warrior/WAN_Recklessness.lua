local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local abilityActive = false
local nRecklessness, nRecklessnessMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Recklessness.id)
    then
        wan.UpdateAbilityData(wan.spellData.Recklessness.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nRecklessnessMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Recklessness.basename)
        return
    end

    -- Base value
    local cRecklessness = nRecklessness
    local cdPotency = wan.CheckOffensiveCooldownPotency(cRecklessness, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cRecklessness) or 0
    wan.UpdateAbilityData(wan.spellData.Recklessness.basename, abilityValue, wan.spellData.Recklessness.icon, wan.spellData.Recklessness.name)
end

-- Init frame 
local frameRecklessness = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRecklessness = wan.OffensiveCooldownToValue(wan.spellData.Recklessness.id)
            nRecklessnessMaxRange = wan.spellData.Recklessness.maxRange > 0 and wan.spellData.Recklessness.maxRange or 15
        end
    end)
end
frameRecklessness:RegisterEvent("ADDON_LOADED")
frameRecklessness:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Recklessness.known and wan.spellData.Recklessness.id
        wan.SetUpdateRate(frameRecklessness, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameRecklessness, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRecklessness, CheckAbilityValue, abilityActive)
    end
end)
