local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameOvergrowth = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nOvergrowth = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Overgrowth.id)
        then
            wan.UpdateMechanicData(wan.spellData.Overgrowth.basename)
            wan.UpdateSupportData(nil, wan.spellData.Overgrowth.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] and (not wan.auraData[groupUnitToken].buff_Lifebloom
                and not wan.auraData[groupUnitToken].buff_Rejuvenation)then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cOvergrowth = wan.UnitDefensiveCooldownToValue(wan.spellData.Overgrowth.id, groupUnitToken)

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cOvergrowth, currentPercentHealth)
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.Overgrowth.basename, abilityValue, wan.spellData.Overgrowth.icon, wan.spellData.Overgrowth.name)
                else
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.Overgrowth.basename)
                end
            end
        else
            local unitToken = "player"
            if (not wan.auraData[unitToken].buff_Lifebloom
            and not wan.auraData[unitToken].buff_Rejuvenation) then

                local playerGUID = wan.PlayerState.GUID
                local currentPercentHealth = playerGUID and (UnitPercentHealthFromGUID(playerGUID) or 0)
                local cOvergrowth = wan.UnitDefensiveCooldownToValue(wan.spellData.Overgrowth.id)

                local abilityValue = wan.UnitAbilityHealValue(unitToken, cOvergrowth, currentPercentHealth)
                wan.UpdateMechanicData(wan.spellData.Overgrowth.basename, abilityValue, wan.spellData.Overgrowth.icon, wan.spellData.Overgrowth.name)
            else
                wan.UpdateMechanicData(wan.spellData.Overgrowth.basename)
            end
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nOvergrowth = wan.GetSpellDescriptionNumbers(wan.spellData.Overgrowth.id, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Overgrowth.known and wan.spellData.Overgrowth.id
            wan.BlizzardEventHandler(frameOvergrowth, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameOvergrowth, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameOvergrowth, CheckAbilityValue, abilityActive)
        end
    end)
end

frameOvergrowth:RegisterEvent("ADDON_LOADED")
frameOvergrowth:SetScript("OnEvent", AddonLoad)