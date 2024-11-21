local _, wan = ...

-- Init data
local frameThrash = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end
    
    -- Init spell data
    local abilityActive = false
    local nTrashInstantDmg, nThrashDotDmg, nThrashDotDuration, nThrashDotDps, nThrashMaxStacks = 0, 0, 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
         -- Early exits
        if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Thrash.id)
        then
            wan.UpdateAbilityData(wan.spellData.Thrash.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Thrash.maxRange)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.Thrash.basename)
            return
        end

        -- Base Values
        local cThrashInstantDmg = nTrashInstantDmg * countValidUnit

         -- Dot Values
        local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Thrash.name, nThrashMaxStacks, cThrashInstantDmg)
        local thrashDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Thrash.name, nThrashMaxStacks)
        local missingThrashDebuffAoE = countValidUnit - thrashDebuffedUnitAoE
        local cThrashDotValue = nThrashDotDmg * missingThrashDebuffAoE * dotPotencyAoE
        local cThrashDotDmg = (thrashDebuffedUnitAoE < countValidUnit and cThrashDotValue) or 0

        local cThrashDmg = cThrashInstantDmg + cThrashDotDmg

        -- Crit layer
        cThrashDmg = cThrashDmg * wan.ValueFromCritical(wan.CritChance)

         -- Update ability data
        local abilityValue = math.floor(cThrashDmg)
        wan.UpdateAbilityData(wan.spellData.Thrash.basename, abilityValue, wan.spellData.Thrash.icon, wan.spellData.Thrash.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local thrashValues = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 1, 2, 3, 4 })
            nTrashInstantDmg = thrashValues[1]
            nThrashDotDmg = thrashValues[2]
            nThrashDotDuration = thrashValues[3]
            nThrashDotDps = thrashValues[2] / thrashValues[3]
            if wan.auraData.player and wan.auraData.player.buff_BearForm then
                nThrashMaxStacks = thrashValues[4]
            else
                nThrashMaxStacks = 1
            end
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Thrash.known and wan.spellData.Thrash.id
            wan.BlizzardEventHandler(frameThrash, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameThrash, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameThrash, CheckAbilityValue, abilityActive)
        end
    end)
end

frameThrash:RegisterEvent("ADDON_LOADED")
frameThrash:SetScript("OnEvent", OnEvent)