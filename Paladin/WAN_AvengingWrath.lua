local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nAvengingWrathDmg, nAvengingWrathHeal, nAvengingWrathMaxRange = 0, 0, 15

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.AvengingWrath.id)
    then
        wan.UpdateAbilityData(wan.spellData.AvengingWrath.basename)
        wan.UpdateMechanicData(wan.spellData.AvengingWrath.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cAvengingWrath = nAvengingWrathHeal 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cAvengingWrath, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nAvengingWrathHeal and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.AvengingWrath.basename, groupAbilityValue, wan.spellData.AvengingWrath.icon, wan.spellData.AvengingWrath.name)
    else
        -- Offensive value
        local playerUnitToken = "player"
        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, nAvengingWrathMaxRange)
        local cAvengingWrathDmg = nAvengingWrathDmg
        local cdPotency = wan.CheckOffensiveCooldownPotency(cAvengingWrathDmg, isValidUnit, idValidUnit)

        -- Update ability data
        local damageValue = cdPotency and math.floor(cAvengingWrathDmg) or 0
        wan.UpdateAbilityData(wan.spellData.AvengingWrath.basename, damageValue, wan.spellData.AvengingWrath.icon, wan.spellData.AvengingWrath.name)

        -- Defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cAvengingWrathHeal = wan.UnitAbilityHealValue(playerUnitToken, nAvengingWrathHeal, currentPercentHealth)

        -- Update ability data
        local healValue = cAvengingWrathHeal
        wan.UpdateMechanicData(wan.spellData.AvengingWrath.basename, healValue, wan.spellData.AvengingWrath.icon, wan.spellData.AvengingWrath.name)
    end
end

local frameAvengingWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nAvengingWrathDmg = wan.OffensiveCooldownToValue(wan.spellData.AvengingWrath.id)
            nAvengingWrathHeal = wan.DefensiveCooldownToValue(wan.spellData.AvengingWrath.id)
        end
    end)
end
frameAvengingWrath:RegisterEvent("ADDON_LOADED")
frameAvengingWrath:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.AvengingWrath.isPassive and wan.spellData.AvengingWrath.known and wan.spellData.AvengingWrath.id
        wan.BlizzardEventHandler(frameAvengingWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameAvengingWrath, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.AvengingWrath.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.AvengingWrath.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAvengingWrath, CheckAbilityValue, abilityActive)
    end
end)
