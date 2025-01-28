local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local abilityActive = false
local nExecutionSentence, nExecutionSentenceMaxRange = 0, 15

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player["buff_" .. wan.spellData.ExecutionSentence.basename]
     or not wan.IsSpellUsable(wan.spellData.ExecutionSentence.id)
    then
        wan.UpdateAbilityData(wan.spellData.ExecutionSentence.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nExecutionSentenceMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.ExecutionSentence.basename)
        return
    end

    -- Base value
    local cExecutionSentence = nExecutionSentence
    local cdPotency = wan.CheckOffensiveCooldownPotency(cExecutionSentence, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cExecutionSentence) or 0
    wan.UpdateAbilityData(wan.spellData.ExecutionSentence.basename, abilityValue, wan.spellData.ExecutionSentence.icon, wan.spellData.ExecutionSentence.name)
end

-- Init frame 
local frameExecutionSentence = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nExecutionSentence = wan.OffensiveCooldownToValue(wan.spellData.ExecutionSentence.id) * 2
        end
    end)
end
frameExecutionSentence:RegisterEvent("ADDON_LOADED")
frameExecutionSentence:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ExecutionSentence.known and wan.spellData.ExecutionSentence.id
        wan.SetUpdateRate(frameExecutionSentence, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameExecutionSentence, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameExecutionSentence, CheckAbilityValue, abilityActive)
    end
end)
