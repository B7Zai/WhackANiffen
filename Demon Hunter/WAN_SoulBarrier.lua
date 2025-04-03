local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nSoulBarrier = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.SoulBarrier.id)
    then
        wan.UpdateMechanicData(wan.spellData.SoulBarrier.basename)
        return
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cSoulBarrier = nSoulBarrier

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSoulBarrier, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.SoulBarrier.basename, abilityValue, wan.spellData.SoulBarrier.icon, wan.spellData.SoulBarrier.name)
end

-- Init frame 
local frameSoulBarrier = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSoulBarrier = wan.DefensiveCooldownToValue(wan.spellData.SoulBarrier.id)
        end
    end)
end
frameSoulBarrier:RegisterEvent("ADDON_LOADED")
frameSoulBarrier:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.SoulBarrier.isPassive and wan.spellData.SoulBarrier.known and wan.spellData.SoulBarrier.id
        wan.BlizzardEventHandler(frameSoulBarrier, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSoulBarrier, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSoulBarrier, CheckAbilityValue, abilityActive)
    end
end)
