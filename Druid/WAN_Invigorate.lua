local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameInvigorate = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nInvigorate = 0


    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Invigorate.id)
        then
            wan.UpdateMechanicData(wan.spellData.Invigorate.basename)
            wan.UpdateSupportData(nil, wan.spellData.Invigorate.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] and (wan.auraData[groupUnitToken].buff_LifeBloom or wan.auraData[groupUnitToken].buff_Rejuvenation) then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cInvigorate = wan.UnitDefensiveCooldownToValue(wan.spellData.Invigorate.id, groupUnitToken)

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cInvigorate, currentPercentHealth)
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.Invigorate.basename, abilityValue, wan.spellData.Invigorate.icon, wan.spellData.Invigorate.name)
                else
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.Invigorate.basename)
                end
            end
        else
            local unitToken = "player"
            local unitGUID = wan.PlayerState.GUID
            if (wan.auraData[unitToken].buff_LifeBloom or wan.auraData[unitToken].buff_Rejuvenation) then

                local currentPercentHealth = UnitPercentHealthFromGUID(unitGUID) or 1
                local cInvigorate = wan.UnitDefensiveCooldownToValue(wan.spellData.Invigorate.id)

                local abilityValue = wan.UnitAbilityHealValue(unitToken, cInvigorate, currentPercentHealth)
                wan.UpdateMechanicData(wan.spellData.Invigorate.basename, abilityValue, wan.spellData.Invigorate.icon, wan.spellData.Invigorate.name)
            else
                wan.UpdateMechanicData(wan.spellData.Invigorate.basename)
            end
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Invigorate.known and wan.spellData.Invigorate.id
            wan.BlizzardEventHandler(frameInvigorate, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameInvigorate, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "HEALERMODE_FRAME_TOGGLE" then
            if wan.PlayerState.InHealerMode then
                wan.UpdateMechanicData(wan.spellData.Invigorate.basename)
            else
                wan.UpdateSupportData(nil, wan.spellData.Invigorate.basename)
            end
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameInvigorate, CheckAbilityValue, abilityActive)
        end
    end)
end

frameInvigorate:RegisterEvent("ADDON_LOADED")
frameInvigorate:SetScript("OnEvent", AddonLoad)