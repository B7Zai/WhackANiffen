local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBlur = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Blur.id)
    then
        wan.UpdateMechanicData(wan.spellData.Blur.basename)
        return
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cBlur = nBlur

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBlur, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.Blur.basename, abilityValue, wan.spellData.Blur.icon, wan.spellData.Blur.name)
end

-- Init frame 
local frameBlur = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBlur = wan.DefensiveCooldownToValue(wan.spellData.Blur.id)
        end
    end)
end
frameBlur:RegisterEvent("ADDON_LOADED")
frameBlur:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.Blur.isPassive and wan.spellData.Blur.known and wan.spellData.Blur.id
        wan.BlizzardEventHandler(frameBlur, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlur, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlur, CheckAbilityValue, abilityActive)
    end
end)
