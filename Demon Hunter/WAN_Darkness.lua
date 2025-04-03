local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nDarkness = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.CheckUnitBuff(nil, wan.spellData.Darkness.formattedName)
        or not wan.IsSpellUsable(wan.spellData.Darkness.id)
    then
        wan.UpdateMechanicData(wan.spellData.Darkness.basename)
        return
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cDarkness = nDarkness

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cDarkness, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.Darkness.basename, abilityValue, wan.spellData.Darkness.icon, wan.spellData.Darkness.name)
end

-- Init frame 
local frameDarkness = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDarkness = wan.DefensiveCooldownToValue(wan.spellData.Darkness.id)
        end
    end)
end
frameDarkness:RegisterEvent("ADDON_LOADED")
frameDarkness:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Darkness.known and wan.spellData.Darkness.id
        wan.BlizzardEventHandler(frameDarkness, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDarkness, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Darkness.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.Darkness.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDarkness, CheckAbilityValue, abilityActive)
    end
end)
