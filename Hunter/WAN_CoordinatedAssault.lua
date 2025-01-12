local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nCoordinatedAssault = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player["buff_" .. wan.spellData.CoordinatedAssault.basename]
     or not wan.IsSpellUsable(wan.spellData.CoordinatedAssault.id)
    then
        wan.UpdateAbilityData(wan.spellData.CoordinatedAssault.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.CoordinatedAssault.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.CoordinatedAssault.basename)
        return
    end

    -- Base value
    local cCoordinatedAssault = nCoordinatedAssault
    local cdPotency = wan.CheckOffensiveCooldownPotency(cCoordinatedAssault, isValidUnit, idValidUnit)


    -- Update ability data
    local abilityValue = cdPotency and math.floor(cCoordinatedAssault) or 0
    wan.UpdateAbilityData(wan.spellData.CoordinatedAssault.basename, abilityValue, wan.spellData.CoordinatedAssault.icon, wan.spellData.CoordinatedAssault.name)
end

-- Init frame 
local frameCoordinatedAssault = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCoordinatedAssault = wan.OffensiveCooldownToValue(wan.spellData.CoordinatedAssault.id)
        end
    end)
end
frameCoordinatedAssault:RegisterEvent("ADDON_LOADED")
frameCoordinatedAssault:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CoordinatedAssault.known and wan.spellData.CoordinatedAssault.id
        wan.SetUpdateRate(frameCoordinatedAssault, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameCoordinatedAssault, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCoordinatedAssault, CheckAbilityValue, abilityActive)
    end
end)
