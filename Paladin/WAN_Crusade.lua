local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nCrusadeDmg, nCrusadeHeal, nCrusadeMaxRange = 0, 0, 15

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.Crusade.id)
    then
        wan.UpdateAbilityData(wan.spellData.Crusade.basename)
        wan.UpdateMechanicData(wan.spellData.Crusade.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cCrusade = nCrusadeHeal 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cCrusade, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nCrusadeHeal and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.Crusade.basename, groupAbilityValue, wan.spellData.Crusade.icon, wan.spellData.Crusade.name)
    else
        -- Offensive value
        local playerUnitToken = "player"
        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, nCrusadeMaxRange)
        local cCrusadeDmg = nCrusadeDmg
        local cdPotency = wan.CheckOffensiveCooldownPotency(cCrusadeDmg, isValidUnit, idValidUnit)

        -- Update ability data
        local damageValue = cdPotency and math.floor(cCrusadeDmg) or 0
        wan.UpdateAbilityData(wan.spellData.Crusade.basename, damageValue, wan.spellData.Crusade.icon, wan.spellData.Crusade.name)

        -- Defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cCrusadeHeal = wan.UnitAbilityHealValue(playerUnitToken, nCrusadeHeal, currentPercentHealth)

        -- Update ability data
        local healValue = cCrusadeHeal
        wan.UpdateMechanicData(wan.spellData.Crusade.basename, healValue, wan.spellData.Crusade.icon, wan.spellData.Crusade.name)
    end
end

local frameCrusade = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nCrusadeDmg = wan.OffensiveCooldownToValue(wan.spellData.Crusade.id)
            nCrusadeHeal = wan.DefensiveCooldownToValue(wan.spellData.Crusade.id)
        end
    end)
end
frameCrusade:RegisterEvent("ADDON_LOADED")
frameCrusade:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Crusade.known and wan.spellData.Crusade.id
        wan.BlizzardEventHandler(frameCrusade, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameCrusade, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Crusade.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.Crusade.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCrusade, CheckAbilityValue, abilityActive)
    end
end)
