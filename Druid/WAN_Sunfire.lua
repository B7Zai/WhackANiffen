local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aSunfireData = {}
local nSunfireInstantDmg, nSunfireDotDmg, nSunfireDotDuration, nSunfireDotTickRate, nSunfireDotTickRateMod, nSunfireDotTickNumber = 0, 0, 0, 2, 0, 0
local sCatForm, sBearForm = "CatForm", "BearForm"

-- Init trait data
local aShootingStars, nShootingStarsDmg, nShootingStarsProcChance = {}, 0, 0.1
local aSunseekerMushroom, nSunseekerMushroomProcChance, nSunseekerMushroomDmg, nSunseekerMushroomDotDmg = {}, 0.05, 0, 0
local aCosmicRapidity, nCosmicRapidity = {}, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sBearForm)
        or not wan.IsSpellUsable(aSunfireData.id)
    then
        wan.UpdateAbilityData(aSunfireData.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aSunfireData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aSunfireData.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    -- Base value
    local cSunfireInstantDmg = 0
    local cSunfireDotDmg = 0
    local cSunfireInstantDmgAoE = 0
    local cSunfireDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

    local cSunfireDotDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, aSunfireData.formattedName)
        if not checkSunfireDebuff then
            local checkDotPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

            cSunfireDotDmgBaseAoE = cSunfireDotDmgBaseAoE + (nSunfireDotDmg * checkDotPotency)
        end
    end

    ---- BALANCE TRAITS ----

    local cShootingStarsDotDmgAoE = 0
    if aShootingStars.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, aSunfireData.formattedName)

            if not checkSunfireDebuff then
                local checkUnitDotPotency = wan.CheckDotPotency()
                
                cShootingStarsDotDmgAoE = cShootingStarsDotDmgAoE + (nSunfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg * checkUnitDotPotency)
            end
        end
    end

    local cSunseekerMushroomInstantDmgAoE = 0
    local cSunseekerMushroomDotDmgAoE = 0
    if aSunseekerMushroom.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, aSunfireData.formattedName)

            if not checkSunfireDebuff then
                local checkUnitDotPotency = wan.CheckDotPotency()

                cSunseekerMushroomInstantDmgAoE = cSunseekerMushroomInstantDmgAoE + (nSunfireDotTickNumber * nSunseekerMushroomProcChance * nSunseekerMushroomDmg)
                cSunseekerMushroomDotDmgAoE = cSunseekerMushroomDotDmgAoE + (nSunfireDotTickNumber * nSunseekerMushroomProcChance * nSunseekerMushroomDotDmg * checkUnitDotPotency)
            end
        end
    end

    -- Crit layer
    local cSunfireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cSunfireInstantDmg = cSunfireInstantDmg
        + (nSunfireInstantDmg * cSunfireCritValue)

    cSunfireDotDmg = cSunfireDotDmg

    cSunfireInstantDmgAoE = cSunfireInstantDmgAoE
        + (cSunseekerMushroomInstantDmgAoE)

    cSunfireDotDmgAoE = cSunfireDotDmgAoE
        + (cSunfireDotDmgBaseAoE * cSunfireCritValue)
        + (cShootingStarsDotDmgAoE * cSunfireCritValue)
        + (cSunseekerMushroomDotDmgAoE * cSunfireCritValue)

    local cSunfireDmg = cSunfireInstantDmg + cSunfireDotDmg + cSunfireInstantDmgAoE + cSunfireDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSunfireDmg)
    wan.UpdateAbilityData(aSunfireData.basename, abilityValue, aSunfireData.icon, aSunfireData.name)
end

-- Init frame 
local frameSunfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local sunfireValues = wan.GetSpellDescriptionNumbers(aSunfireData.id, { 1, 2, 3 })
            nSunfireInstantDmg = sunfireValues[1]
            nSunfireDotDmg = sunfireValues[2]
            nSunfireDotDuration = sunfireValues[3]

            nShootingStarsDmg = wan.GetTraitDescriptionNumbers(aShootingStars.entryid, { 1 })
            nSunfireDotTickRateMod = nSunfireDotTickRate / (1 + (wan.Haste + nCosmicRapidity) * 0.01)
            nSunfireDotTickNumber = nSunfireDotDuration / nSunfireDotTickRateMod

            local aSunseekerMushroomValues = wan.GetTraitDescriptionNumbers(aSunseekerMushroom.entryid, { 2, 3 }, aSunseekerMushroom.rank)
            nSunseekerMushroomDmg = aSunseekerMushroomValues[1]
            nSunseekerMushroomDotDmg = aSunseekerMushroomValues[2]
        end
    end)
end
frameSunfire:RegisterEvent("ADDON_LOADED")
frameSunfire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aSunfireData = wan.spellData.Sunfire

        abilityActive = aSunfireData.known and aSunfireData.id
        wan.BlizzardEventHandler(frameSunfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)

        sBearForm = wan.spellData.BearForm.formattedName
    end

    if event == "TRAIT_DATA_READY" then
        aShootingStars = wan.traitData.ShootingStars

        aSunseekerMushroom = wan.traitData.SunseekerMushroom

        aCosmicRapidity = wan.traitData.CosmicRapidity
        local nCosmicRapidityValue = wan.GetTraitDescriptionNumbers(aCosmicRapidity.entryid, {1}, aCosmicRapidity.rank)
        nCosmicRapidity = aCosmicRapidity.rank > 0 and nCosmicRapidityValue or 0

    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)
    end
end)