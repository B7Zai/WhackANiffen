local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aMoonfireData = {}
local nMoonfireInstantDmg, nMoonfireDotDmg, nMoonfireDotDuration, nMoonfireDotTickRate, nMoonfireDotTickRateMod, nMoonfireDotTickNumber = 0, 0, 0, 2, 0, 0
local sMoonfire = "Moonfire"
local sCatForm, sBearForm = "CatForm", "BearForm"
local sProwl = "Prowl"

-- Init trait
local bShootingStars, nShootingStarsDmg, nShootingStarsProcChance = false, 0, 0.1
local bTwinMoons = false
local nCosmicRapidity = 0
local bBalanceofAllThings, sBalanceofAllThingsBuff, sBalanceofAllThings = false, "BalanceofAllThings", 0
local nBalanceofAllThingsBuffNatureID, nBalanceofAllThingsBuffArcaneID = 394049, 394050

local bTwinMoonfire, nTwinMoonfireAoeCap = false, 1
local bGalacticGuardian, sGalacticGuardian, nGalacticGuardian = false, "GalacticGuardian", 0

local bLunarInspiration = false
local bBloodtalons, sBloodtalons, nBloodtalonsTimer, runBloodtalons = false, "Bloodtalons", 0, true

-- Ability value calculation
local function CheckAbilityValue()
    local isUsableMoonfire = wan.IsSpellUsable(aMoonfireData.id)

    if not wan.PlayerState.Status
        or wan.CheckUnitBuff(nil, sProwl)
        or (wan.CheckUnitBuff(nil, sCatForm) and not bLunarInspiration)
        or (wan.CheckUnitBuff(nil, sBearForm) and wan.PlayerState.SpecializationName ~= "Guardian")
        or not isUsableMoonfire
    then
        wan.UpdateAbilityData(aMoonfireData.basename)
        return
    end

    if bLunarInspiration then
        local _, insufficientPowerShred = wan.IsSpellUsable(wan.spellData.Shred.id)
        if not isUsableMoonfire and insufficientPowerShred then
            wan.UpdateAbilityData(aMoonfireData.basename)
            return
        end
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aMoonfireData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aMoonfireData.basename)
        return
    end


    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cMoonfireInstantDmg = 0
    local cMoonfireDotDmg = 0
    local cMoonfireInstantDmgAoE = 0
    local cMoonfireDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cMoonfireDotDmgBase = 0
    local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, sMoonfire)
    if not checkMoonfireDebuff then
        local dotPotency = wan.CheckDotPotency(nMoonfireInstantDmg)
        cMoonfireDotDmgBase = cMoonfireDotDmgBase + (nMoonfireDotDmg * dotPotency)
    end

    ---- BALANCE TRAITS ----

    local cShootingStarsDotDmg = 0
    local cShootingStarsDotDmgAoE = 0
    if bShootingStars then
        local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, sMoonfire)

        if not checkMoonfireDebuff then
            local dotPotency = wan.CheckDotPotency(nMoonfireInstantDmg)

            cShootingStarsDotDmg = nMoonfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg * dotPotency
        end

        if bTwinMoons then
            local countUnitTwinMoonfire = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then

                    local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sMoonfire)
                    if not checkUnitMoonfireDebuff then
                        local checkUnitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, nameplateUnitToken)

                        cShootingStarsDotDmgAoE = cShootingStarsDotDmgAoE + (nMoonfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg * checkUnitDotPotency)

                        countUnitTwinMoonfire = countUnitTwinMoonfire + 1

                        if countUnitTwinMoonfire >= nTwinMoonfireAoeCap then break end
                    end
                end
            end
        end
    end

    local cTwinMoonsInstantDmgAoE = 0
    local cTwinMoonsDotDmgAoE = 0
    if bTwinMoons then
        cTwinMoonsInstantDmgAoE = cTwinMoonsInstantDmgAoE + nMoonfireInstantDmg
        local countUnitTwinMoonfire = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sMoonfire)
                if not checkUnitMoonfireDebuff then
                    local checkUnitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, nameplateUnitToken)

                    cTwinMoonsDotDmgAoE = cTwinMoonsDotDmgAoE + (nMoonfireDotDmg * checkUnitDotPotency)

                    countUnitTwinMoonfire = countUnitTwinMoonfire + 1

                    if countUnitTwinMoonfire >= nTwinMoonfireAoeCap then break end
                end
            end
        end
    end

    if bBalanceofAllThings then
        local checkBalanecofAllThingsArcane = wan.CheckUnitBuff(nil, sBalanceofAllThingsBuff, nBalanceofAllThingsBuffArcaneID)
        if checkBalanecofAllThingsArcane then
            for _, nBalanceofAllThingsCritChance in ipairs(checkBalanecofAllThingsArcane.points) do
                critChanceMod = critChanceMod + nBalanceofAllThingsCritChance
                break
            end
        end
    end

    ---- FERAL TRAITS ----

    if bBloodtalons then
        if not wan.IsTimerRunning then
            runBloodtalons = true
        end

        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff and not runBloodtalons then
            wan.UpdateAbilityData(wan.spellData.Moonfire.basename)
            return
        end
    end

    ---- GUARDIAN TRAITS ----

    local cTwinMoonfireInstantDmgAoE = 0
    local cTwinMoonfireDotDmgAoE = 0
    if bTwinMoonfire then
        cTwinMoonfireInstantDmgAoE = cTwinMoonfireInstantDmgAoE + nMoonfireInstantDmg
        local countUnitTwinMoonfire = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sMoonfire)

                if not checkUnitMoonfireDebuff then
                    local unitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, nameplateUnitToken)

                    cTwinMoonfireDotDmgAoE = cTwinMoonfireDotDmgAoE + ((nMoonfireDotDmg + cShootingStarsDotDmg) * unitDotPotency)
                    countUnitTwinMoonfire = countUnitTwinMoonfire + 1

                    if countUnitTwinMoonfire >= nTwinMoonfireAoeCap then break end
                end
            end
        end
    end

    local cGalacticGuardian = 1
    if bGalacticGuardian then
        local checkGalacticGuardianBuff = wan.CheckUnitBuff(nil, sGalacticGuardian)
        if checkGalacticGuardianBuff then
            cGalacticGuardian = cGalacticGuardian + nGalacticGuardian
        end
    end

    local cMoonfireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMoonfireInstantDmg = cMoonfireInstantDmg
        + (nMoonfireInstantDmg * cMoonfireCritValue * cGalacticGuardian)

    cMoonfireDotDmg = cMoonfireDotDmg
        + (cMoonfireDotDmgBase * cMoonfireCritValue)
        + (cShootingStarsDotDmg * cMoonfireCritValue)

    cMoonfireInstantDmgAoE = cMoonfireInstantDmgAoE
        + (cTwinMoonsInstantDmgAoE * cMoonfireCritValue)
        + (cTwinMoonfireInstantDmgAoE * cMoonfireCritValue * cGalacticGuardian)

    cMoonfireDotDmgAoE = cMoonfireDotDmgAoE
        + (cTwinMoonsDotDmgAoE * cMoonfireCritValue)
        + (cShootingStarsDotDmgAoE * cMoonfireCritValue)
        + (cTwinMoonfireDotDmgAoE * cMoonfireCritValue)

    local cMoonfireDmg = cMoonfireInstantDmg + cMoonfireDotDmg + cMoonfireInstantDmgAoE + cMoonfireDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMoonfireDmg)
    wan.UpdateAbilityData(aMoonfireData.basename, abilityValue, aMoonfireData.icon, aMoonfireData.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local moonfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Moonfire.id, { 1, 2, 3 })
            nMoonfireInstantDmg = moonfireValues[1]
            nMoonfireDotDmg = moonfireValues[2]
            nMoonfireDotDuration = moonfireValues[3]

            nShootingStarsDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ShootingStars.entryid, { 1 })
            nMoonfireDotTickRateMod = nMoonfireDotTickRate / (1 + (wan.Haste + nCosmicRapidity) * 0.01)
            nMoonfireDotTickNumber = nMoonfireDotDuration / nMoonfireDotTickRateMod
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and bBloodtalons then
            if spellID == wan.spellData.Moonfire.id then
                wan.SetTimer(nBloodtalonsTimer)

                if wan.IsTimerRunning then
                    runBloodtalons = false
                end
            end
        end
    end)
