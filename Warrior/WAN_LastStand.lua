local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nLastStand = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.CheckUnitBuff(nil, wan.traitData.SecondWind.traitkey)
        or not wan.IsSpellUsable(wan.spellData.LastStand.id)
    then
        wan.UpdateMechanicData(wan.spellData.LastStand.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cLastStand = nLastStand

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cLastStand, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.LastStand.basename, abilityValue, wan.spellData.LastStand.icon, wan.spellData.LastStand.name)
end

-- Init frame 
local frameLastStand = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nLastStand = wan.DefensiveCooldownToValue(wan.spellData.LastStand.id)
        end
    end)
end
frameLastStand:RegisterEvent("ADDON_LOADED")
frameLastStand:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.LastStand.known and wan.spellData.LastStand.id
        wan.BlizzardEventHandler(frameLastStand, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameLastStand, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.LastStand.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.LastStand.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameLastStand, CheckAbilityValue, abilityActive)
    end
end)
