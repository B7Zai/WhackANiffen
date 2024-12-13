local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameTranquility = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nTranquility = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Tranquility.id)
        then
            wan.UpdateMechanicData(wan.spellData.Tranquility.basename)
            wan.UpdateSupportData(nil, wan.spellData.Tranquility.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()
            local unitTokenAoE = "allGroupUnitTokens"

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cTranquility = wan.UnitDefensiveCooldownToValue(wan.spellData.Tranquility.id, groupUnitToken)

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cTranquility, currentPercentHealth)
                    wan.UpdateSupportData(unitTokenAoE, wan.spellData.Tranquility.basename, abilityValue, wan.spellData.Tranquility.icon, wan.spellData.Tranquility.name)
                else
                    wan.UpdateSupportData(unitTokenAoE, wan.spellData.Tranquility.basename)
                end
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
            abilityActive = wan.spellData.Tranquility.known and wan.spellData.Tranquility.id
            wan.BlizzardEventHandler(frameTranquility, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
        end
    end)
end

frameTranquility:RegisterEvent("ADDON_LOADED")
frameTranquility:SetScript("OnEvent", AddonLoad)