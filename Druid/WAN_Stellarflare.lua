local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameStellarFlare = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nStellarFlareInstantDmg, nStellarFlareDotDmg, nStellarFlareDotDuration = 0, 0, 0

    -- Init trait data
    local nAstronomicalImpact = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.StellarFlare.id)
        then
            wan.UpdateAbilityData(wan.spellData.StellarFlare.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(wan.spellData.StellarFlare.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.StellarFlare.basename)
            return
        end

        -- Dot value
        local dotPotency = wan.CheckDotPotency(nStellarFlareInstantDmg)
        local cStellarFlareDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_StellarFlare and (nStellarFlareDotDmg * dotPotency)) or 0

        -- Base value
        local critChanceMod = 0
        local critDamageMod = 0
        local cStellarFlareDmg = nStellarFlareInstantDmg + cStellarFlareDotDmg

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.StellarFlare.id, wan.spellData.StellarFlare.castTime)
        cStellarFlareDmg = cStellarFlareDmg * castEfficiency

        -- Crit layer
        cStellarFlareDmg = cStellarFlareDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityDmg = math.floor(cStellarFlareDmg)

        wan.UpdateAbilityData(wan.spellData.StellarFlare.basename, abilityDmg, wan.spellData.StellarFlare.icon, wan.spellData.StellarFlare.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local stellarFlareValues = wan.GetSpellDescriptionNumbers(wan.spellData.StellarFlare.id, { 1, 2, 3 })
            nStellarFlareInstantDmg = stellarFlareValues[1]
            nStellarFlareDotDmg = stellarFlareValues[2]
            nStellarFlareDotDuration = stellarFlareValues[3]
        end
    end)

    -- Set update rate based on settings & data update on traits
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.StellarFlare.known and wan.spellData.StellarFlare.id
            wan.BlizzardEventHandler(frameStellarFlare, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)
        end
    end)
end

frameStellarFlare:RegisterEvent("ADDON_LOADED")
frameStellarFlare:SetScript("OnEvent", AddonLoad)