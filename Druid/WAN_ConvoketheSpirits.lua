local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nConvoketheSpiritsDmg, nConvoketheSpiritsHeal, nConvokeTheSpiritsMaxRange = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
        or not wan.PlayerState.Combat or not wan.IsSpellUsable(wan.spellData.ConvoketheSpirits.id)
    then
        wan.UpdateAbilityData(wan.spellData.ConvoketheSpirits.basename)
        wan.UpdateMechanicData(wan.spellData.ConvoketheSpirits.basename)
        wan.UpdateSupportData(nil, wan.spellData.ConvoketheSpirits.basename)
        return
    end

    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[wan.spellData.ConvoketheSpirits.basename] = wan.HealUnitCountAoE[wan.spellData.ConvoketheSpirits.basename] or 1

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cConvoketheSpirits = wan.UnitDefensiveCooldownToValue(wan.spellData.ConvoketheSpirits.id, groupUnitToken) * wan.UnitState.LevelScale[groupUnitGUID]

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cConvoketheSpirits, currentPercentHealth)
                if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                wan.UpdateSupportData(groupUnitToken, wan.spellData.ConvoketheSpirits.basename, abilityValue, wan.spellData.ConvoketheSpirits.icon, wan.spellData.ConvoketheSpirits.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.ConvoketheSpirits.basename)
            end
        end

        if unitsNeedHeal > 0 then
            wan.HealUnitCountAoE[wan.spellData.ConvoketheSpirits.basename] = unitsNeedHeal
        else
            wan.HealUnitCountAoE[wan.spellData.ConvoketheSpirits.basename] = 1
        end
    else
        -- Offensive value
        local playerUnitToken = "player"
        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, nConvokeTheSpiritsMaxRange)
        local cConvoketheSpiritsDmg = nConvoketheSpiritsDmg
        local cdPotency = wan.CheckOffensiveCooldownPotency(cConvoketheSpiritsDmg, isValidUnit, idValidUnit)

        -- Update ability data
        local damageValue = cdPotency and math.floor(cConvoketheSpiritsDmg) or 0
        wan.UpdateAbilityData(wan.spellData.ConvoketheSpirits.basename, damageValue, wan.spellData.ConvoketheSpirits.icon, wan.spellData.ConvoketheSpirits.name)

        -- Defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cConvoketheSpiritsHeal = wan.UnitAbilityHealValue(playerUnitToken, nConvoketheSpiritsHeal, currentPercentHealth)

        -- Update ability data
        local healValue = cConvoketheSpiritsHeal
        wan.UpdateMechanicData(wan.spellData.ConvoketheSpirits.basename, healValue, wan.spellData.ConvoketheSpirits.icon, wan.spellData.ConvoketheSpirits.name)
    end
end

local frameConvokeTheSpirits = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nConvoketheSpiritsDmg = wan.OffensiveCooldownToValue(wan.spellData.ConvoketheSpirits.id)
            nConvoketheSpiritsHeal = wan.DefensiveCooldownToValue(wan.spellData.ConvoketheSpirits.id)
            local formID = GetShapeshiftForm()
            if formID == 0 or formID == 4 then
                nConvokeTheSpiritsMaxRange = 40
            elseif formID == 1 or formID == 2 then
                nConvokeTheSpiritsMaxRange = 5
            else
                nConvokeTheSpiritsMaxRange = 0
            end
        end
    end)
end
frameConvokeTheSpirits:RegisterEvent("ADDON_LOADED")
frameConvokeTheSpirits:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ConvoketheSpirits.known and wan.spellData.ConvoketheSpirits.id
        wan.SetUpdateRate(frameConvokeTheSpirits, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameConvokeTheSpirits, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.ConvoketheSpirits.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.ConvoketheSpirits.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameConvokeTheSpirits, CheckAbilityValue, abilityActive)
    end
end)
