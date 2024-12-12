local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameGroveGuardians = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nGroveGuardians = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.GroveGuardians.id)
        then
            wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename)
            wan.UpdateSupportData(nil, wan.spellData.GroveGuardians.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cGroveGuardians = wan.UnitDefensiveCooldownToValue(wan.spellData.GroveGuardians.id, groupUnitToken)

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cGroveGuardians, currentPercentHealth)
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.GroveGuardians.basename, abilityValue, wan.spellData.GroveGuardians.icon, wan.spellData.GroveGuardians.name)
                else
                    wan.UpdateSupportData(groupUnitToken, wan.spellData.GroveGuardians.basename)
                end
            end
        else
            local unitToken = "player"
            if not wan.auraData[unitToken].buff_Ironbark then

                local playerGUID = wan.PlayerState.GUID
                local currentPercentHealth = playerGUID and (UnitPercentHealthFromGUID(playerGUID) or 0)
                local cGroveGuardians = wan.UnitDefensiveCooldownToValue(wan.spellData.GroveGuardians.id)

                local abilityValue = wan.UnitAbilityHealValue(unitToken, cGroveGuardians, currentPercentHealth)
                wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename, abilityValue, wan.spellData.GroveGuardians.icon, wan.spellData.GroveGuardians.name)
            else
                wan.UpdateMechanicData(wan.spellData.GroveGuardians.basename)
            end
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nGroveGuardians = wan.GetSpellDescriptionNumbers(wan.spellData.GroveGuardians.id, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.GroveGuardians.known and wan.spellData.GroveGuardians.id
            wan.BlizzardEventHandler(frameGroveGuardians, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameGroveGuardians, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameGroveGuardians, CheckAbilityValue, abilityActive)
        end
    end)
end

frameGroveGuardians:RegisterEvent("ADDON_LOADED")
frameGroveGuardians:SetScript("OnEvent", AddonLoad)