local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRoarOfSacrifice = 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.RoarofSacrifice.id)
    then
        wan.UpdateMechanicData(wan.spellData.RoarofSacrifice.basename)
        wan.UpdateSupportData(nil, wan.spellData.RoarofSacrifice.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken]["buff_" .. wan.spellData.RoarofSacrifice.basename] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cRoarOfSacrifice = wan.UnitDefensiveCooldownToValue(wan.spellData.RoarofSacrifice.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cRoarOfSacrifice, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RoarofSacrifice.basename, abilityValue, wan.spellData.RoarofSacrifice.icon, wan.spellData.RoarofSacrifice.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RoarofSacrifice.basename)
            end
        end
    else
        if not wan.auraData.player["buff_" .. wan.spellData.RoarofSacrifice.basename] then
            local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
            local cRoarOfSacrifice = nRoarOfSacrifice

            local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cRoarOfSacrifice, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.RoarofSacrifice.basename, abilityValue, wan.spellData.RoarofSacrifice.icon, wan.spellData.RoarofSacrifice.name)
        else
            wan.UpdateMechanicData(wan.spellData.RoarofSacrifice.basename)
        end
    end
end

-- Init frame 
local frameRoarOfSacrifice = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRoarOfSacrifice = wan.DefensiveCooldownToValue(wan.spellData.RoarofSacrifice.id)
        end
    end)
end
frameRoarOfSacrifice:RegisterEvent("ADDON_LOADED")
frameRoarOfSacrifice:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RoarofSacrifice.known and wan.spellData.RoarofSacrifice.id
        wan.BlizzardEventHandler(frameRoarOfSacrifice, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRoarOfSacrifice, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.RoarofSacrifice.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.RoarofSacrifice.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRoarOfSacrifice, CheckAbilityValue, abilityActive)
    end
end)
