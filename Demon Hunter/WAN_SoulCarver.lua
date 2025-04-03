local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nSoulCarver = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.SoulCarver.id)
    then
        wan.UpdateMechanicData(wan.spellData.SoulCarver.basename)
        return
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cSoulCarver = nSoulCarver

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSoulCarver, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.SoulCarver.basename, abilityValue, wan.spellData.SoulCarver.icon, wan.spellData.SoulCarver.name)
end

-- Init frame 
local frameSoulCarver = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSoulCarver = wan.DefensiveCooldownToValue(wan.spellData.SoulCarver.id)
        end
    end)
end
frameSoulCarver:RegisterEvent("ADDON_LOADED")
frameSoulCarver:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.SoulCarver.isPassive and wan.spellData.SoulCarver.known and wan.spellData.SoulCarver.id
        wan.BlizzardEventHandler(frameSoulCarver, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSoulCarver, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSoulCarver, CheckAbilityValue, abilityActive)
    end
end)
