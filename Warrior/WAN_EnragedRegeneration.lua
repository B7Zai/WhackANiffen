local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nEnragedRegeneration = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.EnragedRegeneration.id)
    then
        wan.UpdateMechanicData(wan.spellData.EnragedRegeneration.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cEnragedRegeneration = nEnragedRegeneration

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cEnragedRegeneration, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.EnragedRegeneration.basename, abilityValue, wan.spellData.EnragedRegeneration.icon, wan.spellData.EnragedRegeneration.name)
end

-- Init frame 
local frameEnragedRegeneration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nEnragedRegeneration = wan.DefensiveCooldownToValue(wan.spellData.EnragedRegeneration.id)
        end
    end)
end
frameEnragedRegeneration:RegisterEvent("ADDON_LOADED")
frameEnragedRegeneration:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.EnragedRegeneration.known and wan.spellData.EnragedRegeneration.id
        wan.BlizzardEventHandler(frameEnragedRegeneration, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameEnragedRegeneration, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.EnragedRegeneration.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.EnragedRegeneration.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameEnragedRegeneration, CheckAbilityValue, abilityActive)
    end
end)
