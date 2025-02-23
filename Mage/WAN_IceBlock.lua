local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nIceBlock = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player.debuff_Hypothermia
        or wan.auraData.player["buff_" .. wan.spellData.IceBlock.formattedName]
        or wan.auraData.player["buff_" .. wan.spellData.Invisibility.formattedName]
        or wan.auraData.player.buff_MassInvisibility
        or not wan.IsSpellUsable(wan.spellData.IceBlock.id)
    then
        wan.UpdateMechanicData(wan.spellData.IceBlock.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cIceBlock = nIceBlock

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cIceBlock, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.IceBlock.basename, abilityValue, wan.spellData.IceBlock.icon, wan.spellData.IceBlock.name)
end

-- Init frame 
local frameIceBlock = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nIceBlock = wan.DefensiveCooldownToValue(wan.spellData.IceBlock.id)
        end
    end)
end
frameIceBlock:RegisterEvent("ADDON_LOADED")
frameIceBlock:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.IceBlock.known and wan.spellData.IceBlock.id
        wan.BlizzardEventHandler(frameIceBlock, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIceBlock, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.IceBlock.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.IceBlock.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIceBlock, CheckAbilityValue, abilityActive)
    end
end)
