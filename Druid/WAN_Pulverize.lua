local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local framePulverize = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nPulverizeDmg, nPulverizeHeal, nPulverizeDR = 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
        or wan.auraData[wan.TargetUnitID].debuff_Pulverize or not wan.IsSpellUsable(wan.spellData.Pulverize.id)
        then
            wan.UpdateAbilityData(wan.spellData.Pulverize.basename)
            wan.UpdateMechanicData(wan.spellData.Pulverize.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Pulverize.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Pulverize.basename)
            wan.UpdateMechanicData(wan.spellData.Pulverize.basename)
            return
        end

        -- Base values
        local cPulverizeDmg = nPulverizeDmg
        local cPulverizeHeal = nPulverizeDR / countValidUnit

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        cPulverizeDmg = cPulverizeDmg * checkPhysicalDR

        -- Crit layer
        cPulverizeDmg = cPulverizeDmg * wan.ValueFromCritical(wan.CritChance)

        -- Threat situation
        local isTanking = wan.IsTanking()

        -- Update ability data
        local damageValue = not isTanking and math.floor(cPulverizeDmg) or 0 -- Update Ability Data
        local healValue = isTanking and math.floor(cPulverizeHeal) or 0 -- Update Mechanic Data

        wan.UpdateMechanicData(wan.spellData.Pulverize.basename, healValue, wan.spellData.Pulverize.icon, wan.spellData.Pulverize.name)
        wan.UpdateAbilityData(wan.spellData.Pulverize.basename, damageValue, wan.spellData.Pulverize.icon, wan.spellData.Pulverize.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nPulverizeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Pulverize.id, { 2, 3 })
            nPulverizeDmg = nPulverizeValues[1]
            nPulverizeHeal = nPulverizeValues[2]
            nPulverizeDR = wan.AbilityPercentageToValue(nPulverizeHeal)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Pulverize.known and wan.spellData.Pulverize.id
            wan.BlizzardEventHandler(framePulverize, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(framePulverize, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(framePulverize, CheckAbilityValue, abilityActive)
        end
    end)
end

framePulverize:RegisterEvent("ADDON_LOADED")
framePulverize:SetScript("OnEvent", AddonLoad)