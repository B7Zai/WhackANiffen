local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameTreeofLife = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nIncarnationTreeofLife = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_IncarnationTreeofLife
        or not wan.IsSpellUsable(wan.spellData.IncarnationTreeofLife.id)
        then
            wan.UpdateMechanicData(wan.spellData.IncarnationTreeofLife.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()
            local groupAbilityValue = 0

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then
                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cIncarnationTreeofLife = nIncarnationTreeofLife 

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cIncarnationTreeofLife, currentPercentHealth)
                    groupAbilityValue = groupAbilityValue + abilityValue
                end
            end

            groupAbilityValue = groupAbilityValue > nIncarnationTreeofLife and groupAbilityValue or 0
            wan.UpdateMechanicData(wan.spellData.IncarnationTreeofLife.basename, groupAbilityValue, wan.spellData.IncarnationTreeofLife.icon, wan.spellData.IncarnationTreeofLife.name)
        else
            -- Base defensive value
            local cIncarnationTreeofLife = nIncarnationTreeofLife
            local healThreshold = wan.HealThreshold() > cIncarnationTreeofLife

            -- Update ability data
            local healValue = healThreshold and cIncarnationTreeofLife or 0
            wan.UpdateMechanicData(wan.spellData.IncarnationTreeofLife.basename, healValue, wan.spellData.IncarnationTreeofLife.icon, wan.spellData.IncarnationTreeofLife.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nIncarnationTreeofLife = wan.DefensiveCooldownToValue(wan.spellData.IncarnationTreeofLife.id)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.IncarnationTreeofLife.known and wan.spellData.IncarnationTreeofLife.id
            wan.SetUpdateRate(frameTreeofLife, CheckAbilityValue, abilityActive)
            wan.BlizzardEventHandler(frameTreeofLife, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameTreeofLife, CheckAbilityValue, abilityActive)
        end
    end)
end

frameTreeofLife:RegisterEvent("ADDON_LOADED")
frameTreeofLife:SetScript("OnEvent", AddonLoad)