local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nCrusaderStrikeDmg, nCrusaderStrikeDotDmg = 0, 0
local nCrusaderStrikeMaxRange = 0

-- Init trait data
local nHeartOfTheCrusader = 0
local nBlessedChampionUnitCap, nBlessedChampion = 0, 0
local nHammeroftheRighteousAoEDmg = 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.CrusaderStrike.id)
    then
        wan.UpdateAbilityData(wan.spellData.CrusaderStrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.CrusaderStrike.id, nCrusaderStrikeMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.CrusaderStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cCrusaderStrikeInstantDmg = nCrusaderStrikeDmg
    local cCrusaderStrikeDotDmg = 0
    local cCrusaderStrikeInstantDmgAoE = 0
    local cCrusaderStrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- RETRIBUTION TRAITS ----

    local cTemplarStrikesDotDmg = 0
    local cTemplarStrikesDotDmgAoE = 0
    if wan.traitData.TemplarStrikes.known and wan.spellData.CrusaderStrike.name == "Templar Slash" then
        local checkTemplarStrikesDebuff = wan.CheckUnitDebuff(targetUnitToken, wan.spellData.CrusaderStrike.basename)
        if not checkTemplarStrikesDebuff then
            local dotPotency = wan.CheckDotPotency(nCrusaderStrikeDmg)

            cTemplarStrikesDotDmg = cTemplarStrikesDotDmg + (nCrusaderStrikeDmg * nCrusaderStrikeDotDmg * dotPotency)
        end

        if wan.traitData.BlessedChampion.known then
            local countBlessedChampionUnits = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitTemplarStrikesDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.CrusaderStrike.basename)
                    if not checkUnitTemplarStrikesDebuff then
                        local dotUnitPotency = wan.CheckDotPotency(nCrusaderStrikeDmg, nameplateUnitToken)

                        cTemplarStrikesDotDmgAoE = cTemplarStrikesDotDmgAoE + (nCrusaderStrikeDmg * nCrusaderStrikeDotDmg * nBlessedChampion * dotUnitPotency)
                        countBlessedChampionUnits = countBlessedChampionUnits + 1

                        if countBlessedChampionUnits >= nBlessedChampionUnitCap then break end
                    end
                end
            end
        end
    end

    local cBlessedChampionInstantDmgAoE = 0
    if wan.traitData.BlessedChampion.known then
        local countBlessedChampionUnits = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = ((wan.traitData.TemplarStrikes.known or wan.traitData.BladesofLight.known) and 1) or wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
                cBlessedChampionInstantDmgAoE = cBlessedChampionInstantDmgAoE + (nCrusaderStrikeDmg * checkUnitPhysicalDR * nBlessedChampion)
                countBlessedChampionUnits = countBlessedChampionUnits + 1
                if countBlessedChampionUnits >= nBlessedChampionUnitCap then break end
            end
        end
    end

    if wan.traitData.HeartoftheCrusader.known then
        critDamageMod = critDamageMod + nHeartOfTheCrusader
    end

    ---- PROTECTION TRAITS ----

    local cHammeroftheRighteousInstantDmgAoE = 0
    if wan.spellData.CrusaderStrike.name == "Hammer of the Righteous" then
        local checkConsecrationBuff = wan.CheckUnitDebuff(nil, wan.spellData.Consecration.basename)
        if checkConsecrationBuff then
            local HammeroftheRighteousUnits = math.max(countValidUnit - 1, 0)
            cHammeroftheRighteousInstantDmgAoE = cHammeroftheRighteousInstantDmgAoE + (nHammeroftheRighteousAoEDmg * HammeroftheRighteousUnits)
        end
    end

    local cBlessedHammer = 1
    local cBlessedHammerInstantDmgAoE = 0
    if wan.spellData.CrusaderStrike.name == "Blessed Hammer" then
        cBlessedHammer = 1 + 1
        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                cBlessedHammerInstantDmgAoE = cBlessedHammerInstantDmgAoE + nCrusaderStrikeDmg
            end
        end
    end


    local checkPhysicalBypass = wan.traitData.TemplarStrikes.known or wan.traitData.BladesofLight.known or wan.spellData.CrusaderStrike.name == "Blessed Hammer"
    local checkPhysicalDR = (checkPhysicalBypass and 1) or wan.CheckUnitPhysicalDamageReduction()
    local cCrusaderStrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cCrusaderStrikeInstantDmg = cCrusaderStrikeInstantDmg * cBlessedHammer * checkPhysicalDR * cCrusaderStrikeCritValue

    cCrusaderStrikeDotDmg = cCrusaderStrikeDotDmg 
        + (cTemplarStrikesDotDmg * checkPhysicalDR * cCrusaderStrikeCritValue)

    cCrusaderStrikeInstantDmgAoE = cCrusaderStrikeInstantDmgAoE
        + (cBlessedChampionInstantDmgAoE * cCrusaderStrikeCritValue)
        + (cHammeroftheRighteousInstantDmgAoE * cCrusaderStrikeCritValue)
        + (cBlessedHammerInstantDmgAoE * cBlessedHammer * cCrusaderStrikeCritValue)

    cCrusaderStrikeDotDmgAoE = cCrusaderStrikeDotDmgAoE
        + (cTemplarStrikesDotDmgAoE * cCrusaderStrikeCritValue)

    local cCrusaderStrikeDmg = cCrusaderStrikeInstantDmg + cCrusaderStrikeDotDmg + cCrusaderStrikeInstantDmgAoE + cCrusaderStrikeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cCrusaderStrikeDmg)
    wan.UpdateAbilityData(wan.spellData.CrusaderStrike.basename, abilityValue, wan.spellData.CrusaderStrike.icon, wan.spellData.CrusaderStrike.name)
end

-- Init frame 
local frameCrusaderStrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nCrusaderStrikeValues = wan.GetSpellDescriptionNumbers(wan.spellData.CrusaderStrike.id, { 1, 2, 3 })
            nCrusaderStrikeDmg = nCrusaderStrikeValues[1]
            nCrusaderStrikeDotDmg = nCrusaderStrikeValues[2] * 0.01
            nHammeroftheRighteousAoEDmg = nCrusaderStrikeValues[3]

            nCrusaderStrikeMaxRange = wan.spellData.CrusaderStrike.name == "Blessed Hammer" and 11 or 0
        end
    end)
end
frameCrusaderStrike:RegisterEvent("ADDON_LOADED")
frameCrusaderStrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CrusaderStrike.known and wan.spellData.CrusaderStrike.id
        wan.BlizzardEventHandler(frameCrusaderStrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameCrusaderStrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nHeartOfTheCrusader = wan.GetTraitDescriptionNumbers(wan.traitData.HeartoftheCrusader.entryid, { 1 }, wan.traitData.HeartoftheCrusader.rank)

        local nBlessedChampionValues = wan.GetTraitDescriptionNumbers(wan.traitData.BlessedChampion.entryid, { 1, 2 })
        nBlessedChampionUnitCap = nBlessedChampionValues[1]
        nBlessedChampion = 1 - (nBlessedChampionValues[2] * 0.01)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCrusaderStrike, CheckAbilityValue, abilityActive)
    end
end)