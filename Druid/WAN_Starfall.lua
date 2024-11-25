local _, wan = ...

local frameStarfall = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local nStarfallDmg, nStarfallMaxRange = 0, 0

    -- Init trait data
    local nAstronomicalImpact = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Starfall.id)
        then
            wan.UpdateAbilityData(wan.spellData.Starfall.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit, idValidUnit  = wan.ValidUnitBoolCounter(nil, nStarfallMaxRange)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.Starfall.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local checkPotencyAoE = wan.CheckAoEPotency(idValidUnit)
        local cStarfallDmg = nStarfallDmg * countValidUnit * checkPotencyAoE

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end

        -- Crit layer
        cStarfallDmg = cStarfallDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityValue = math.floor(cStarfallDmg)
        
        wan.UpdateAbilityData(wan.spellData.Starfall.basename, abilityValue, wan.spellData.Starfall.icon, wan.spellData.Starfall.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local starfallValues = wan.GetSpellDescriptionNumbers(wan.spellData.Starfall.id, { 1, 2 })
            nStarfallMaxRange = starfallValues[1]
            nStarfallDmg = starfallValues[2] 
        end
    end)

    -- Set update rate based on settings & data update on traits
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Starfall.known and wan.spellData.Starfall.id
            wan.BlizzardEventHandler(frameStarfall, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)
        end
    end)
end

frameStarfall:RegisterEvent("ADDON_LOADED")
frameStarfall:SetScript("OnEvent", OnEvent)