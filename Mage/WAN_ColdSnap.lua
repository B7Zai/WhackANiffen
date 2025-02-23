local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nColdSnap = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or (wan.IsSpellUsable(wan.spellData.IceBlock.id) and wan.IsSpellUsable(wan.spellData.IceBarrier.id))
        or not wan.IsSpellUsable(wan.spellData.ColdSnap.id)
    then
        wan.UpdateMechanicData(wan.spellData.ColdSnap.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cColdSnap = nColdSnap

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cColdSnap, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.ColdSnap.basename, abilityValue, wan.spellData.ColdSnap.icon, wan.spellData.ColdSnap.name)
end

-- Init frame 
local frameColdSnap = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nColdSnap = wan.DefensiveCooldownToValue(wan.spellData.ColdSnap.id)
        end
    end)
end
frameColdSnap:RegisterEvent("ADDON_LOADED")
frameColdSnap:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ColdSnap.known and wan.spellData.ColdSnap.id
        wan.BlizzardEventHandler(frameColdSnap, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameColdSnap, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.ColdSnap.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.ColdSnap.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameColdSnap, CheckAbilityValue, abilityActive)
    end
end)
