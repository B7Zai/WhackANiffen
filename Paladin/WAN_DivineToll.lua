local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDivineTollDmg, nDivineTollHeal = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
     or not wan.IsSpellUsable(wan.spellData.DivineToll.id)
    then
        wan.UpdateAbilityData(wan.spellData.DivineToll.basename)
        wan.UpdateMechanicData(wan.spellData.DivineToll.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cDivineToll = nDivineTollHeal 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cDivineToll, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nDivineTollHeal and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.DivineToll.basename, groupAbilityValue, wan.spellData.DivineToll.icon, wan.spellData.DivineToll.name)
    else
        -- Offensive value
        local playerUnitToken = "player"
        local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.DivineToll.id)
        local cDivineTollDmg = nDivineTollDmg
        local cdPotency = wan.CheckOffensiveCooldownPotency(cDivineTollDmg, isValidUnit, idValidUnit)

        -- Update ability data
        local damageValue = cdPotency and math.floor(cDivineTollDmg) or 0
        wan.UpdateAbilityData(wan.spellData.DivineToll.basename, damageValue, wan.spellData.DivineToll.icon, wan.spellData.DivineToll.name)

        -- Defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cDivineTollHeal = wan.UnitAbilityHealValue(playerUnitToken, nDivineTollHeal, currentPercentHealth)

        -- Update ability data
        local healValue = cDivineTollHeal
        wan.UpdateMechanicData(wan.spellData.DivineToll.basename, healValue, wan.spellData.DivineToll.icon, wan.spellData.DivineToll.name)
    end
end

local frameDivineToll = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nDivineTollDmg = wan.OffensiveCooldownToValue(wan.spellData.DivineToll.id)
            nDivineTollHeal = wan.DefensiveCooldownToValue(wan.spellData.DivineToll.id)
        end
    end)
end
frameDivineToll:RegisterEvent("ADDON_LOADED")
frameDivineToll:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DivineToll.known and wan.spellData.DivineToll.id
        wan.SetUpdateRate(frameDivineToll, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameDivineToll, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.DivineToll.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.DivineToll.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDivineToll, CheckAbilityValue, abilityActive)
    end
end)
