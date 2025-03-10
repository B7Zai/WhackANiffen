local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nVictoryRushHeal = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.VictoryRush.id)
    then
        wan.UpdateMechanicData(wan.spellData.VictoryRush.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.VictoryRush.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.VictoryRush.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cVictoryRushHeal = nVictoryRushHeal

    -- update healing data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cVictoryRushHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.VictoryRush.basename, abilityValue, wan.spellData.VictoryRush.icon, wan.spellData.VictoryRush.name)
end

-- Init frame 
local frameVictoryRush = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local VictoryRushValue = wan.GetSpellDescriptionNumbers(wan.spellData.VictoryRush.id, { 2 })
            nVictoryRushHeal = wan.AbilityPercentageToValue(VictoryRushValue)
        end
    end)
end
frameVictoryRush:RegisterEvent("ADDON_LOADED")
frameVictoryRush:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.VictoryRush.known and wan.spellData.VictoryRush.id
        wan.BlizzardEventHandler(frameVictoryRush, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameVictoryRush, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameVictoryRush, CheckAbilityValue, abilityActive)
    end
end)