end

local frameMoonfire = CreateFrame("Frame")
frameMoonfire:RegisterEvent("ADDON_LOADED")
frameMoonfire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        aMoonfireData = wan.spellData.Moonfire

        abilityActive = aMoonfireData.known and aMoonfireData.id
        wan.BlizzardEventHandler(frameMoonfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)

        sMoonfire = aMoonfireData.formattedName
        sCatForm = wan.spellData.CatForm.formattedName
        sBearForm = wan.spellData.BearForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bShootingStars = wan.traitData.ShootingStars.known

        bTwinMoons = wan.traitData.TwinMoons.known

        bTwinMoonfire = wan.traitData.TwinMoonfire.known

        bBalanceofAllThings = wan.traitData.BalanceofAllThings.known
        sBalanceofAllThingsBuff = wan.traitData.BalanceofAllThings.traitkey
        sBalanceofAllThings = wan.GetTraitDescriptionNumbers(wan.traitData.BalanceofAllThings.entryid, { 2 }, wan.traitData.BalanceofAllThings.rank)

        bGalacticGuardian = wan.traitData.GalacticGuardian.known
        sGalacticGuardian = wan.traitData.GalacticGuardian.traitkey
        nGalacticGuardian = wan.GetTraitDescriptionNumbers(wan.traitData.GalacticGuardian.entryid, { 3 }) * 0.01

        local nCosmicRapidityValue = wan.GetTraitDescriptionNumbers(wan.traitData.CosmicRapidity.entryid, { 1 }, wan.traitData.CosmicRapidity.rank)
        nCosmicRapidity = wan.traitData.CosmicRapidity.rank > 0 and nCosmicRapidityValue or 0

        bLunarInspiration = wan.traitData.LunarInspiration.known

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey
        nBloodtalonsTimer = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodtalons.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
    end
end)