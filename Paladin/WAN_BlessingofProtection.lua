local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBlessingofProtection, nBlessingofProtectionCooldownMS = 0, 300000

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BlessingofProtection.id)
    then
        wan.UpdateMechanicData(wan.spellData.BlessingofProtection.basename)
        wan.UpdateSupportData(nil, wan.spellData.BlessingofProtection.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken].debuff_Forbearance and wan.UnitState.Role[groupUnitToken] ~= "TANK" then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cBlessingofProtection = wan.UnitDefensiveCooldownToValue(wan.spellData.BlessingofProtection.id, groupUnitToken, nBlessingofProtectionCooldownMS)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cBlessingofProtection, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofProtection.basename, abilityValue, wan.spellData.BlessingofProtection.icon, wan.spellData.BlessingofProtection.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofProtection.basename)
            end
        end
    else
        if wan.UnitState.Role[playerUnitToken] == "TANK" or wan.auraData.player.debuff_Forbearance then
            wan.UpdateMechanicData(wan.spellData.BlessingofProtection.basename)
            return
        end

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cBlessingofProtection = nBlessingofProtection

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBlessingofProtection, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.BlessingofProtection.basename, abilityValue, wan.spellData.BlessingofProtection.icon, wan.spellData.BlessingofProtection.name)
    end
end

-- Init frame 
local frameBlessingofProtection = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBlessingofProtection = wan.DefensiveCooldownToValue(wan.spellData.BlessingofProtection.id, nBlessingofProtectionCooldownMS)
        end
    end)
end
frameBlessingofProtection:RegisterEvent("ADDON_LOADED")
frameBlessingofProtection:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlessingofProtection.known and wan.spellData.BlessingofProtection.id
        wan.BlizzardEventHandler(frameBlessingofProtection, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlessingofProtection, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BlessingofProtection.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BlessingofProtection.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlessingofProtection, CheckAbilityValue, abilityActive)
    end
end)
