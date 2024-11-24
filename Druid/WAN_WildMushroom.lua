local _, wan = ...

-- Init data
local frameWildMushroom = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nWildMushroomInstantDmg, nWildMushroomDotDmg = 0, 0

    -- Init trait

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.WildMushroom.id)
        then
            wan.UpdateAbilityData(wan.spellData.WildMushroom.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.WildMushroom.id)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.WildMushroom.basename)
            return
        end

        -- Base value
        local cWildMushroomInstantDmg = nWildMushroomInstantDmg * countValidUnit
        local cWirldMushroomDmg = cWildMushroomInstantDmg

        -- Dot Value
        local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.WildMushroom.name, nil, cWildMushroomInstantDmg)
        local wildMushroomDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.WildMushroom.name)
        local missingWildMushroomDebuffAoE = countValidUnit - wildMushroomDebuffedUnitAoE
        local cWildMushroomDotDmg = nWildMushroomDotDmg * dotPotencyAoE * missingWildMushroomDebuffAoE
        cWirldMushroomDmg = cWirldMushroomDmg + cWildMushroomDotDmg

        -- Crit layer
        cWirldMushroomDmg = cWirldMushroomDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cWirldMushroomDmg)
        wan.UpdateAbilityData(wan.spellData.WildMushroom.basename, abilityValue, wan.spellData.WildMushroom.icon, wan.spellData.WildMushroom.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local wildMushroomValues = wan.GetSpellDescriptionNumbers(wan.spellData.WildMushroom.id, { 1, 2 })
            nWildMushroomInstantDmg = wildMushroomValues[1]
            nWildMushroomDotDmg = wildMushroomValues[2]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.WildMushroom.known and wan.spellData.WildMushroom.id
            wan.BlizzardEventHandler(frameWildMushroom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameWildMushroom, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameWildMushroom, CheckAbilityValue, abilityActive)
        end
    end)
end

frameWildMushroom:RegisterEvent("ADDON_LOADED")
frameWildMushroom:SetScript("OnEvent", OnEvent)