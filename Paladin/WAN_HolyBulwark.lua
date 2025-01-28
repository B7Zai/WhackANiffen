local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nHolyBulwark = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.HolyBulwark.id)
    then
        wan.UpdateMechanicData(wan.spellData.HolyBulwark.basename)
        wan.UpdateSupportData(nil, wan.spellData.HolyBulwark.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] and (not wan.auraData[groupUnitToken].buff_SacredWeapon and not wan.auraData[groupUnitToken].buff_HolyBulwark) then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cHolyBulwark = wan.UnitDefensiveCooldownToValue(wan.spellData.HolyBulwark.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cHolyBulwark, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.HolyBulwark.basename, abilityValue, wan.spellData.HolyBulwark.icon, wan.spellData.HolyBulwark.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.HolyBulwark.basename)
            end
        end
    else
        if (not wan.auraData.player.buff_SacredWeapon and not wan.auraData.player.buff_HolyBulwark) then
            local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
            local cHolyBulwark = nHolyBulwark

            local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cHolyBulwark, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.HolyBulwark.basename, abilityValue, wan.spellData.HolyBulwark.icon, wan.spellData.HolyBulwark.name)
        else
            wan.UpdateMechanicData(wan.spellData.SacredWeapon.basename)
        end
    end
end

-- Init frame 
local frameHolyBulwark = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nHolyBulwark = wan.DefensiveCooldownToValue(wan.spellData.HolyBulwark.id)
        end
    end)
end
frameHolyBulwark:RegisterEvent("ADDON_LOADED")
frameHolyBulwark:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HolyBulwark.known and wan.spellData.HolyBulwark.id
        wan.BlizzardEventHandler(frameHolyBulwark, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHolyBulwark, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.HolyBulwark.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.HolyBulwark.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHolyBulwark, CheckAbilityValue, abilityActive)
    end
end)