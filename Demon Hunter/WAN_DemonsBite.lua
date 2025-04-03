local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nDemonsBiteDmg = 0

-- Init trait data
local isTank = false
local nKnowYourEnemy = 0
local nBurningWoundDotDmg, nBurningWoundUnitCap = 0, 0

local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0
local bWoundedQuarry, nWoundedQuarry = false, 0
local bWarbladesHunger, sWarbladesHunger, nWarbladesHunger = false, "WarbladesHunger", 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.DemonsBite.id)
    then
        wan.UpdateAbilityData(wan.spellData.DemonsBite.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.DemonsBite.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.DemonsBite.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cDemonsBiteInstantDmg = 0
    local cDemonsBiteDotDmg = 0
    local cDemonsBiteInstantDmgAoE = 0
    local cDemonsBiteDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HAVOC TRAITS ----

    local cBurningWoundDotDmg = 0
    if wan.traitData.BurningWound.known then
        local formattedDebuffName = wan.traitData.BurningWound.traitkey

        local countBurningWoundDebuff = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitBurningWoundDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            if checkUnitBurningWoundDebuff then
                countBurningWoundDebuff = countBurningWoundDebuff + 1

                if countBurningWoundDebuff >= nBurningWoundUnitCap then
                    break
                end
            end
        end

        if countBurningWoundDebuff < nBurningWoundUnitCap then
            local checkUnitBurningWoundDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

            if not checkUnitBurningWoundDebuff then
                local checkDotPotency = wan.CheckDotPotency(nDemonsBiteDmg)

                cBurningWoundDotDmg = cBurningWoundDotDmg + (nBurningWoundDotDmg * checkDotPotency)
            end
        end
    end

    if wan.traitData.KnowYourEnemy.known then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
    end

    ---- VENGEANCE TRAITS ----

    local cVulnerability = 1
    if bVulnerability then
        local checkFrailtyDebuff = wan.CheckUnitDebuff(nil, sFrailty)

        if checkFrailtyDebuff then
            local nFrailtyStacks = checkFrailtyDebuff and checkFrailtyDebuff.applications

            if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

            cVulnerability = cVulnerability + (nVulnerability * nFrailtyStacks)
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMark = 1
    if bReaversMark then
        local checkReaversMarkDebuff = wan.CheckUnitDebuff(nil, sReaversMark)
        if checkReaversMarkDebuff then
            local cReaversMarkStacks = checkReaversMarkDebuff and checkReaversMarkDebuff.applications

            if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                cReaversMarkStacks = 1
            end

            local cWoundedQuarry = 0
            if bWoundedQuarry then
                cWoundedQuarry = cWoundedQuarry + (nWoundedQuarry)
            end

            cReaversMark = cReaversMark + (nReaversMark * cReaversMarkStacks) + cWoundedQuarry
        end
    end

    local cWarbladesHungerInstantDmg = 0
    if bWarbladesHunger and isTank == "TANK" then
        local checkWarbladesHungerBuff = wan.CheckUnitBuff(nil, sWarbladesHunger)

        if checkWarbladesHungerBuff then
            local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

            cWarbladesHungerInstantDmg = cWarbladesHungerInstantDmg + (nWarbladesHunger * checkPhysicalDR)
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cDemonsBiteCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cDemonsBiteInstantDmg = cDemonsBiteInstantDmg
        + (nDemonsBiteDmg * checkPhysicalDR * cDemonsBiteCritValue * cReaversMark * cVulnerability)
        + (cWarbladesHungerInstantDmg * cDemonsBiteCritValue * cReaversMark * cVulnerability)

    cDemonsBiteDotDmg = cDemonsBiteDotDmg

    cDemonsBiteInstantDmgAoE = cDemonsBiteInstantDmgAoE
        + (cBurningWoundDotDmg * cDemonsBiteCritValue * cReaversMark)

    cDemonsBiteDotDmgAoE = cDemonsBiteDotDmgAoE

    local cDemonsBiteDmg = cDemonsBiteInstantDmg + cDemonsBiteDotDmg + cDemonsBiteInstantDmgAoE + cDemonsBiteDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cDemonsBiteDmg)
    wan.UpdateAbilityData(wan.spellData.DemonsBite.basename, abilityValue, wan.spellData.DemonsBite.icon, wan.spellData.DemonsBite.name)
end

-- Init frame 
local frameDemonsBite = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDemonsBiteDmg = wan.GetSpellDescriptionNumbers(wan.spellData.DemonsBite.id, { 1 })
        end
    end)
end
frameDemonsBite:RegisterEvent("ADDON_LOADED")
frameDemonsBite:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.DemonsBite.isPassive and wan.spellData.DemonsBite.known and wan.spellData.DemonsBite.id
        wan.BlizzardEventHandler(frameDemonsBite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDemonsBite, CheckAbilityValue, abilityActive)

        isTank = wan.spellData.MasteryFelBlood.known
    end

    if event == "TRAIT_DATA_READY" then 

        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        local nBurningWoundValues = wan.GetTraitDescriptionNumbers(wan.traitData.BurningWound.entryid, { 1, 4 })
        nBurningWoundDotDmg = nBurningWoundValues[1]
        nBurningWoundUnitCap = nBurningWoundValues[2]

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bWoundedQuarry = wan.traitData.WoundedQuarry.known
        nWoundedQuarry = wan.GetTraitDescriptionNumbers(wan.traitData.WoundedQuarry.entryid, { 1 }, wan.traitData.WoundedQuarry.rank) * 0.01

        bWarbladesHunger = wan.traitData.WarbladesHunger.known
        sWarbladesHunger = wan.traitData.WarbladesHunger.traitkey
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDemonsBite, CheckAbilityValue, abilityActive)
    end
end)