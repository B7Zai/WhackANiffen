local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSacredWeapon = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.SacredWeapon.id)
    then
        wan.UpdateMechanicData(wan.spellData.SacredWeapon.basename)
        wan.UpdateSupportData(nil, wan.spellData.SacredWeapon.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] and (not wan.auraData[groupUnitToken].buff_SacredWeapon and not wan.auraData[groupUnitToken].buff_HolyBulwark) then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cSacredWeapon = wan.UnitDefensiveCooldownToValue(wan.spellData.SacredWeapon.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cSacredWeapon, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.SacredWeapon.basename, abilityValue, wan.spellData.SacredWeapon.icon, wan.spellData.SacredWeapon.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.SacredWeapon.basename)
            end
        end
    else
        if (not wan.auraData.player.buff_SacredWeapon and not wan.auraData.player.buff_HolyBulwark) then
            local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
            local cSacredWeapon = nSacredWeapon

            local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSacredWeapon, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.SacredWeapon.basename, abilityValue, wan.spellData.SacredWeapon.icon, wan.spellData.SacredWeapon.name)
        else
            wan.UpdateMechanicData(wan.spellData.SacredWeapon.basename)
        end
    end
end

-- Init frame 
local frameSacredWeapon = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSacredWeapon = wan.DefensiveCooldownToValue(wan.spellData.SacredWeapon.id)
        end
    end)
end
frameSacredWeapon:RegisterEvent("ADDON_LOADED")
frameSacredWeapon:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SacredWeapon.known and wan.spellData.SacredWeapon.id
        wan.BlizzardEventHandler(frameSacredWeapon, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSacredWeapon, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.SacredWeapon.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.SacredWeapon.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSacredWeapon, CheckAbilityValue, abilityActive)
    end
end)