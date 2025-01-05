local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nIronbark = 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Ironbark.id)
    then
        wan.UpdateMechanicData(wan.spellData.Ironbark.basename)
        wan.UpdateSupportData(nil, wan.spellData.Ironbark.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken].buff_Ironbark then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cIronbark = wan.UnitDefensiveCooldownToValue(wan.spellData.Ironbark.id, groupUnitToken)

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cIronbark, currentPercentHealth)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Ironbark.basename, abilityValue, wan.spellData.Ironbark.icon, wan.spellData.Ironbark.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.Ironbark.basename)
            end
        end
    else
        if not wan.auraData.player.buff_Ironbark then
            local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
            local cIronbark = nIronbark

            local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cIronbark, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.Ironbark.basename, abilityValue, wan.spellData.Ironbark.icon, wan.spellData.Ironbark.name)
        else
            wan.UpdateMechanicData(wan.spellData.Ironbark.basename)
        end
    end
end

-- Init frame 
local frameIronbark = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nIronbark = wan.UnitDefensiveCooldownToValue(wan.spellData.Ironbark.id)
        end
    end)
end
frameIronbark:RegisterEvent("ADDON_LOADED")
frameIronbark:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Ironbark.known and wan.spellData.Ironbark.id
        wan.BlizzardEventHandler(frameIronbark, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIronbark, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Ironbark.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.Ironbark.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIronbark, CheckAbilityValue, abilityActive)
    end
end)
