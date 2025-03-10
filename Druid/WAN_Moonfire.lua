local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nMoonfireInstantDmg, nMoonfireDotDmg, nMoonfireDotDuration, nMoonfireDotTickRate, nMoonfireDotTickRateMod, nMoonfireDotTickNumber = 0, 0, 0, 2, 0, 0

-- Init trait
local nGalacticGuardian = 0
local nTwinMoonfireAoeCap = 1
local nCosmicRapidity = 0
local nShootingStarsDmg, nShootingStarsProcChance = 0, 0.1
local nCosmicRapidity = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
        or (wan.auraData.player.buff_CatForm and not wan.traitData.LunarInspiration.known)
        or (wan.auraData.player.buff_BearForm and wan.PlayerState.Role ~= "TANK")
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
    local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Moonfire.formattedName)
    if not checkMoonfireDebuff then
        local dotPotency = wan.CheckDotPotency(nMoonfireInstantDmg)
        cMoonfireDotDmgBase = cMoonfireDotDmgBase + (nMoonfireDotDmg * dotPotency)
    end

    ---- BALANCE TRAITS ----
    
    local cShootingStarsDotDmg = 0
    local cShootingStarsDotDmgAoE = 0
    if wan.traitData.ShootingStars.known then
        local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Moonfire.formattedName)

        if not checkMoonfireDebuff then
            local dotPotency = wan.CheckDotPotency(nMoonfireInstantDmg)

            cShootingStarsDotDmg = nMoonfireDotTickNumber * nShootingStarsProcChance * nShootingStarsDmg * dotPotency
        end

        if wan.traitData.TwinMoons.known then
            local countUnitTwinMoonfire = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then

                    local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.Moonfire.formattedName)
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
    if wan.traitData.TwinMoons.known then
        cTwinMoonsInstantDmgAoE = cTwinMoonsInstantDmgAoE + nMoonfireInstantDmg
        local countUnitTwinMoonfire = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.Moonfire.formattedName)
                if not checkUnitMoonfireDebuff then
                    local checkUnitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, nameplateUnitToken)

                    cTwinMoonsDotDmgAoE = cTwinMoonsDotDmgAoE + (nMoonfireDotDmg * checkUnitDotPotency)

                    countUnitTwinMoonfire = countUnitTwinMoonfire + 1

                    if countUnitTwinMoonfire >= nTwinMoonfireAoeCap then break end
                end
            end
        end
    end

    ---- GUARDIAN TRAITS ----

    local cTwinMoonfireInstantDmg = 0
    local cTwinMoonfireDotDmg = 0
    if wan.traitData.TwinMoonfire.known then
        cTwinMoonfireInstantDmg = cTwinMoonfireInstantDmg + nMoonfireInstantDmg
        local countUnitTwinMoonfire = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.Moonfire.formattedName)
                if not checkUnitMoonfireDebuff then
                    local unitDotPotency = wan.CheckDotPotency(nMoonfireInstantDmg, nameplateUnitToken)

                    cTwinMoonfireDotDmg = cTwinMoonfireDotDmg + ((nMoonfireDotDmg + cShootingStarsDotDmg) * unitDotPotency)
                    countUnitTwinMoonfire = countUnitTwinMoonfire + 1

                    if countUnitTwinMoonfire >= nTwinMoonfireAoeCap then break end
                end
            end
        end
    end

    local cGalacticGuardian = 1
    if wan.traitData.GalacticGuardian.known then
        local checkGalacticGuardianBuff = wan.CheckUnitBuff(nil, wan.traitData.GalacticGuardian.traitkey)
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
        + (cTwinMoonfireInstantDmg * cMoonfireCritValue * cGalacticGuardian)

    cMoonfireDotDmgAoE = cMoonfireDotDmgAoE
        + (cTwinMoonsDotDmgAoE * cMoonfireCritValue)
        + (cShootingStarsDotDmgAoE * cMoonfireCritValue)
        + (cTwinMoonfireDotDmg * cMoonfireCritValue)

    local cMoonfireDmg = cMoonfireInstantDmg + cMoonfireDotDmg + cMoonfireInstantDmgAoE + cMoonfireDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMoonfireDmg)
    wan.UpdateAbilityData(wan.spellData.Moonfire.basename, abilityValue, wan.spellData.Moonfire.icon, wan.spellData.Moonfire.name)
end

-- Init frame 
local frameMoonfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local moonfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Moonfire.id, { 1, 2, 3 })
            nMoonfireInstantDmg = moonfireValues[1]
            nMoonfireDotDmg = moonfireValues[2]
            nMoonfireDotDuration = moonfireValues[3]

            nShootingStarsDmg = wan.GetTraitDescriptionNumbers(wan.traitData.ShootingStars.entryid, { 1 })
            nMoonfireDotTickRateMod = nMoonfireDotTickRate / (1 + (wan.Haste + nCosmicRapidity) * 0.01)
            nMoonfireDotTickNumber = nMoonfireDotDuration / nMoonfireDotTickRateMod
        end
    end)
end
frameMoonfire:RegisterEvent("ADDON_LOADED")
frameMoonfire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Moonfire.known and wan.spellData.Moonfire.id
        wan.BlizzardEventHandler(frameMoonfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nGalacticGuardian = wan.GetTraitDescriptionNumbers(wan.traitData.GalacticGuardian.entryid, { 3 }) * 0.01

        local nCosmicRapidityValue = wan.GetTraitDescriptionNumbers(wan.traitData.CosmicRapidity.entryid, { 1 }, wan.traitData.CosmicRapidity.rank)
        nCosmicRapidity = wan.traitData.CosmicRapidity.rank > 0 and nCosmicRapidityValue or 0
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
    end
end)