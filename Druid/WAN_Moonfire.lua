local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMoonfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    local playerGUID = wan.PlayerState.GUID or UnitGUID("player")

    -- Init data
    local abilityActive = false
    local nMoonfireInstantDmg, nMoonfireDotDmg, nMoonfireDotDuration, nMoonfireDotDps, nMoonfireDotTickRate = 0, 0, 0, 0, 2

    -- Init trait
    local nGalacticGuardian = 0
    local nTwinMoonfireAoeCap = 1
    local nCosmicRapidity = 0
    local nShootingStarsDmg, nShootingStarsProcChance = 0, 0.1

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData[playerGUID].buff_Prowl
            or (wan.auraData[playerGUID].buff_CatForm and not wan.traitData.LunarInspiration.known)
            or (wan.auraData[playerGUID].buff_BearForm and wan.PlayerState.Role ~= "TANK")
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
        local cMoonfireInstantDmg = nMoonfireInstantDmg
        local cMoonfireDotDmg = 0

        -- add Shooting Stars layer
        local cShootingStarsDmg = 0
        if wan.traitData.ShootingStars.known then
            local cosmicRapidityMod = wan.traitData.CosmicRapidity.rank > 0 and nCosmicRapidity or 0
            local nMoonfireDotTickModifier = (wan.Haste + cosmicRapidityMod) * 0.01
            local nMoonfireDotTickRateMod = nMoonfireDotTickRate / (1 + nMoonfireDotTickModifier)
            local nMoonfireDotTickNumber = nMoonfireDotDuration / nMoonfireDotTickRateMod
            cShootingStarsDmg = nMoonfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg
        end

        local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]
        local checkMoonfireDebuff = targetGUID and wan.auraData[targetGUID]["debuff_" .. wan.spellData.Moonfire.basename]
        if not checkMoonfireDebuff then
            local dotPotency = wan.CheckDotPotency(nMoonfireInstantDmg)
            cMoonfireDotDmg = cMoonfireDotDmg + ((nMoonfireDotDmg + cShootingStarsDmg) * dotPotency)
        end

        -- add Twin Moons and Twin Moonfire layer
        local cTwinMoonfireInstantDmg = 0
        local cTwinMoonfireDotDmg = 0
        if (wan.traitData.TwinMoonfire.known or wan.traitData.TwinMoons.known) and countValidUnit > 1 then
            cTwinMoonfireInstantDmg = cTwinMoonfireInstantDmg + nMoonfireInstantDmg
            for unitToken, unitGUID in pairs(idValidUnit) do
                if unitGUID ~= targetGUID then
                    local checkTwinMoonfireDebuff = wan.auraData[unitGUID]["debuff_" .. wan.spellData.Moonfire.basename]
                    if not checkTwinMoonfireDebuff then
                        local unitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, unitToken)
                        cTwinMoonfireDotDmg = cTwinMoonfireDotDmg + ((nMoonfireDotDmg + cShootingStarsDmg) * unitDotPotency)
                        break
                    end
                end


            end
        end

        local cGalacticGuardian = 1
        if wan.traitData.GalacticGuardian.known then
            local checkGalacticGuardianBuff = wan.auraData.playerGUID.buff_GalacticGuardian
            if checkGalacticGuardianBuff then
                cGalacticGuardian = cGalacticGuardian + nGalacticGuardian
            end
        end

        -- Crit layer
        local cMoonfireCritValue = wan.ValueFromCritical(wan.CritChance)

        cMoonfireInstantDmg = (cMoonfireInstantDmg + cTwinMoonfireInstantDmg) * cGalacticGuardian * cMoonfireCritValue
        cMoonfireDotDmg = (cMoonfireDotDmg + cTwinMoonfireDotDmg) * cMoonfireCritValue

        local cMoonfireDmg = cMoonfireInstantDmg + cMoonfireDotDmg

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
            nGalacticGuardian = wan.GetTraitDescriptionNumbers(wan.traitData.GalacticGuardian.entryid, {3}) * 0.01
            nCosmicRapidity = wan.GetTraitDescriptionNumbers(wan.traitData.CosmicRapidity.entryid, {1}, wan.traitData.CosmicRapidity.rank)
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMoonfire:RegisterEvent("ADDON_LOADED")
frameMoonfire:SetScript("OnEvent", AddonLoad)