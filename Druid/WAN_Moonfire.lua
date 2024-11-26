local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMoonfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nMoonfireInstantDmg, nMoonfireDotDmg, nMoonfireDotDuration, nMoonfireDotDps, nMoonfireDotTickRate = 0, 0, 0, 0, 2

    -- Init trait
    local nGalacticGuardian = 0
    local nTwinMoonfireAoeCap = 2
    local nCosmicRapidity = 0
    local nShootingStarsDmg, nShootingStarsProcChance = 0, 0.1

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or (wan.auraData.player.buff_CatForm and not wan.traitData.LunarInspiration.known)
            or not wan.IsSpellUsable(wan.spellData.Moonfire.id)
        then
            wan.UpdateAbilityData(wan.spellData.Moonfire.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Moonfire.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Moonfire.basename)
            return
        end

        -- Base value
        local cMoonfireDotDmg = nMoonfireDotDmg
        local cMoonfireInstantDmg = nMoonfireInstantDmg * ((wan.auraData.player.buff_GalacticGuardian and nGalacticGuardian) or 1)

        -- Shooting Stars
        if wan.traitData.ShootingStars.known then
            local cosmicRapidityMod = wan.traitData.CosmicRapidity.rank > 0 and nCosmicRapidity or 0
            local nMoonfireDotTickModifier = (wan.Haste + cosmicRapidityMod) * 0.01
            local nMoonfireDotTickRateMod = nMoonfireDotTickRate / (1 + nMoonfireDotTickModifier)
            local nSunfireDotTickNumber = nMoonfireDotDuration / nMoonfireDotTickRateMod
            local cShootingStarsDmg = nSunfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg
            cMoonfireDotDmg = cMoonfireDotDmg + cShootingStarsDmg
        end

        -- Twin Moonfire or Twin Moons
        if wan.traitData.TwinMoonfire.known or wan.traitData.TwinMoons.known then
            cMoonfireInstantDmg = cMoonfireInstantDmg * math.min(countValidUnit, nTwinMoonfireAoeCap)
            local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Moonfire.name, nil, cMoonfireInstantDmg)
            local nMoonfireDebuffedAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Moonfire.name)
            local nMissingMoonfireDebuffAoE = math.min(countValidUnit - nMoonfireDebuffedAoE, nTwinMoonfireAoeCap)
            local cMoonfireDotDmgAoE = cMoonfireDotDmg * dotPotencyAoE * nMissingMoonfireDebuffAoE
            cMoonfireDotDmg = cMoonfireDotDmgAoE
        else
            local dotPotency = wan.CheckDotPotency(cMoonfireInstantDmg)
            cMoonfireDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_Moonfire and (cMoonfireDotDmg * dotPotency)) or 0
        end

        local cMoonfireDmg = cMoonfireInstantDmg + cMoonfireDotDmg

        -- Crit layer
        cMoonfireDmg = cMoonfireDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cMoonfireDmg)
        wan.UpdateAbilityData(wan.spellData.Moonfire.basename, abilityValue, wan.spellData.Moonfire.icon, wan.spellData.Moonfire.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local moonfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Moonfire.id, { 1, 2, 3 })
            nMoonfireInstantDmg = moonfireValues[1]
            nMoonfireDotDmg = moonfireValues[2]
            nMoonfireDotDuration = moonfireValues[3]
            nMoonfireDotDps = moonfireValues[2] / moonfireValues[3]

            nShootingStarsDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ShootingStars.entryid, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Moonfire.known and wan.spellData.Moonfire.id
            wan.BlizzardEventHandler(frameMoonfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nGalacticGuardian = wan.GetTraitDescriptionNumbers(wan.traitData.GalacticGuardian.entryid, {3}) / 100
            nCosmicRapidity = wan.GetTraitDescriptionNumbers(wan.traitData.CosmicRapidity.entryid, {1}, wan.traitData.CosmicRapidity.rank)
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMoonfire:RegisterEvent("ADDON_LOADED")
frameMoonfire:SetScript("OnEvent", AddonLoad)