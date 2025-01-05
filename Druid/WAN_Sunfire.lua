local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSunfireInstantDmg, nSunfireDotDmg, nSunfireDotDuration, nSunfireDotTickRate = 0, 0, 0, 2

-- Init trait data
local nShootingStarsDmg, nShootingStarsProcChance = 0, 0.1
local nCosmicRapidity = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.Sunfire.id)
    then
        wan.UpdateAbilityData(wan.spellData.Sunfire.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Sunfire.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Sunfire.basename)
        return
    end

    -- Base value
    local cSunfireInstantDmg = nSunfireInstantDmg
    local cSunfireDotDmg = 0

    -- Shooting Stars
    local cShootingStarsDmg = 0
    if wan.traitData.ShootingStars.known then
        local cosmicRapidityMod = wan.traitData.CosmicRapidity.rank > 0 and nCosmicRapidity or 0
        local nSunfireDotTickModifier = (wan.Haste + cosmicRapidityMod) * 0.01
        local nSunfireDotTickRateMod = nSunfireDotTickRate / (1 + nSunfireDotTickModifier)
        local nSunfireDotTickNumber = nSunfireDotDuration / nSunfireDotTickRateMod
        cShootingStarsDmg = nSunfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg
    end

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]
    local checkSunfireDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Sunfire.basename]
    if not checkSunfireDebuff then
        local dotPotency = wan.CheckDotPotency(nSunfireInstantDmg)
        cSunfireDotDmg = cSunfireDotDmg + ((nSunfireDotDmg + cShootingStarsDmg) * dotPotency)
    end

    local cImprovedSunfireDotDmg = 0
    if wan.traitData.ImprovedSunfire.known then
        local cImprovedSunfireInstantDmg = cSunfireInstantDmg / countValidUnit

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkImprovedSunfireDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename]

                if not checkImprovedSunfireDebuff then
                    local dotPotency = wan.CheckDotPotency(cImprovedSunfireInstantDmg, nameplateUnitToken)

                    cImprovedSunfireDotDmg = cImprovedSunfireDotDmg + ((nSunfireDotDmg + cShootingStarsDmg) * dotPotency)
                end
            end
        end
    end

    -- Crit layer
    local cSunfireCritValue =  wan.ValueFromCritical(wan.CritChance)

    cSunfireInstantDmg = cSunfireInstantDmg * cSunfireCritValue
    cSunfireDotDmg = (cSunfireDotDmg + cImprovedSunfireDotDmg) * cSunfireCritValue

    local cSunfireDmg = cSunfireInstantDmg + cSunfireDotDmg

    -- Update ability data
    local abilityValue = math.floor(cSunfireDmg)
    wan.UpdateAbilityData(wan.spellData.Sunfire.basename, abilityValue, wan.spellData.Sunfire.icon, wan.spellData.Sunfire.name)
end

-- Init frame 
local frameSunfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local sunfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Sunfire.id, { 1, 2, 3 })
            nSunfireInstantDmg = sunfireValues[1]
            nSunfireDotDmg = sunfireValues[2]
            nSunfireDotDuration = sunfireValues[3]

            nShootingStarsDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ShootingStars.entryid, { 1 })
        end
    end)
end
frameSunfire:RegisterEvent("ADDON_LOADED")
frameSunfire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Sunfire.known and wan.spellData.Sunfire.id
        wan.BlizzardEventHandler(frameSunfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nCosmicRapidity = wan.GetTraitDescriptionNumbers(wan.traitData.CosmicRapidity.entryid, {1}, wan.traitData.CosmicRapidity.rank)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)
    end
end)