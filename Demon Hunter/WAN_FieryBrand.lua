local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nFieryBrandDmg, nFieryBrandDotDmg, nFieryBrandDuration, nFieryBrand = 0, 0, 0, 0
local sFieryBrandDebuff, nFieryBrandDR = "FieryBrand", 0

-- Init trait data
local bFieryDemise, nFieryDemise = false, 0
local bBurningAlive = false
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

-- Ability value calculation
local function CheckAbilityValue()

    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.FieryBrand.id)
    then
        wan.UpdateAbilityData(wan.spellData.FieryBrand.basename)
        wan.UpdateMechanicData(wan.spellData.FieryBrand.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FieryBrand.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FieryBrand.basename)
        wan.UpdateMechanicData(wan.spellData.FieryBrand.basename)
        return
    end

    if bBurningAlive then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFieryBrandDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFieryBrandDebuff)
            if checkUnitFieryBrandDebuff then
                wan.UpdateAbilityData(wan.spellData.FieryBrand.basename)
                wan.UpdateMechanicData(wan.spellData.FieryBrand.basename)
                return
            end
        end
    else
        local checkFieryBrandDebuff = wan.CheckUnitDebuff(nil, sFieryBrandDebuff)
        if checkFieryBrandDebuff then
            wan.UpdateAbilityData(wan.spellData.FieryBrand.basename)
            wan.UpdateMechanicData(wan.spellData.FieryBrand.basename)
            return
        end
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFieryBrandInstantDmg = 0
    local cFieryBrandDotDmg = 0
    local cFieryBrandInstantDmgAoE = 0
    local cFieryBrandDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

    ---- VENGEANCE TRAITS ----

    local cFieryDemise = 1
    if bFieryDemise then
        cFieryDemise = cFieryDemise + nFieryDemise
    end

    local cBurningAlive = 1
    local cBurningAliveDotDmgAoE = 0
    if bBurningAlive then
        local cBurningAliveUnits = math.max(countValidUnit - 1, 0)
        if cBurningAliveUnits > 0 then
            for i = 1, cBurningAliveUnits do
                local cUnitBurningAlive = nFieryBrandDuration - i
                cBurningAlive = cBurningAlive + (cUnitBurningAlive / nFieryBrandDuration)
                cBurningAliveDotDmgAoE = cBurningAliveDotDmgAoE + (nFieryBrandDotDmg * (cUnitBurningAlive / nFieryBrandDuration))
            end
        end
    end

    local cVulnerability = 1
    local cVulnerabilityAoE = 1
    if bVulnerability then
        local checkFrailtyDebuff = wan.CheckUnitDebuff(nil, sFrailty)
        if checkFrailtyDebuff then
            local nFrailtyStacks = checkFrailtyDebuff and checkFrailtyDebuff.applications

            if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

            cVulnerability = cVulnerability + (nVulnerability * nFrailtyStacks)
        end

        local cVulnerabilityUnits = math.max(countValidUnit - 1, 0)
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitFrailtyDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFrailty)
                if checkUnitFrailtyDebuff then
                    local nFrailtyStacks = checkUnitFrailtyDebuff and checkUnitFrailtyDebuff.applications

                    if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

                    cVulnerabilityAoE = cVulnerabilityAoE + ((nVulnerability * nFrailtyStacks) / cVulnerabilityUnits)
                end
            end
        end
    end

    local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
    local cFieryBrandCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFieryBrandInstantDmg = cFieryBrandInstantDmg
        + (nFieryBrandDmg * cFieryBrandCritValue * cVulnerability)

    cFieryBrandDotDmg = cFieryBrandDotDmg
        + (nFieryBrandDotDmg * cFieryBrandCritValue * cFieryDemise * cVulnerability)

    cFieryBrandInstantDmgAoE = cFieryBrandInstantDmgAoE

    cFieryBrandDotDmgAoE = cFieryBrandDotDmgAoE
        + (cBurningAliveDotDmgAoE * cFieryBrandCritValue * cFieryDemise * cVulnerabilityAoE)

    local cFieryBrandDmg = cFieryBrandInstantDmg + cFieryBrandDotDmg + cFieryBrandInstantDmgAoE + cFieryBrandDotDmgAoE
    local cFieryBrandDef = (nFieryBrandDR * cBurningAlive) / countValidUnit

    local isTanking = wan.IsTanking()

    -- Update ability data
    local abilityValue = not isTanking and math.floor(cFieryBrandDmg) or 0
    local defensiveValue = isTanking and wan.UnitAbilityHealValue(playerUnitToken, cFieryBrandDef, currentPercentHealth)

    wan.UpdateMechanicData(wan.spellData.FieryBrand.basename, defensiveValue, wan.spellData.FieryBrand.icon, wan.spellData.FieryBrand.name)
    wan.UpdateAbilityData(wan.spellData.FieryBrand.basename, abilityValue, wan.spellData.FieryBrand.icon, wan.spellData.FieryBrand.name)
end

-- Init frame 
local frameFieryBrand = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local aFieryBrandValues = wan.GetSpellDescriptionNumbers(wan.spellData.FieryBrand.id, { 1, 2, 3, 4 })
            nFieryBrandDmg = aFieryBrandValues[1]
            nFieryBrandDotDmg = aFieryBrandValues[2]
            nFieryBrandDuration = aFieryBrandValues[3]
            nFieryBrand = aFieryBrandValues[4]
            nFieryBrandDR = wan.AbilityPercentageToValue(nFieryBrand)

        end
    end)
end
frameFieryBrand:RegisterEvent("ADDON_LOADED")
frameFieryBrand:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FieryBrand.known and wan.spellData.FieryBrand.id
        wan.BlizzardEventHandler(frameFieryBrand, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFieryBrand, CheckAbilityValue, abilityActive)

        sFieryBrandDebuff = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then
        bFieryDemise = wan.traitData.FieryDemise.known
        nFieryDemise = wan.GetTraitDescriptionNumbers(wan.traitData.FieryDemise .entryid, { 1 }, wan.traitData.FieryDemise .rank) * 0.01

        bBurningAlive = wan.traitData.BurningAlive.known

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFieryBrand, CheckAbilityValue, abilityActive)
    end
end)
