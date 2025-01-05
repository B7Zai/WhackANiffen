local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRageOfTheSleeper = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
        or not wan.PlayerState.Combat or wan.auraData.player.buff_RageoftheSleeper
        or not wan.IsSpellUsable(wan.spellData.RageoftheSleeper.id)
    then
        wan.UpdateMechanicData(wan.spellData.RageoftheSleeper.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cRageOfTheSleeperHeal = nRageOfTheSleeper

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cRageOfTheSleeperHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.RageoftheSleeper.basename, abilityValue, wan.spellData.RageoftheSleeper.icon, wan.spellData.RageoftheSleeper.name)
end

local frameRageOfTheSleeper = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRageOfTheSleeper = wan.DefensiveCooldownToValue(wan.spellData.RageoftheSleeper.id)
        end
    end)
end
frameRageOfTheSleeper:RegisterEvent("ADDON_LOADED")
frameRageOfTheSleeper:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RageoftheSleeper.known and wan.spellData.RageoftheSleeper.id
        wan.BlizzardEventHandler(frameRageOfTheSleeper, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRageOfTheSleeper, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRageOfTheSleeper, CheckAbilityValue, abilityActive)
    end
end)
