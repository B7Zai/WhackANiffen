local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBlessingofSpellwarding, nBlessingofSpellwardingCooldownMS = 0, 300000

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BlessingofSpellwarding.id)
    then
        wan.UpdateMechanicData(wan.spellData.BlessingofSpellwarding.basename)
        wan.UpdateSupportData(nil, wan.spellData.BlessingofSpellwarding.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken].debuff_Forbearance
                and wan.UnitState.Role[groupUnitToken] ~= "TANK" and not wan.IsUnitTanking(groupUnitToken)
            then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cBlessingofSpellwarding = wan.UnitDefensiveCooldownToValue(wan.spellData.BlessingofSpellwarding.id, groupUnitToken, nBlessingofSpellwardingCooldownMS)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cBlessingofSpellwarding, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofSpellwarding.basename, abilityValue, wan.spellData.BlessingofSpellwarding.icon, wan.spellData.BlessingofSpellwarding.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.BlessingofSpellwarding.basename)
            end
        end
    else
        if (wan.PlayerState.InGroup and wan.PlayerState.Role == "TANK") or wan.auraData.player.debuff_Forbearance
            or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
            or wan.auraData.player["buff_" .. wan.spellData.BlessingofSpellwarding.basename]
            or wan.auraData.player["buff_" .. wan.spellData.GuardianofAncientKings.basename]
            then
            wan.UpdateMechanicData(wan.spellData.BlessingofSpellwarding.basename)
            return
        end

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cBlessingofSpellwarding = nBlessingofSpellwarding

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBlessingofSpellwarding, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.BlessingofSpellwarding.basename, abilityValue, wan.spellData.BlessingofSpellwarding.icon, wan.spellData.BlessingofSpellwarding.name)
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
            nBlessingofSpellwarding = wan.DefensiveCooldownToValue(wan.spellData.BlessingofSpellwarding.id, nBlessingofSpellwardingCooldownMS)
        end
    end)
end
frameBlessingofProtection:RegisterEvent("ADDON_LOADED")
frameBlessingofProtection:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlessingofSpellwarding.known and wan.spellData.BlessingofSpellwarding.id
        wan.BlizzardEventHandler(frameBlessingofProtection, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlessingofProtection, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.BlessingofSpellwarding.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.BlessingofSpellwarding.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlessingofProtection, CheckAbilityValue, abilityActive)
    end
end)
