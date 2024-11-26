local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMoonMoon = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nMoonMoonDmg = 0

    -- Init trait data
    local nAstronomicalImpact = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.NewMoon.id)
        then
            wan.UpdateAbilityData(wan.spellData.NewMoon.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.NewMoon.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.NewMoon.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cMoonMoonDmg = nMoonMoonDmg

        -- AoE values
        if wan.spellData.NewMoon.name == "Full Moon" and countValidUnit > 1 then
            local moonMoonUnitAoE = countValidUnit - 1
            local softCappedValidUnit = math.sqrt(1 / countValidUnit)
            local cMoonMoonAoEDmg = (nMoonMoonDmg * softCappedValidUnit) * moonMoonUnitAoE
            cMoonMoonDmg = cMoonMoonDmg + cMoonMoonAoEDmg
        end

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.NewMoon.id, wan.spellData.NewMoon.castTime)
        cMoonMoonDmg = cMoonMoonDmg * castEfficiency

        -- Crit layer
        cMoonMoonDmg = cMoonMoonDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityValue = math.floor(cMoonMoonDmg)

        wan.UpdateAbilityData(wan.spellData.NewMoon.basename, abilityValue, wan.spellData.NewMoon.icon, wan.spellData.NewMoon.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMoonMoonDmg = wan.GetSpellDescriptionNumbers(wan.spellData.NewMoon.id, { 1 })

        end
    end)

    -- Set update rate based on settings & data update on traits
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.NewMoon.known and wan.spellData.NewMoon.id
            wan.BlizzardEventHandler(frameMoonMoon, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameMoonMoon, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMoonMoon, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMoonMoon:RegisterEvent("ADDON_LOADED")
frameMoonMoon:SetScript("OnEvent", AddonLoad)