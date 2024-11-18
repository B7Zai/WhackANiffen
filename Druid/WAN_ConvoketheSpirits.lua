local _, wan = ...

local frameConvokeTheSpirits = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local maxRange = 0
    local nConvoketheSpiritsDmg, nConvoketheSpiritsHeal = 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or not wan.IsSpellUsable(wan.spellData.ConvoketheSpirits.id)
        then
            wan.UpdateAbilityData(wan.spellData.ConvoketheSpirits.basename)
            wan.UpdateMechanicData(wan.spellData.ConvoketheSpirits.basename)
            return
        end -- Early exits

        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, maxRange)
        local cConvoketheSpiritsDmg = nConvoketheSpiritsDmg  -- Base values
        local cdPotency = wan.CheckOffensiveCooldownPotency(cConvoketheSpiritsDmg, isValidUnit, idValidUnit)
        local damageValue = cdPotency and math.floor(cConvoketheSpiritsDmg) -- Update AbilityData

        if damageValue then
            wan.UpdateAbilityData(
            wan.spellData.ConvoketheSpirits.basename,
            damageValue,
            wan.spellData.ConvoketheSpirits.icon,
            wan.spellData.ConvoketheSpirits.name
        )
        else
            wan.UpdateAbilityData(wan.spellData.ConvoketheSpirits.basename)
        end

        local cConvoketheSpiritsHeal = nConvoketheSpiritsHeal
        local healValue = wan.HealThreshold() > cConvoketheSpiritsHeal and cConvoketheSpiritsHeal

        if healValue then
            wan.UpdateMechanicData(
            wan.spellData.ConvoketheSpirits.basename,
            healValue,
            wan.spellData.ConvoketheSpirits.icon,
            wan.spellData.ConvoketheSpirits.name
        )
        else
            wan.UpdateMechanicData(wan.spellData.ConvoketheSpirits.basename)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nConvoketheSpiritsDmg = wan.OffensiveCooldownToValue(wan.spellData.ConvoketheSpirits.id)
            nConvoketheSpiritsHeal = wan.DefensiveCooldownToValue(wan.spellData.ConvoketheSpirits.id)
            local formID = GetShapeshiftForm()
            if formID == 0 or formID == 4 then
                maxRange = 40
            elseif formID == 1 or formID == 2 then
                maxRange = 5
            else
                maxRange = 0
            end
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.ConvoketheSpirits.known and wan.spellData.ConvoketheSpirits.id
            wan.BlizzardEventHandler(frameConvokeTheSpirits, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameConvokeTheSpirits, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameConvokeTheSpirits, CheckAbilityValue, abilityActive)
        end
    end)
end

frameConvokeTheSpirits:RegisterEvent("ADDON_LOADED")
frameConvokeTheSpirits:SetScript("OnEvent", OnEvent)