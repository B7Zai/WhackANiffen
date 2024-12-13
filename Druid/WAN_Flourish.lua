local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameFlourish = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nFlourish = 0


    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.Flourish.id)
        then
            wan.UpdateMechanicData(wan.spellData.Flourish.basename)
            wan.UpdateSupportData(nil, wan.spellData.Flourish.basename)
            return
        end

        local countTotalHots = 0
        local unitTokenAoE = "allGroupUnitTokens"
        local cFlourish = nFlourish * 0.1

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, _ in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    countTotalHots = countTotalHots + countHots
                end
            end

            local cFlourishHeal = cFlourish * countTotalHots
            local abilityValue = math.floor((cFlourishHeal > nFlourish and cFlourishHeal) or 0)
            wan.UpdateSupportData(unitTokenAoE, wan.spellData.Flourish.basename, abilityValue, wan.spellData.Flourish.icon, wan.spellData.Flourish.name)
        else
            local unitToken = "player"
            local playerGUID = wan.PlayerState.GUID
            local currentPercentHealth = playerGUID and (UnitPercentHealthFromGUID(playerGUID) or 0)
            local _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
            local cFlourish = (wan.DefensiveCooldownToValue(wan.spellData.Flourish.id))
            local cFlourishHeal = ((cFlourish * 0.1) * countHots > cFlourish) or 0

            local abilityValue = wan.UnitAbilityHealValue(unitToken, cFlourish, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.Flourish.basename, abilityValue, wan.spellData.Flourish.icon, wan.spellData.Flourish.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFlourish = wan.DefensiveCooldownToValue(wan.spellData.Flourish.id)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Flourish.known and wan.spellData.Flourish.id
            wan.BlizzardEventHandler(frameFlourish, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameFlourish, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameFlourish, CheckAbilityValue, abilityActive)
        end
    end)
end

frameFlourish:RegisterEvent("ADDON_LOADED")
frameFlourish:SetScript("OnEvent", AddonLoad)