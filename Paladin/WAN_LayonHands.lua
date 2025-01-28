local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nLayonHands = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.debuff_Forbearance
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.LayonHands.id)
    then
        wan.UpdateMechanicData(wan.spellData.LayonHands.basename)
        wan.UpdateSupportData(nil, wan.spellData.LayonHands.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken].debuff_Forbearance then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cLayonHands = wan.UnitDefensiveCooldownToValue(wan.spellData.LayonHands.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cLayonHands, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.LayonHands.basename, abilityValue, wan.spellData.LayonHands.icon, wan.spellData.LayonHands.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.LayonHands.basename)
            end
        end
    else

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cLayonHands = nLayonHands

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cLayonHands, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.LayonHands.basename, abilityValue, wan.spellData.LayonHands.icon, wan.spellData.LayonHands.name)
    end
end

-- Init frame 
local frameLayonHands = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nLayonHands = wan.DefensiveCooldownToValue(wan.spellData.LayonHands.id)
        end
    end)
end
frameLayonHands:RegisterEvent("ADDON_LOADED")
frameLayonHands:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.LayonHands.known and wan.spellData.LayonHands.id
        wan.BlizzardEventHandler(frameLayonHands, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameLayonHands, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.LayonHands.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.LayonHands.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameLayonHands, CheckAbilityValue, abilityActive)
    end
end)
